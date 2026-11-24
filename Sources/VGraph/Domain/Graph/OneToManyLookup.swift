public struct OneToManyLookup<One: VProtocol, Many: VProtocol>: VProtocol {
    private let oneToMany: [One: Set<Many>]
    private let manyToOne: [Many: One]

    /// A many has one one, so adding it under another moves it.
    func adding(many: Many, one: One) -> Self {
        let moved = removing(many: many)
        var oneToMany = moved.oneToMany
        var manyToOne = moved.manyToOne
        oneToMany[one, default: []].insert(many)
        manyToOne[many] = one
        return OneToManyLookup(oneToMany: oneToMany, manyToOne: manyToOne)
    }

    func removing(many: Many) -> Self {
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

    func removing(one: One) -> Self {
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

    public init() {
        self.oneToMany = [:]
        self.manyToOne = [:]
    }

    private init(oneToMany: [One: Set<Many>], manyToOne: [Many: One]) {
        self.oneToMany = oneToMany
        self.manyToOne = manyToOne
    }
}
