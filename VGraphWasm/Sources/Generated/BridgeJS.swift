// bridge-js: skip
// swift-format-ignore-file
// NOTICE: This is auto-generated code by BridgeJS from JavaScriptKit,
// DO NOT EDIT.
//
// To update this file, just rebuild your project or run
// `swift package bridge-js`.

@_spi(BridgeJS) import JavaScriptKit

@_expose(wasm, "bjs_mountEditor")
@_cdecl("bjs_mountEditor")
public func _bjs_mountEditor(_ elementIdBytes: Int32, _ elementIdLength: Int32) -> Void {
    #if arch(wasm32)
    let elementId = String.bridgeJSLiftParameter(elementIdBytes, elementIdLength)
    mountEditor(elementId: elementId)
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_editorRenderNow")
@_cdecl("bjs_editorRenderNow")
public func _bjs_editorRenderNow() -> Void {
    #if arch(wasm32)
    editorRenderNow()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_editorLongPressFired")
@_cdecl("bjs_editorLongPressFired")
public func _bjs_editorLongPressFired() -> Void {
    #if arch(wasm32)
    editorLongPressFired()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_editorClipboardRead")
@_cdecl("bjs_editorClipboardRead")
public func _bjs_editorClipboardRead(_ textBytes: Int32, _ textLength: Int32) -> Void {
    #if arch(wasm32)
    let text = String.bridgeJSLiftParameter(textBytes, textLength)
    editorClipboardRead(text: text)
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_setEditorVGL")
@_cdecl("bjs_setEditorVGL")
public func _bjs_setEditorVGL(_ textBytes: Int32, _ textLength: Int32) -> Void {
    #if arch(wasm32)
    let text = String.bridgeJSLiftParameter(textBytes, textLength)
    setEditorVGL(text: text)
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_openEditorDocument")
@_cdecl("bjs_openEditorDocument")
public func _bjs_openEditorDocument(_ textBytes: Int32, _ textLength: Int32, _ nameBytes: Int32, _ nameLength: Int32) -> Int32 {
    #if arch(wasm32)
    let name = String.bridgeJSLiftParameter(nameBytes, nameLength)
    let text = String.bridgeJSLiftParameter(textBytes, textLength)
    let ret = openEditorDocument(text: text, name: name)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_setEditorStatus")
@_cdecl("bjs_setEditorStatus")
public func _bjs_setEditorStatus(_ textBytes: Int32, _ textLength: Int32) -> Void {
    #if arch(wasm32)
    let text = String.bridgeJSLiftParameter(textBytes, textLength)
    setEditorStatus(text: text)
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_convertToDot")
@_cdecl("bjs_convertToDot")
public func _bjs_convertToDot(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = convertToDot(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_dotForLayout")
@_cdecl("bjs_dotForLayout")
public func _bjs_dotForLayout(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = dotForLayout(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_renderGraph")
@_cdecl("bjs_renderGraph")
public func _bjs_renderGraph(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = renderGraph(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_renderGraphDark")
@_cdecl("bjs_renderGraphDark")
public func _bjs_renderGraphDark(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = renderGraphDark(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_renderGraphWithQuality")
@_cdecl("bjs_renderGraphWithQuality")
public func _bjs_renderGraphWithQuality(_ graphBytes: Int32, _ graphLength: Int32, _ viewBytes: Int32, _ viewLength: Int32) -> Void {
    #if arch(wasm32)
    let view = String.bridgeJSLiftParameter(viewBytes, viewLength)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = renderGraphWithQuality(graph: graph, view: view)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_listViews")
@_cdecl("bjs_listViews")
public func _bjs_listViews(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = listViews(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_describeNotation")
@_cdecl("bjs_describeNotation")
public func _bjs_describeNotation(_ notationBytes: Int32, _ notationLength: Int32) -> Void {
    #if arch(wasm32)
    let notation = String.bridgeJSLiftParameter(notationBytes, notationLength)
    let ret = describeNotation(notation: notation)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_debugGraph")
@_cdecl("bjs_debugGraph")
public func _bjs_debugGraph(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = debugGraph(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_layoutGraph")
@_cdecl("bjs_layoutGraph")
public func _bjs_layoutGraph(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = layoutGraph(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_exportToVGL")
@_cdecl("bjs_exportToVGL")
public func _bjs_exportToVGL(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let graph = String.bridgeJSLiftParameter(graphBytes, graphLength)
    let ret = exportToVGL(graph: graph)
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}