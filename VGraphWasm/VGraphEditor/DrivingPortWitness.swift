//
//  DrivingPortWitness.swift
//  VGraphEditor
//
//  ADR-0013 left one thing to be settled by a compile rather than by argument:
//  whether a component may hold two driving ports at once (`A & B`) under
//  Embedded Swift as a generic constraint, never an existential. Nothing in the editor
//  needs two yet — this file is that compile and nothing else.
//
//  The case it stands in for is the real one: a diagram pane that also wants
//  ⌘Z, since [[History]] is a single stack over commands and text edits alike,
//  so undo belongs to the document's port and not the pane's. Delete this file
//  the day such a pane exists — it will be the better witness.
//

import App
import VGraph

/// A diagram pane's-worth of work over two ports. Static dispatch throughout:
/// `Session` is a generic parameter, so the composition is resolved at
/// specialisation exactly as a single constraint would be.
func vgConfirmTwoPortsCompose<Session: ForEditAGraphVisually & ForManageADocument>(
    _ session: Session
) -> Bool {
    session.canUndo && session.label(of: "") == nil
}
