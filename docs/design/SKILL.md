---
name: vithanco-diagram-design
description: Use when adding or changing a VGraph notation, node type, colour, token, icon or dark-mode behaviour, or when rendered diagrams "look off". Holds the normative visual reference for the default theme of the VGraph renderer (light and dark).
---

Read `README.md` in this folder first: it says which files are binding and lists the rules that regress most often.

Change the guide first (`Diagram Style Guide.html`, or the approved amendment it names), then mirror the change in the Swift code in the same PR:

- colours and tokens → `Sources/VGraph/Domain/Color/SemanticColor.swift` and the notation's tokens
- icons → `Sources/VGraph/Domain/Icons/BuiltinIcons.swift`

`Tests/VGraphTests/StyleGuideSyncTests.swift` fails when the guide and the code disagree. Never implement from `exploration/`.
