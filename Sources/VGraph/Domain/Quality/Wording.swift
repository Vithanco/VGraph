/// `CriticalSuccessFactor` → `Critical Success Factor`, `plus_first_operand` →
/// `plus first operand`; a run of capitals (`OR`) stays one word.
func inWords(_ identifier: String) -> String {
    let characters = Array(identifier)
    var result = ""
    for (index, character) in characters.enumerated() {
        let previous = index > 0 ? characters[index - 1] : nil
        let next = index + 1 < characters.count ? characters[index + 1] : nil
        let startsWord =
            character.isUppercase && previous.map { !$0.isUppercase || (next?.isLowercase ?? false) } ?? false
        if startsWord { result.append(" ") }
        result.append(character == "_" ? " " : character)
    }
    return result
}

/// Up to nine in words, as prose writes them; larger numbers in digits.
func numberInWords(_ number: Int) -> String {
    let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
    return (0..<words.count).contains(number) ? words[number] : "\(number)"
}

/// Both in words or both in digits: "between two and five", "between 1 and 20".
func rangeInWords(_ min: Int, _ max: Int) -> String {
    max < 10 ? "between \(numberInWords(min)) and \(numberInWords(max))" : "between \(min) and \(max)"
}

/// "a, b and c".
func listed(_ items: [String], joinedBy conjunction: String = "and") -> String {
    guard let last = items.last, items.count > 1 else { return items.first ?? "" }
    return items.dropLast().joined(separator: ", ") + " \(conjunction) " + last
}
