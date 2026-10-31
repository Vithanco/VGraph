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
    mountEditor(elementId: String.bridgeJSLiftParameter(elementIdBytes, elementIdLength))
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

@_expose(wasm, "bjs_setEditorVGL")
@_cdecl("bjs_setEditorVGL")
public func _bjs_setEditorVGL(_ textBytes: Int32, _ textLength: Int32) -> Void {
    #if arch(wasm32)
    setEditorVGL(text: String.bridgeJSLiftParameter(textBytes, textLength))
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_openEditorDocument")
@_cdecl("bjs_openEditorDocument")
public func _bjs_openEditorDocument(_ textBytes: Int32, _ textLength: Int32, _ nameBytes: Int32, _ nameLength: Int32) -> Int32 {
    #if arch(wasm32)
    let ret = openEditorDocument(text: String.bridgeJSLiftParameter(textBytes, textLength), name: String.bridgeJSLiftParameter(nameBytes, nameLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_setEditorStatus")
@_cdecl("bjs_setEditorStatus")
public func _bjs_setEditorStatus(_ textBytes: Int32, _ textLength: Int32) -> Void {
    #if arch(wasm32)
    setEditorStatus(text: String.bridgeJSLiftParameter(textBytes, textLength))
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_convertToDot")
@_cdecl("bjs_convertToDot")
public func _bjs_convertToDot(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = convertToDot(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_dotForLayout")
@_cdecl("bjs_dotForLayout")
public func _bjs_dotForLayout(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = dotForLayout(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_renderGraph")
@_cdecl("bjs_renderGraph")
public func _bjs_renderGraph(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = renderGraph(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_renderGraphDark")
@_cdecl("bjs_renderGraphDark")
public func _bjs_renderGraphDark(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = renderGraphDark(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_renderGraphWithQuality")
@_cdecl("bjs_renderGraphWithQuality")
public func _bjs_renderGraphWithQuality(_ graphBytes: Int32, _ graphLength: Int32, _ viewBytes: Int32, _ viewLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = renderGraphWithQuality(graph: String.bridgeJSLiftParameter(graphBytes, graphLength), view: String.bridgeJSLiftParameter(viewBytes, viewLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_listViews")
@_cdecl("bjs_listViews")
public func _bjs_listViews(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = listViews(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_describeNotation")
@_cdecl("bjs_describeNotation")
public func _bjs_describeNotation(_ notationBytes: Int32, _ notationLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = describeNotation(notation: String.bridgeJSLiftParameter(notationBytes, notationLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_debugGraph")
@_cdecl("bjs_debugGraph")
public func _bjs_debugGraph(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = debugGraph(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_layoutGraph")
@_cdecl("bjs_layoutGraph")
public func _bjs_layoutGraph(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = layoutGraph(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}

@_expose(wasm, "bjs_exportToVGL")
@_cdecl("bjs_exportToVGL")
public func _bjs_exportToVGL(_ graphBytes: Int32, _ graphLength: Int32) -> Void {
    #if arch(wasm32)
    let ret = exportToVGL(graph: String.bridgeJSLiftParameter(graphBytes, graphLength))
    return ret.bridgeJSLowerReturn()
    #else
    fatalError("Only available on WebAssembly")
    #endif
}