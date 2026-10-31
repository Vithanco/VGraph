public struct NodeStyleConstants {
    public static let cornerRadius: Double = 9
    public static let borderWidth: Double = 1.5
    public static let emptyBorder: Double = 2
    public static let readableDiff: Double = 5
    public static let separation: Double = 4

    public static let categoryHeight: Double = 19
    public static let categoryTextFontSize: Double = 11.0

    public static let defaultPadding: Double = emptyBorder + readableDiff

    public static let categoryFont = VFont(family: .dmSans, size: categoryTextFontSize)
    public static let defaultFont = VFont(family: .dmSans, size: 11)
    public static let typeLabelFont = VFont(family: .dmSans, size: 9)
    public static let contentFont = VFont(family: .dmSans, size: 13)
    public static let accentBarWidth: Double = 4
    public static let typeLabelRowHeight: Double = 22

    // Insets for content below category header - just regular padding on all sides
    // Note: The category height is already handled by the vertical layout
    public static let belowCategoryInsets = VEdgeInsets(regular: defaultPadding)

    public static let roundedBoxInsets = VEdgeInsets(regular: defaultPadding)

    // Padding to prevent frame stroke from being clipped
    // SVG strokes are centered on the path, so we need half the border width as padding
    public static let frameStrokePadding = VEdgeInsets(regular: borderWidth / 2)

    // C4 shape metrics. Fixed (not proportional to the card) so the layout can reserve
    // exactly the space the shape occupies — the SVG shape drawing uses the same values.
    public static let c4PersonHeadRadius: Double = 11
    /// C4 person: vertical band above the body reserved for the head.
    public static let c4PersonHeadBand: Double = c4PersonHeadRadius * 1.7
    /// C4 database cylinder: elliptical cap height (top and bottom).
    public static let c4CylinderCapHeight: Double = 9

    /// Minimum width for an iconAccentStrip node so the badge (circle + type name) never clips.
    /// Formula: badgeDiameter(18) + gap(6) + labelWidth + left(12) + right(8)
    /// Uppercase letters render ~20% wider than the average-char estimate, and letter-spacing
    /// 0.06em adds ~0.06 × fontSize per character — both accounted for below.
    public static func iconBadgeMinWidth(typeLabel: String) -> Double {
        let upper = typeLabel.uppercased()
        let baseWidth = TextSizeEstimator.estimateWidth(text: upper, font: typeLabelFont)
        let uppercaseFactor = 1.2
        let letterSpacing = Double(upper.count) * typeLabelFont.size * 0.06
        let labelWidth = baseWidth * uppercaseFactor + letterSpacing
        return 18 + 6 + labelWidth + 12 + 8
    }
}
