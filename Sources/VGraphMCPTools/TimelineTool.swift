// MCP tool for creating Timeline diagrams from VGL.

import Foundation
import MCP
import VGraph

public enum TimelineTool: VGraphTool {
    public static let name = "create_timeline"
    public static let errorNoun = "timeline"
    public static let notationName = "Timeline"

    public static let purposeSentence = """
        A Timeline visualises events over time, \
        optionally across multiple parallel tracks (groups). The default layout is left-to-right \
        but can be changed to any direction. The base notation provides generic TimePoint and Event \
        types — use `vnotation extends Timeline` to define domain-specific event types (e.g. Battle, \
        Treaty, Release, Incident) with custom colours and categories.
        """

    public static let vglParameterDescription = """
        Valid VGL code using the Timeline notation. Either \
        `vgraph <id>: Timeline "<title>" { ... }` directly, or a \
        `vnotation <Name> extends Timeline { ... }` block followed by \
        `vgraph <id>: <Name> "<title>" { ... }`.
        """

    private static let entry = Notations.Timeline.entry

    public static var descriptionBody: String {
        """
        ## Core Concept: alignGroup

        The key mechanism is the `alignGroup` attribute. Nodes sharing the same `alignGroup` value \
        are placed at the same position in the layout — pinned to the same column (left-to-right) \
        or the same row (top-to-bottom). This is what creates time alignment.

        ```
        node t1800: TimePoint "1800" [alignGroup: "1800"]
        node e1: Event "Something happened" [alignGroup: "1800"]
        ```

        These two nodes will appear at the same horizontal position because they share alignGroup "1800".

        ## How to Build a Timeline

        1. Choose a title that describes the scope of the timeline.
        2. Decide whether you need TimePoints (axis markers) or whether alignGroup alone suffices.
        3. Add Events for things that happened, each with an `alignGroup` matching its time.
        4. Use `sequence` edges between TimePoints to form the visible time axis.
        5. Use `influence` edges between Events to show causal or contextual links.
        6. Optionally use groups to create named parallel tracks (countries, teams, systems).

        ## VGL Syntax

        ```
        vgraph <id>: Timeline "<title>" {
            <nodes, edges, and groups>
        }
        ```

        ### Node Types

        \(NotationMarkdown.nodeTypeBullets(entry.nodeTypeDefinitions))

        ```
        node <id>: TimePoint "<label>" [alignGroup: "<time_value>"]
        node <id>: Event "<label>" [alignGroup: "<time_value>"]
        ```

        ALWAYS include `alignGroup` on every node to ensure correct time alignment.

        ### Edges

        \(NotationMarkdown.edgeTypeBullets(entry.edgeTypeDefinitions))

        `influence` can optionally carry a label.

        ```
        edge <from_id> -> <to_id>: sequence
        edge <from_id> -> <to_id>: influence
        edge <from_id> -> <to_id>: influence "<label>"
        ```

        ### Groups (Tracks)

        Groups create named parallel tracks rendered as labelled cluster boxes. Groups are optional.

        ```
        group <id> "<label>" {
            node <id>: Event "<label>" [alignGroup: "<value>"]
        }
        ```

        ## Changing Layout Direction

        The default is left-to-right. Use `vnotation extends Timeline` to change direction. \
        All four directions are supported: `topToBottom`, `bottomToTop`, `leftToRight`, `rightToLeft`.

        ```
        vnotation VerticalTimeline extends Timeline {
            layout: topToBottom
        }

        vgraph myTimeline: VerticalTimeline "My Timeline" {
            ...
        }
        ```

        ## Custom Event Types with vnotation

        For domain-specific timelines, use `vnotation extends Timeline` to add custom node types, \
        edge types, and change the layout — all in one block. The base TimePoint and Event types \
        plus sequence and influence edges remain available.

        ```
        vnotation WarTimeline extends Timeline {
            layout: topToBottom
            node type: Battle [nodeStyle: withCategory, color: "#883333", category: "Battle"]
            node type: Treaty [nodeStyle: withCategory, color: "#339933", category: "Treaty"]
            edge type: resolved_by from: Battle to: Treaty
            edge type: influenced from: Battle to: Battle
        }

        vgraph napoleonicWars: WarTimeline "Napoleonic Wars" {
            node t1805: TimePoint "1805" [alignGroup: "1805"]
            node t1812: TimePoint "1812" [alignGroup: "1812"]
            node t1815: TimePoint "1815" [alignGroup: "1815"]
            edge t1805 -> t1812: sequence
            edge t1812 -> t1815: sequence
                node f1: Battle "Battle of Austerlitz" [alignGroup: "1805"]
                node f2: Battle "Invasion of Russia" [alignGroup: "1812"]
                node f3: Battle "Battle of Waterloo" [alignGroup: "1815"]
                node e1: Treaty "Treaty of Pressburg" [alignGroup: "1805"]
                node e2: Treaty "Congress of Vienna" [alignGroup: "1815"]
            edge f1 -> e1: resolved_by
            edge f3 -> e2: resolved_by
            edge f1 -> f2: influenced "overconfidence"
            edge f2 -> f3: influenced "weakened army"
        }
        ```

        ## Basic Example (without vnotation)

        ```
        vgraph europe: Timeline "19th Century Europe" {
            node t1800: TimePoint "1800" [alignGroup: "1800"]
            node t1850: TimePoint "1850" [alignGroup: "1850"]
            node t1871: TimePoint "1871" [alignGroup: "1871"]
            edge t1800 -> t1850: sequence
            edge t1850 -> t1871: sequence

            group germany "Germany" {
                node g1: Event "Napoleon defeats Prussia" [alignGroup: "1800"]
                node g2: Event "German Unification" [alignGroup: "1871"]
            }

            group england "England" {
                node e1: Event "Industrial Revolution peaks" [alignGroup: "1850"]
                node e2: Event "Franco-Prussian War impact" [alignGroup: "1871"]
            }

            edge g1 -> g2: influence "led to"
            edge e1 -> e2: influence
            edge e1 -> g2: influence "industrialization enabled"
        }
        ```

        ## Rules

        1. ALWAYS use `alignGroup` on every node to ensure correct time alignment.
        2. TimePoints are optional — alignGroup alone suffices for alignment.
        3. Keep TimePoint labels short (dates, phase names).
        4. Use influence edges sparingly — only for meaningful causal or contextual links.
        5. Use meaningful IDs (t1800, battleOfWaterloo — not n1, n2).
        6. Groups are optional — use them when you have distinct parallel tracks.
        7. When you need domain-specific event types, use `vnotation extends Timeline` — \
        don't overload the generic Event type.
        8. When changing layout direction, always use `vnotation extends Timeline` with a \
        `layout:` directive — the base Timeline is always left-to-right.
        """
    }
}
