/// How the geometry types store themselves: their numbers, comma-separated.
/// `nil` unless the text holds exactly `count` of them.
func commaSeparatedNumbers(_ text: String, count: Int) -> [Double]? {
    let fields = text.split(separator: ",")
    guard fields.count == count else { return nil }
    let numbers = fields.compactMap { Double(String($0)) }
    return numbers.count == count ? numbers : nil
}
