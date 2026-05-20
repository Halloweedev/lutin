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
    @State private var backgroundImage: CGImage?
    @State private var renderError: String?
    @State private var renderTask: Task<Void, Never>?

    public init(document: LutinProjectDocument, selectionModel: CanvasSelectionModel) {
        self.document = document
        self.selectionModel = selectionModel
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let backgroundImage {
                    Image(backgroundImage, scale: 2.0, label: Text("Background preview"))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    set: { selectionModel.selection = $0 }),
                    iconSize: document.config.window?.iconSize ?? 96)
                ItemLayer(document: document, selection: Binding(
                    get: { selectionModel.selection },
                    set: { selectionModel.selection = $0 }))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.color(.canvasBackground))
            .contentShape(Rectangle())
            .coordinateSpace(.named("canvas"))
            .onTapGesture { selectionModel.selection = .none }
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
