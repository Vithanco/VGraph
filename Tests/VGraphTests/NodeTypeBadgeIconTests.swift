import Testing

@testable import VGraph

@Suite("Built-in notations' node type badges")
struct NodeTypeBadgeIconTests {

    @Test("Given every built-in notation, when its node type badges are read, then each names an icon that resolves")
    func everyNodeTypeBadgeNamesAnIconThatResolves() throws {
        let badges = try BuiltInNodeTypeStyles.all().filter { BuiltInNodeTypeStyles.wearsNodeTypeBadge($0.style) }
        #expect(!badges.isEmpty)
        for (key, style) in badges {
            let names = style.extractIcons()
            #expect(!names.isEmpty, "\(key) wears a node type badge that names no icon")
            for name in names {
                #expect(BuiltinIcons.artwork(for: name) != nil, "\(key) names \(name), which resolves to nothing")
            }
        }
    }
}
