import SwiftUI
import CoreGraphics
import ImageIO
import LutinCore
import LutinConfig
import LutinRender
import LutinDocument

public struct CanvasView: View {
    @Bindable var document: LutinProjectDocument
    @State private var backgroundImage: CGImage?
    @State private var renderError: String?
    @State private var renderTask: Task<Void, Never>?
    @State private var selection: CanvasSelection = .none

    public init(document: LutinProjectDocument) {
        self.document = document
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let backgroundImage {
                    Image(backgroundImage, scale: 2.0, label: Text("Background preview"))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else if let renderError {
                    Text("Render failed: \(renderError)")
                        .font(Typography.chromeSmall)
                        .foregroundStyle(Tokens.color(.logError))
                        .padding()
                } else {
                    ProgressView().controlSize(.small)
                }
                ArrowLayer(document: document, selection: $selection,
                           iconSize: document.config.window?.iconSize ?? 96)
                ItemLayer(document: document, selection: $selection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.color(.canvasBackground))
            .contentShape(Rectangle())
            .coordinateSpace(.named("canvas"))
            .onTapGesture { selection = .none }
            .task(id: document.id) { await render() }
        }
    }

    @MainActor
    private func render() async {
        renderTask?.cancel()
        renderTask = Task.detached(priority: .userInitiated) {
            do {
                let url = try LutinRenderer.renderBackground(
                    config: document.config, projectDirectory: document.projectDirectory)
                defer { try? FileManager.default.removeItem(at: url) }
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    await MainActor.run { renderError = "Could not read rendered PNG" }
                    return
                }
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
