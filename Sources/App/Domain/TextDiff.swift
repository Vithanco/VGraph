// Pure line-based diff over two VGL strings. Stdlib only — no Foundation, no
// git — so every ForStoreDocumentVersions adapter gets diffing for free.

public enum DiffLine: Equatable {
    case equal(String)
    case insert(String)
    case delete(String)
}

public enum TextDiff {
    public static func lines(from old: String, to new: String) -> [DiffLine] {
        let a = splitLines(old)
        let b = splitLines(new)
        return shortestEditScript(a, b).map { step in
            switch step {
            case .equal(let s): .equal(s)
            case .insert(let s): .insert(s)
            case .delete(let s): .delete(s)
            }
        }
    }

    /// `lines(from:to:)` as unified-diff-style text: `context` equal lines on
    /// each side of every change, longer equal runs collapsed to `@@ ... @@`.
    /// No file headers — which two versions these are is the caller's concern.
    public static func unified(from old: String, to new: String, context: Int = 3) -> String {
        let script = lines(from: old, to: new)
        guard !script.isEmpty else { return "" }

        var out: [String] = []
        var pendingEqual: [String] = []
        var sawChange = false

        // The equal run before a change splits three ways: trailing context
        // closing the previous hunk, elided middle, leading context opening
        // this one. Nothing closes a hunk that hasn't started, so before the
        // first change the run contributes leading context only.
        func flushEqualRun() {
            let trailing = sawChange ? pendingEqual.prefix(context) : pendingEqual.prefix(0)
            let rest = pendingEqual.dropFirst(trailing.count)
            let leading = rest.suffix(context)

            for line in trailing { out.append("  " + line) }
            if sawChange && rest.count > leading.count { out.append("@@ ... @@") }
            for line in leading { out.append("  " + line) }
            pendingEqual = []
        }

        for step in script {
            switch step {
            case .equal(let s):
                pendingEqual.append(s)
            case .insert(let s):
                flushEqualRun()
                out.append("+ " + s)
                sawChange = true
            case .delete(let s):
                flushEqualRun()
                out.append("- " + s)
                sawChange = true
            }
        }
        guard sawChange else { return "" }
        for line in pendingEqual.prefix(context) { out.append("  " + line) }

        return out.joined(separator: "\n")
    }

    private static func splitLines(_ s: String) -> [String] {
        guard !s.isEmpty else { return [] }
        var result = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if result.last == "" { result.removeLast() }
        return result
    }

    private enum EditStep {
        case equal(String)
        case insert(String)
        case delete(String)
    }

    /// Myers O(ND) shortest edit script.
    private static func shortestEditScript(_ a: [String], _ b: [String]) -> [EditStep] {
        let n = a.count
        let m = b.count
        if n == 0 && m == 0 { return [] }
        if n == 0 { return b.map { .insert($0) } }
        if m == 0 { return a.map { .delete($0) } }

        let maxD = n + m
        var trace: [[Int]] = []
        var v = [Int](repeating: 0, count: 2 * maxD + 1)
        let offset = maxD

        outer: for d in 0...maxD {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                var x: Int
                if k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]) {
                    x = v[offset + k + 1]
                } else {
                    x = v[offset + k - 1] + 1
                }
                var y = x - k
                while x < n && y < m && a[x] == b[y] {
                    x += 1
                    y += 1
                }
                v[offset + k] = x
                if x >= n && y >= m { break outer }
            }
        }

        // `trace[d]` is the snapshot taken *before* round `d`, so the backtrack
        // must include `d == 0` to pick up the leading common prefix.
        var steps: [EditStep] = []
        var x = n
        var y = m
        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let v = trace[d]
            let k = x - y
            let prevK = (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1])) ? k + 1 : k - 1
            let prevX = v[offset + prevK]
            let prevY = prevX - prevK

            while x > prevX && y > prevY {
                x -= 1
                y -= 1
                steps.append(.equal(a[x]))
            }
            if d > 0 {
                if x == prevX {
                    y -= 1
                    steps.append(.insert(b[y]))
                } else {
                    x -= 1
                    steps.append(.delete(a[x]))
                }
            }
            x = prevX
            y = prevY
        }
        return steps.reversed()
    }
}
