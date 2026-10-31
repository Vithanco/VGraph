// Integration tests for Docker/Linux functionality

import Foundation
import MathUtils
import Testing

@Suite(.tags(.integration))
struct DockerIntegrationTests {

    // MARK: - Host-side Docker infrastructure tests

    private func findProjectRoot() -> String? {
        var currentPath = FileManager.default.currentDirectoryPath
        while currentPath != "/" {
            if FileManager.default.fileExists(atPath: currentPath + "/Package.swift") {
                return currentPath
            }
            currentPath = (currentPath as NSString).deletingLastPathComponent
        }
        return nil
    }

    // The cloud-image build moved from dockerBuild.sh into the justfile
    // (`just build-cloud-image`); these assert that recipe is present and correct.
    @Test
    func testCloudImageRecipeExists() throws {
        guard let root = findProjectRoot() else {
            throw TestError.projectRootNotFound
        }
        let justfile = try String(contentsOfFile: root + "/justfile", encoding: .utf8)

        #expect(justfile.contains("build-cloud-image:"), "justfile should define a build-cloud-image recipe")
        #expect(justfile.contains("docker build"), "build-cloud-image should run docker build")
    }

    @Test
    func testCloudImageRecipeTargetsLinuxAmd64() throws {
        guard let root = findProjectRoot() else {
            throw TestError.projectRootNotFound
        }
        let justfile = try String(contentsOfFile: root + "/justfile", encoding: .utf8)

        #expect(justfile.contains("--platform linux/amd64"), "Cloud Run image must be built for linux/amd64")
    }

    @Test
    func testDockerfileExists() throws {
        guard let root = findProjectRoot() else {
            throw TestError.projectRootNotFound
        }
        let fileManager = FileManager.default
        let dockerfile = root + "/Dockerfile"

        #expect(fileManager.fileExists(atPath: dockerfile), "Dockerfile should exist")
    }

    @Test
    func testDockerfileContainsRequiredDirectives() throws {
        guard let root = findProjectRoot() else {
            throw TestError.projectRootNotFound
        }
        let dockerfile = root + "/Dockerfile"
        let content = try String(contentsOfFile: dockerfile, encoding: .utf8)

        #expect(content.contains("FROM swift:"), "Dockerfile should specify a Swift base image")
        #expect(content.contains("ENTRYPOINT"), "Dockerfile should define an entrypoint")
        #expect(content.contains("vgraph-mcp"), "Dockerfile should reference vgraph-mcp")
    }

    // MARK: - Container-side tests (Linux only)

    @Test
    func testDockerBuildSucceeds() throws {
        #if os(Linux)
            // This test runs inside Docker on Linux
            // Verify Graphviz is available at expected location
            let dotPath = "/usr/bin/dot"
            let fileManager = FileManager.default

            #expect(fileManager.fileExists(atPath: dotPath), "Graphviz dot should be installed at \(dotPath)")
            #expect(fileManager.isExecutableFile(atPath: dotPath), "Graphviz dot should be executable")
        #endif
    }

    @Test
    func testGlibcMathFunctionsWork() throws {
        #if canImport(Glibc)
            let cosResult = Math.cos(0)
            #expect(cosResult.isEqual(to: 1.0, precision: 0.0001), "cos(0) should equal 1.0")

            let sinResult = Math.sin(Double.pi / 2)
            #expect(sinResult.isEqual(to: 1.0, precision: 0.0001), "sin(π/2) should equal 1.0")

            let powResult = Math.pow(base: 2.0, exponent: 3.0)
            #expect(powResult.isEqual(to: 8.0, precision: 0.0001), "pow(2, 3) should equal 8.0")
        #endif
    }

    @Test
    func testNonRootUserExecution() throws {
        #if os(Linux)
            // Verify we're running as non-root user in Docker
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/whoami")

            let pipe = Pipe()
            process.standardOutput = pipe

            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let username = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            #expect(username != "root", "Container should not run as root user")
            #expect(username == "vgraph", "Container should run as vgraph user")
        #endif
    }
}

extension Tag {
    @Tag static var integration: Self
}

enum TestError: Error {
    case projectRootNotFound
}
