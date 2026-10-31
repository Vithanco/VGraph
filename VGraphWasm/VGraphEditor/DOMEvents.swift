//
//  DOMEvents.swift
//  VGraphEditor
//

import ElementaryUI
import JavaScriptKit

// MARK: - Pointer and mouse

/// Every pointer and mouse event the gestures read, with the raw event kept.
///
/// ElementaryUI ships no config for `contextmenu`, `dblclick` or the pointer
/// events, and its `MouseEvent` hides the raw event — we need
/// `preventDefault()` (to suppress the browser's native menu) and `target`
/// (to find the element under the pointer). `_TypedDOMEvent` /
/// `_DOMEventHandlerConfig` / `_onEvent` are the public seams ElementaryUI
/// exposes for exactly this. Crucially this rides the same BridgeJS
/// event-sink path as `.onClick`, so — unlike a JavaScriptKit `JSClosure`
/// (see the header of `Editor.swift`) — it actually fires in this embedded build.
struct RawPointerEvent: _TypedDOMEvent {
    let rawEvent: JSObject
    init?(__jsObject rawEvent: JSObject) { self.rawEvent = rawEvent }
    var clientX: Double { rawEvent.clientX.number ?? 0 }
    var clientY: Double { rawEvent.clientY.number ?? 0 }
    var altKey: Bool { rawEvent.altKey.boolean ?? false }
    /// ⇧ means *extend* in both pointer gestures — a [[Rubber band]] that
    /// adds rather than replaces, and a click that toggles (ADR-0018).
    var shiftKey: Bool { rawEvent.shiftKey.boolean ?? false }
    var target: JSValue { rawEvent.target }
    var movementX: Double { rawEvent.movementX.number ?? 0 }
    /// Which button *caused* this event — only meaningful on pointerdown/up.
    var button: Int { Int(rawEvent.button.number ?? 0) }
    /// Which buttons are held *now*.
    var buttons: Int { Int(rawEvent.buttons.number ?? 0) }
    /// Defaulted because this type also carries the plain `MouseEvent`s
    /// (`click`, `contextmenu`, `dblclick`), which are mouse-only by definition.
    var pointerType: String { rawEvent.pointerType.string ?? "mouse" }
    var pointerId: JSValue { rawEvent.pointerId }
    /// Defaulted so the mouse-only events above stay primary.
    var isPrimary: Bool { rawEvent.isPrimary.boolean ?? true }
    func preventDefault() { _ = rawEvent.preventDefault?() }
}

enum ContextMenuConfig: _DOMEventHandlerConfig {
    static let name = "contextmenu"
    typealias Event = RawPointerEvent
}

extension View {
    consuming func onContextMenu(_ handler: @escaping (RawPointerEvent) -> Void) -> some View<Tag> {
        _onEvent(ContextMenuConfig.self, handler: handler)
    }
}

/// `dblclick` rides the same seam as `contextmenu` — ElementaryUI has no
/// built-in double-click, and inline editing needs `target` to find the element
/// under the cursor (ADR-0009).
enum DoubleClickConfig: _DOMEventHandlerConfig {
    static let name = "dblclick"
    typealias Event = RawPointerEvent
}

extension View {
    consuming func onDoubleClick(_ handler: @escaping (RawPointerEvent) -> Void) -> some View<Tag> {
        _onEvent(DoubleClickConfig.self, handler: handler)
    }
}

/// ElementaryUI's own `.onClick` reports no coordinates, and the toolbar's
/// "＋ Node" needs them: the type list is positioned absolutely, so without
/// them it would open wherever the last context menu was (ADR-0016).
enum ClickRawConfig: _DOMEventHandlerConfig {
    static let name = "click"
    typealias Event = RawPointerEvent
}

extension View {
    consuming func onClickRaw(_ handler: @escaping (RawPointerEvent) -> Void) -> some View<Tag> {
        _onEvent(ClickRawConfig.self, handler: handler)
    }
}

/// Pointer, not mouse. `PointerEvent` inherits `MouseEvent`, so a mouse still
/// delivers every field the gestures read and desktop behaviour is unchanged
/// — but a finger and a pen now arrive through the same handlers instead of
/// through Safari's compatibility mouse events, which report `buttons: 0` and
/// would trip the gesture's "released somewhere we never saw" guard.
///
/// ElementaryUI ships `.onMouseDown`/`.onMouseMove`/`.onMouseUp` but nothing
/// for pointers, and its `MouseEvent` hides `target` anyway — the element
/// under the pointer is the whole hit test.
enum PointerDownRawConfig: _DOMEventHandlerConfig {
    static let name = "pointerdown"
    typealias Event = RawPointerEvent
}

enum PointerMoveRawConfig: _DOMEventHandlerConfig {
    static let name = "pointermove"
    typealias Event = RawPointerEvent
}

enum PointerUpRawConfig: _DOMEventHandlerConfig {
    static let name = "pointerup"
    typealias Event = RawPointerEvent
}

/// How a drag is really lost on touch: the browser promotes it to a scroll, or
/// a system gesture takes it. Not `pointerout`, which bubbles on every hop
/// between the SVG's own shapes, so a drag across the diagram would cancel
/// itself.
enum PointerCancelRawConfig: _DOMEventHandlerConfig {
    static let name = "pointercancel"
    typealias Event = RawPointerEvent
}

extension View {
    consuming func onPointerDownRaw(_ handler: @escaping (RawPointerEvent) -> Void) -> some View<Tag> {
        _onEvent(PointerDownRawConfig.self, handler: handler)
    }

    consuming func onPointerMoveRaw(_ handler: @escaping (RawPointerEvent) -> Void) -> some View<Tag> {
        _onEvent(PointerMoveRawConfig.self, handler: handler)
    }

    consuming func onPointerUpRaw(_ handler: @escaping (RawPointerEvent) -> Void) -> some View<Tag> {
        _onEvent(PointerUpRawConfig.self, handler: handler)
    }

    consuming func onPointerCancelRaw(_ handler: @escaping (RawPointerEvent) -> Void) -> some View<Tag> {
        _onEvent(PointerCancelRawConfig.self, handler: handler)
    }
}

/// A fuller `keydown` event than ElementaryUI's built-in `KeyboardEvent`
/// (which exposes only `.key`): undo/redo needs the modifier keys and
/// `preventDefault()`. Same seam as ``RawPointerEvent``; carries `keyup` too.
struct RawKeyEvent: _TypedDOMEvent {
    let rawEvent: JSObject
    init?(__jsObject rawEvent: JSObject) { self.rawEvent = rawEvent }
    var key: String { rawEvent.key.string ?? "" }
    var metaKey: Bool { rawEvent.metaKey.boolean ?? false }
    var ctrlKey: Bool { rawEvent.ctrlKey.boolean ?? false }
    var shiftKey: Bool { rawEvent.shiftKey.boolean ?? false }
    var altKey: Bool { rawEvent.altKey.boolean ?? false }
    func preventDefault() { _ = rawEvent.preventDefault?() }
}

enum KeyDownConfig: _DOMEventHandlerConfig {
    static let name = "keydown"
    typealias Event = RawKeyEvent
}

/// ⌥ released under a stationary pointer — the one case no `mousemove` will
/// report. Best-effort: a lost keyup self-heals on the next movement.
enum KeyUpConfig: _DOMEventHandlerConfig {
    static let name = "keyup"
    typealias Event = RawKeyEvent
}

/// A payload-less event — for the handlers that only need the *fact* that it
/// fired (`blur` seals the typing burst; `change` means a file was picked).
struct BareEvent: _TypedDOMEvent {
    let rawEvent: JSObject
    init?(__jsObject rawEvent: JSObject) { self.rawEvent = rawEvent }
}

enum BlurConfig: _DOMEventHandlerConfig {
    static let name = "blur"
    typealias Event = BareEvent
}

/// `change`, for the file input. Not `input`: a file `<input>` fires `change`
/// everywhere, while `input` on one is a newer and less even guarantee. The
/// event carries nothing we need — the chosen file is read off the element.
enum ChangeConfig: _DOMEventHandlerConfig {
    static let name = "change"
    typealias Event = BareEvent
}

extension View {
    /// Named to avoid colliding with ElementaryUI's own `onKeyDown`.
    consuming func onKeyDownRaw(_ handler: @escaping (RawKeyEvent) -> Void) -> some View<Tag> {
        _onEvent(KeyDownConfig.self, handler: handler)
    }

    consuming func onKeyUpRaw(_ handler: @escaping (RawKeyEvent) -> Void) -> some View<Tag> {
        _onEvent(KeyUpConfig.self, handler: handler)
    }

    consuming func onBlur(_ handler: @escaping () -> Void) -> some View<Tag> {
        _onEvent(BlurConfig.self, handler: { _ in handler() })
    }

    /// `Raw` like `onKeyDownRaw`: ElementaryUI's own `onChange` is the
    /// value-watching one, nothing to do with the DOM event.
    consuming func onChangeRaw(_ handler: @escaping () -> Void) -> some View<Tag> {
        _onEvent(ChangeConfig.self, handler: { _ in handler() })
    }
}

/// A trackpad pinch arrives as a `ctrlKey` wheel. `preventDefault` keeps the
/// browser from zooming the whole page instead.
struct RawWheelEvent: _TypedDOMEvent {
    let rawEvent: JSObject
    init?(__jsObject rawEvent: JSObject) { self.rawEvent = rawEvent }
    var clientX: Double { rawEvent.clientX.number ?? 0 }
    var clientY: Double { rawEvent.clientY.number ?? 0 }
    var deltaY: Double { rawEvent.deltaY.number ?? 0 }
    var zooms: Bool { (rawEvent.ctrlKey.boolean ?? false) || (rawEvent.metaKey.boolean ?? false) }
    func preventDefault() { _ = rawEvent.preventDefault?() }
}

enum WheelConfig: _DOMEventHandlerConfig {
    static let name = "wheel"
    typealias Event = RawWheelEvent
}

extension View {
    consuming func onWheelRaw(_ handler: @escaping (RawWheelEvent) -> Void) -> some View<Tag> {
        _onEvent(WheelConfig.self, handler: handler)
    }
}
