//
//  Drawing+Editor.swift
//  VGraphEditor
//
//  The preview, mounted: a `VSVGNode` as ElementaryUI views, so that a redraw
//  patches the elements already shown instead of replacing them (ADR-0015 F1).
//

import EditorCore
import ElementaryUI
import VGraph
import VGraphSVG

/// Its own view because `<svg>` is the one SVG element that is also HTML
/// content, which is what the preview's `div` holds — and because the frame and
/// the zoom are the root's alone.
@View
struct Drawing {
    let root: VSVGNode
    /// What `root`'s `viewBox` is shown as. A `var` because ElementaryUI eases
    /// it from the last drawing's (`Animatable`, below): left to jump, a redraw
    /// that changes the diagram's bounds rescales and shifts the whole picture
    /// at once, and the nodes then glide from the wrong place.
    var frame: VRect
    let zoom: Zoom

    var body: some View {
        if case .element(.svg, let attributes, let children) = root {
            SVG.svg(attributes: mounted(framed(attributes))) { drawn(children) }
        }
    }

    private func framed(_ attributes: [VSVGAttribute]) -> [VSVGAttribute] {
        // The renderer's own strings once the easing has arrived: `frame` has
        // been through `Float` by then, and is a hair off them.
        let rest = mountedFrame(of: root)
        let arrived = rest.map { isClose($0, frame) } ?? true
        var result = arrived ? attributes : attributes.map { eased($0) }
        result.append(VSVGAttribute("preserveAspectRatio", "xMinYMin meet"))
        result.append(VSVGAttribute("style", zoomStyle(zoom, natural: arrived ? rest?.size ?? frame.size : frame.size)))
        return result
    }

    /// Width and height follow the `viewBox` because the renderer sets them to
    /// it: they are the natural size the zoom is taken from.
    private func eased(_ attribute: VSVGAttribute) -> VSVGAttribute {
        switch attribute.name {
        case "viewBox":
            return VSVGAttribute("viewBox", "\(frame.x) \(frame.y) \(frame.width) \(frame.height)")
        case "width": return VSVGAttribute("width", "\(frame.width)")
        case "height": return VSVGAttribute("height", "\(frame.height)")
        default: return attribute
        }
    }
}

extension Drawing: Animatable {
    var animatableValue: SIMD4<Float> {
        get { SIMD4(Float(frame.x), Float(frame.y), Float(frame.width), Float(frame.height)) }
        set {
            frame = VRect(
                x: Double(newValue[0]), y: Double(newValue[1]), width: Double(newValue[2]),
                height: Double(newValue[3]))
        }
    }
}

private func isClose(_ a: VRect, _ b: VRect) -> Bool {
    abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01 && abs(a.width - b.width) < 0.01
        && abs(a.height - b.height) < 0.01
}

/// Recurses into itself: a tree whose shape is only known at run time cannot be
/// type-erased, and every child being this one nominal type is what lets it
/// compile at all. The switch is over a closed tag set for the same reason —
/// Elementary carries the tag in the type.
@View
struct Drawn: SVGView {
    let node: VSVGNode

    var body: some SVGView {
        switch node {
        case .element(let tag, let attributes, let children):
            switch tag {
            case .svg: SVG.svg(attributes: mounted(attributes)) { drawn(children) }
            case .g: SVG.g(attributes: mounted(attributes)) { drawn(children) }
            case .defs: SVG.defs(attributes: mounted(attributes)) { drawn(children) }
            case .style: SVG.style(attributes: mounted(attributes)) { drawn(children) }
            case .symbol: SVG.symbol(attributes: mounted(attributes)) { drawn(children) }
            case .use: SVG.use(attributes: mounted(attributes)) { drawn(children) }
            case .marker: SVG.marker(attributes: mounted(attributes)) { drawn(children) }
            case .rect: SVG.rect(attributes: mounted(attributes)) { drawn(children) }
            case .circle: SVG.circle(attributes: mounted(attributes)) { drawn(children) }
            case .ellipse: SVG.ellipse(attributes: mounted(attributes)) { drawn(children) }
            case .path: SVG.path(attributes: mounted(attributes)) { drawn(children) }
            case .polygon: SVG.polygon(attributes: mounted(attributes)) { drawn(children) }
            case .polyline: SVG.polyline(attributes: mounted(attributes)) { drawn(children) }
            case .line: SVG.line(attributes: mounted(attributes)) { drawn(children) }
            case .text: SVG.text(attributes: mounted(attributes)) { drawn(children) }
            case .tspan: SVG.tspan(attributes: mounted(attributes)) { drawn(children) }
            case .title: SVG.title(attributes: mounted(attributes)) { drawn(children) }
            case .a: SVG.a(attributes: mounted(attributes)) { drawn(children) }
            case .linearGradient: SVG.linearGradient(attributes: mounted(attributes)) { drawn(children) }
            case .radialGradient: SVG.radialGradient(attributes: mounted(attributes)) { drawn(children) }
            case .stop: SVG.stop(attributes: mounted(attributes)) { drawn(children) }
            case .image: SVG.image(attributes: mounted(attributes)) { drawn(children) }
            case .clipPath: SVG.clipPath(attributes: mounted(attributes)) { drawn(children) }
            case .mask: SVG.mask(attributes: mounted(attributes)) { drawn(children) }
            }
        case .text(let content):
            content
        case .raw, .fragment, .empty:
            // `mountedChildren` has already left these out.
            EmptyContent()
        }
    }
}

private func drawn(_ children: [VSVGNode]) -> some SVGView {
    ForEach(mountedChildren(of: children), id: { $0.key }, content: { Drawn(node: $0.node) })
}

private func mounted<Tag: SVGTagDefinition & MarkupTrait.AllowsAttributes>(_ attributes: [VSVGAttribute]) -> [SVGAttribute<Tag>] {
    attributes.map { .custom(name: $0.name, value: $0.value) }
}
