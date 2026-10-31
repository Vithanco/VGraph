extension Double {
    /// How VGL writes a number back: a whole number keeps its whole spelling, since
    /// reformatting hand-written VGL breaks the document rather than tidying it.
    var vglSpelling: String {
        self == rounded() && Swift.abs(self) < 1e15 ? "\(Int(self))" : "\(self)"
    }
}
