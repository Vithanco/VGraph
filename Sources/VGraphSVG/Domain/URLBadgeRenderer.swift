//
//  URLBadgeRenderer.swift
//  VGraphSVG
//
//  The mark an element carrying a link wears, and the click that follows it.
//

/// Names the badge for everything that has to recognise one: ``VSVGURLBadge``
/// stamps it, `SVGBuilder.hoverStyles` paints it, and the editor asks `closest`
/// for it to tell a click on the link apart from a click on the element beneath.
public enum URLBadgeRenderer {
    public static let cssClass = "vgraph-url-badge"
}
