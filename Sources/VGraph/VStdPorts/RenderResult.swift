//
//  RenderResult.swift
//  VGraph
//
//  In the core rather than in App because `VForEditAGraphVisually` names it, and
//  a port declared in the core cannot reach forward into App for its types.
//

public struct RenderResult {
    public let svg: String

    public let qualityReport: QualityReport

    public init(svg: String, qualityReport: QualityReport) {
        self.svg = svg
        self.qualityReport = qualityReport
    }
}
