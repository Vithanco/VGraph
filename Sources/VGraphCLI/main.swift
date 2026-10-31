// Native CLI for VGraph — converts Vithanco graph notation to DOT, SVG, or VGL.

import App
import ArgumentParser
import Foundation
import VGraph

struct VGraphCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vgraph",
        abstract: "Convert a VGL model to DOT, SVG, or VGL.",
        discussion: "Reads a VGL model from --input <file> or stdin. Writes result to --output <file> or stdout.",
        subcommands: [Dot.self, Svg.self, Vgl.self, Debug.self, Describe.self]
    )
}

// MARK: - Shared Options

struct IOOptions: ParsableArguments {
    @Option(name: .long, help: "VGL model file to read (default: stdin)")
    var input: String?

    @Option(name: .long, help: "Output file to write (default: stdout)")
    var output: String?

    func readInput() throws -> String {
        if let path = input {
            return try String(contentsOfFile: path, encoding: .utf8)
        }
        var lines: [String] = []
        while let line = readLine(strippingNewline: false) {
            lines.append(line)
        }
        return lines.joined()
    }

    func writeOutput(_ content: String) throws {
        if let path = output {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            print(content)
        }
    }
}

// MARK: - Subcommands

struct Dot: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Convert a VGL model to Graphviz DOT format"
    )

    @OptionGroup var io: IOOptions

    func run() throws {
        let graph = try io.readInput()
        let app = VGraphCLIApp()
        do {
            let result = try app.vithancoGraphToDot(graph)
            try io.writeOutput(result)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode.failure
        }
    }
}

struct Svg: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Render a VGL model to SVG with full layout and styles"
    )

    @OptionGroup var io: IOOptions

    @Option(name: .long, help: "Name of the view to render (default: the model)")
    var view: String?

    func run() throws {
        let graph = try io.readInput()
        let app = VGraphCLIApp()
        do {
            let result = try app.renderGraph(graph, view: view)
            try io.writeOutput(result.svg)

            // Write quality report to stderr (secondary output)
            if let qualityText = result.qualityReport.formatted() {
                FileHandle.standardError.write(Data("\(qualityText)\n".utf8))
            }
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode.failure
        }
    }
}

struct Vgl: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Parse and re-export a VGL model to canonical VGL format"
    )

    @OptionGroup var io: IOOptions

    func run() throws {
        let graph = try io.readInput()
        let app = VGraphCLIApp()
        do {
            let result = try app.exportToVGL(graph)
            try io.writeOutput(result)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode.failure
        }
    }
}

struct Debug: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print debug info about a parsed VGL model"
    )

    @OptionGroup var io: IOOptions

    func run() throws {
        let graph = try io.readInput()
        let app = VGraphCLIApp()
        do {
            let parsedGraph = try app.parseGraph(graph)
            let typedGraph = parsedGraph.typedGraph

            var output = parsedGraph.debugDescription
            output += "\n\nTypedGraph stats:"
            output += "\n  Nodes: \(typedGraph.nodes.count)"
            output += "\n  Edges: \(typedGraph.edges.count)"
            output += "\n  Node types: \(typedGraph.nodeTypes.count)"
            output += "\n  Edge types: \(typedGraph.edgeTypes.count)"

            try io.writeOutput(output)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode.failure
        }
    }
}

struct Describe: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the self-describing Markdown document for a built-in notation",
        discussion: "Example: vgraph describe --notation IBIS"
    )

    @Option(name: .long, help: "Notation name (e.g. IBIS, Timeline, CLD, ConceptMap, …)")
    var notation: String

    @Option(name: .long, help: "Optional custom title to use as the Markdown H1")
    var title: String?

    @Option(name: .long, help: "Output file to write (default: stdout)")
    var output: String?

    func run() throws {
        guard let markdown = VGraphCLIApp().describeNotation(notation, title: title) else {
            FileHandle.standardError.write(
                Data(
                    "Error: notation '\(notation)' has no Markdown self-description (is it a dynamic vnotation?)\n".utf8
                ))
            throw ExitCode.failure
        }
        do {
            if let path = output {
                try markdown.write(toFile: path, atomically: true, encoding: .utf8)
            } else {
                print(markdown)
            }
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            throw ExitCode.failure
        }
    }
}

// MARK: - Entry Point

VGraphCLI.main()
