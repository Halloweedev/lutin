import SwiftUI
import CoreGraphics
import ImageIO
import LutinCore
import LutinConfig
import LutinRender
import LutinDocument

public struct CanvasView: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    @Bindable var editorState: EditorState
    @State private var backgroundImage: CGImage?
    @State private var renderError: String?
    @State private var renderTask: Task<Void, Never>?
    @State private var contextLocation: CGPoint = .zero

    public init(document: LutinProjectDocument,
                selectionModel: CanvasSelectionModel,
                editorState: EditorState) {
        self.document = document
        self.selectionModel = selectionModel
        self.editorState = editorState
    }

    public var body: some View {
        GeometryReader { proxy in
            // Canvas content is laid out at config-window dimensions (e.g. 680x420)
            // so items, arrows, and background all use the same coordinate system
            // as the rendered PNG. The whole stack is then scaled uniformly to fit
            // the available pane — keeps WYSIWYG when the window resizes.
            let configW = CGFloat(document.config.window?.width ?? 680)
            let configH = CGFloat(document.config.window?.height ?? 420)
            let scale = min(proxy.size.width / configW, proxy.size.height / configH)

            ZStack(alignment: .topLeading) {
                if let backgroundImage {
                    Image(backgroundImage, scale: 2.0, label: Text("Background preview"))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: configW, height: configH)
                } else if let renderError {
                    Text("Render failed: \(renderError)")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.logError))
                        .padding()
                } else {
                    ProgressView().controlSize(.small)
                }
                ArrowLayer(document: document, selection: Binding(
                    get: { selectionModel.selection },
                    set: { selectionModel.replace(with: $0) }),
                    iconSize: document.config.window?.iconSize ?? 96)
                ItemLayer(document: document, selection: Binding(
                    get: { selectionModel.selection },
                    set: { selectionModel.replace(with: $0) }))
            }
            .frame(width: configW, height: configH)
            // Named coordinate space lives INSIDE the scaleEffect so drag
            // gestures (connector handles, item drags) keep reporting in
            // unscaled config-pixel coordinates — what intents expect.
            .coordinateSpace(.named("canvas"))
            .onDrop(of: [LibraryItem.dragType, .fileURL],
                    delegate: CanvasFileDropDelegate(document: document) { $0 })
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .named("canvas"))
                    .onEnded { v in contextLocation = v.location }
            )
            .contextMenu {
                Button("Add App…") {
                    CanvasFileDropDelegate.addLibrary(.app, at: contextLocation, document: document)
                }
                Button("Add Applications folder") {
                    CanvasFileDropDelegate.addLibrary(.applications, at: contextLocation, document: document)
                }
                Button("Add Image…") {
                    CanvasFileDropDelegate.addLibrary(.image, at: contextLocation, document: document)
                }
            }
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: configW * scale, height: configH * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Tokens.color(.canvasBackground))
            .contentShape(Rectangle())
            .onTapGesture { selectionModel.clear() }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.delete) {
                try? selectionModel.delete(in: document)
                return .handled
            }
            .task(id: document.id) { await render() }
        }
    }

    @MainActor
    private func render() async {
        renderTask?.cancel()
        // Snapshot main-actor-isolated state before entering the detached task
        // so the renderer doesn't reach back across an isolation boundary.
        let configSnapshot = document.config
        let projectDirSnapshot = document.projectDirectory
        renderTask = Task.detached(priority: .userInitiated) {
            do {
                let url = try LutinRenderer.renderBackground(
                    config: configSnapshot, projectDirectory: projectDirSnapshot)
                // Force-decode now: CGImageSourceCreateImageAtIndex is lazy by
                // default. If we let it defer until SwiftUI displays the image,
                // the file may already be gone — which yields a valid CGImage
                // handle backed by nothing and renders as empty white.
                let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, options) else {
                    try? FileManager.default.removeItem(at: url)
                    await MainActor.run { renderError = "Could not read rendered PNG" }
                    return
                }
                try? FileManager.default.removeItem(at: url)
                await MainActor.run {
                    backgroundImage = image
                    renderError = nil
                }
            } catch let error as LutinError {
                await MainActor.run { renderError = error.message }
            } catch {
                await MainActor.run { renderError = error.localizedDescription }
            }
        }
        _ = await renderTask?.value
    }
}
