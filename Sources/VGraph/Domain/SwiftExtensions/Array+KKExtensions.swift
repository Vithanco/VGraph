extension Array where Element: Equatable {
    public mutating func remove(object: Iterator.Element) {
        if let index = self.firstIndex(of: object) {
            self.remove(at: index)
        }
    }

    public func splitAndCombine(makeFirst: Element) -> [Element] {
        guard let i = self.firstIndex(of: makeFirst) else {
            return self
        }
        var first = Array(self[i..<self.count])
        let second = Array(self[0..<i])
        first.append(contentsOf: second)
        return first
    }

    public var uniqueElements: [Element] {
        return self.reduce(into: []) {
            uniqueElements, element in

            if !uniqueElements.contains(element) {
                uniqueElements.append(element)
            }
        }
    }
    public mutating func toggle(_ object: Element) {
        if self.contains(object) {
            remove(object: object)
            return
        }
        append(object)
    }
}

extension Sequence {
    public func chunked(into size: Int) -> [[Element]] {
        let array = Array(self)
        return stride(from: 0, to: array.count, by: size).map {
            let i = $0 + size
            let min = i < array.count ? i : array.count
            return Array(array[$0..<min])
        }
    }
}

extension Sequence where Element: Hashable {
    public var asSet: Set<Element> {
        return Set<Element>(self)
    }
}

extension Array {

    func first() -> Element? {
        if isEmpty {
            return nil
        }
        return self[0]
    }

    func last() -> Element? {
        if isEmpty {
            return nil
        }
        let index = count - 1
        return self[index]
    }

    func head() -> Element? {
        return first()
    }

    func tail() -> [Element] {
        if isEmpty || count == 1 {
            return []
        }
        let range: CountableRange<Int> = 1..<count
        let slice = self[range]
        return Array(slice)
    }
}

public protocol OptionalArray {
}

extension Array: OptionalArray {
}

// inspired from https://stackoverflow.com/questions/25738817/removing-duplicate-elements-from-an-array-in-swift
extension Sequence where Iterator.Element: Hashable {

    func uniqueItemsSet() -> Set<Iterator.Element> {
        return Set<Iterator.Element>(self)
    }

    func uniqueItemsArray() -> [Iterator.Element] {
        return Array(self.uniqueItemsSet())
    }

    func uniqueItemsArrayMaintainedOrder() -> [Iterator.Element] {
        return reduce([Iterator.Element]()) { $0.contains($1) ? $0 : $0 + [$1] }
    }
}

extension Set {
    var asArray: [Element] {
        return Array(self)
    }
}
