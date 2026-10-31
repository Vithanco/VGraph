public typealias GraphTransform = (VGraph) throws(VError) -> VGraph

extension TransformStep.Id {
    /// Declared here rather than in App so any hexagon downstream of layout can ask
    /// whether it ran.
    public static var layoutGraph: Self { "layoutGraph" }
    public static var notationTransforms: Self { "notationTransforms" }
}

public enum TransformPipeline {

    public static func compose(_ transforms: GraphTransform...) -> GraphTransform {
        return { graph in
            var result = graph
            for transform in transforms {
                result = try transform(result)
            }
            return result
        }
    }

    public static func compose(_ transforms: [GraphTransform]) -> GraphTransform {
        return { graph in
            var result = graph
            for transform in transforms {
                result = try transform(result)
            }
            return result
        }
    }

    public static var identity: GraphTransform {
        return { $0 }
    }
}
