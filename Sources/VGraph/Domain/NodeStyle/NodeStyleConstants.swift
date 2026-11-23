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
    public static let typeLabelFont = VFont(family: .dmSans, size: 9)
    public static let accentBarWidth: Double = 4
    public static let typeLabelRowHeight: Double = 22

    public static let belowCategoryInsets = VEdgeInsets(regular: defaultPadding)

    public static let roundedBoxInsets = VEdgeInsets(regular: defaultPadding)

    // An SVG stroke is centred on its path, so half of it would be clipped.
    public static let frameStrokePadding = VEdgeInsets(regular: borderWidth / 2)

    // C4 shape metrics. Fixed (not proportional to the card) so the layout can reserve
    // exactly the space the shape occupies — the SVG shape drawing uses the same values.
    public static let c4PersonHeadRadius: Double = 11
    /// C4 person: vertical band above the body reserved for the head.
    public static let c4PersonHeadBand: Double = c4PersonHeadRadius * 1.7
    /// C4 database cylinder: elliptical cap height (top and bottom).
    public static let c4CylinderCapHeight: Double = 9

    /// The circle a type badge's icon sits on, and the gap before the type name.
    public static let typeBadgeDiameter: Double = 18
    public static let typeBadgeGap: Double = 6
    /// An accent strip's content insets, left and right.
    public static let accentStripLeftInset: Double = 12
    public static let accentStripRightInset: Double = 8
    public static let accentStripInsets = VEdgeInsets(
        top: 4, left: accentStripLeftInset, bottom: 6, right: accentStripRightInset)

    /// Minimum width for an iconAccentStrip node so the badge (circle + type name) never clips.
    public static func iconBadgeMinWidth(typeLabel: String) -> Double {
        typeBadgeDiameter + typeBadgeGap + uppercaseLabelWidth(typeLabel, font: typeLabelFont, letterSpacing: 0.06)
            + accentStripLeftInset + accentStripRightInset
    }

    /// The width of a label the renderer draws uppercased and letter-spaced by
    /// `letterSpacing` em. Uppercase letters run about 20% wider than the
    /// average-character estimate, and the spacing adds to every character.
    public static func uppercaseLabelWidth(_ text: String, font: VFont, letterSpacing: Double) -> Double {
        let upper = text.uppercased()
        let uppercaseFactor = 1.2
        return TextSizeEstimator.estimateWidth(text: upper, font: font) * uppercaseFactor
            + Double(upper.count) * font.size * letterSpacing
    }
}
