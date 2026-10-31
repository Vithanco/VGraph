public struct OneToManyLookup<One: VProtocol, Many: VProtocol>: VProtocol {
    private let oneToMany: [One: Set<Many>]
    private let manyToOne: [Many: One]

    /// A many has one one, so adding it under another moves it.
    func add(many: Many, one: One) -> Self {
        let moved = remove(many: many)
        var oneToMany = moved.oneToMany
        var manyToOne = moved.manyToOne
        oneToMany[one, default: []].insert(many)
        manyToOne[many] = one
        return OneToManyLookup(oneToMany: oneToMany, manyToOne: manyToOne)
    }

    func remove(many: Many) -> Self {
        guard let one = getOne(many: many) else {
            return self
        }
        var oneToMany = self.oneToMany
        var manyToOne = self.manyToOne
        oneToMany[one]?.remove(many)
        if oneToMany[one]?.isEmpty == true {
            oneToMany.removeValue(forKey: one)
        }
        manyToOne.removeValue(forKey: many)
        return OneToManyLookup(oneToMany: oneToMany, manyToOne: manyToOne)
    }

    func remove(one: One) -> Self {
        var oneToMany = self.oneToMany
        var manyToOne = self.manyToOne
        for entry in getMany(one: one) ?? Set<Many>() {
            manyToOne.removeValue(forKey: entry)
        }
        oneToMany.removeValue(forKey: one)
        return OneToManyLookup(oneToMany: oneToMany, manyToOne: manyToOne)
    }

    func getMany(one: One) -> Set<Many>? {
        return oneToMany[one]
    }

    func getOne(many: Many) -> One? {
        return manyToOne[many]
    }

    var getAllOnes: [One] {
        return Array(oneToMany.keys)
    }

    var getAllManys: Set<Many> {
        return Set(manyToOne.keys)
    }

    public init() {
        self.oneToMany = [:]
        self.manyToOne = [:]
    }

    private init(oneToMany: [One: Set<Many>], manyToOne: [Many: One]) {
        self.oneToMany = oneToMany
        self.manyToOne = manyToOne
    }

    public static func == (lhs: OneToManyLookup<One, Many>, rhs: OneToManyLookup<One, Many>) -> Bool {
        return lhs.oneToMany == rhs.oneToMany && lhs.manyToOne == rhs.manyToOne
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(oneToMany)
        hasher.combine(manyToOne)
    }

    struct Counts: Equatable {
        let ones: Int
        let manys: Int
    }

    func counts() -> Counts {
        return Counts(ones: oneToMany.count, manys: manyToOne.count)
    }

    var _oneToMany: [One: Set<Many>] {
        return oneToMany
    }

    var _manyToOne: [Many: One] {
        return manyToOne
    }
}
