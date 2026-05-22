import SwiftUI
import CoreGraphics
import ImageIO
import AppKit
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
    @State private var marqueeStart: CGPoint?
    @State private var marqueeCurrent: CGPoint?
    @State private var guideState = CanvasGuideState()

    public init(document: LutinProjectDocument,
                selectionModel: CanvasSelectionModel,
                editorState: EditorState) {
        self.document = document
        self.selectionModel = selectionModel
        self.editorState = editorState
    }

    public var body: some View {
        GeometryReader { proxy in
            let configW = CGFloat(document.config.window?.width ?? 680)
            let configH = CGFloat(document.config.window?.height ?? 420)
            let scale = CGFloat(editorState.zoomPercent) / 100.0

            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    background(configW: configW, configH: configH)
                    ArrowLayer(document: document,
                               selection: Binding(
                                   get: { selectionModel.selection },
                                   set: { selectionModel.replace(with: $0) }),
                               iconSize: document.config.window?.iconSize ?? 96)
                    ImageDecorationLayer(document: document, selectionModel: selectionModel)
                    ItemLayer(document: document, selectionModel: selectionModel, guideState: guideState)
                    if let gx = guideState.guideX {
                        Rectangle()
                            .fill(Tokens.color(.alignmentGuide))
                            .frame(width: Tokens.Size.hairline, height: configH)
                            .position(x: CGFloat(gx), y: configH / 2)
                            .allowsHitTesting(false)
                    }
                    if let gy = guideState.guideY {
                        Rectangle()
                            .fill(Tokens.color(.alignmentGuide))
                            .frame(width: configW, height: Tokens.Size.hairline)
                            .position(x: configW / 2, y: CGFloat(gy))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: configW, height: configH)
                .coordinateSpace(.named("canvas"))
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: configW * scale, height: configH * scale)
                .background(Tokens.color(.canvasBackground))
                .contentShape(Rectangle())
                .onTapGesture { selectionModel.clear() }
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named("canvas"))
                        .onChanged { v in
                            if marqueeStart == nil { marqueeStart = v.startLocation }
                            marqueeCurrent = v.location
                        }
                        .onEnded { v in
                            if let start = marqueeStart, let end = marqueeCurrent {
                                let rect = CGRect(x: min(start.x, end.x),
                                                  y: min(start.y, end.y),
                                                  width: abs(end.x - start.x),
                                                  height: abs(end.y - start.y))
                                let hits = MarqueeSelection.hits(in: document.config, rect: rect)
                                if NSEvent.modifierFlags.contains(.command) {
                                    selectionModel.replace(with: selectionModel.selection.union(hits))
                                } else {
                                    selectionModel.replace(with: hits)
                                }
                            }
                            marqueeStart = nil; marqueeCurrent = nil
                        }
                )
                .overlay {
                    if let start = marqueeStart, let end = marqueeCurrent {
                        MarqueeOverlay(rect: CGRect(
                            x: min(start.x, end.x), y: min(start.y, end.y),
                            width: abs(end.x - start.x), height: abs(end.y - start.y)))
                    }
                }
                .focusable()
                .focusEffectDisabled()
                .onKeyPress(.delete) {
                    try? selectionModel.delete(in: document); return .handled
                }
                .onKeyPress(.leftArrow) { nudge(dx: -1, dy: 0); return .handled }
                .onKeyPress(.rightArrow) { nudge(dx: 1, dy: 0); return .handled }
                .onKeyPress(.upArrow) { nudge(dx: 0, dy: -1); return .handled }
                .onKeyPress(.downArrow) { nudge(dx: 0, dy: 1); return .handled }
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
                .onDrop(of: [LibraryItem.dragType, .fileURL],
                        delegate: CanvasFileDropDelegate(document: document) { $0 })
                .task(id: document.id) { await render() }
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottomTrailing) {
                ZoomControlBar(zoomPercent: $editorState.zoomPercent,
                               paneSize: proxy.size,
                               canvasSize: CGSize(width: configW, height: configH))
                    .padding(Tokens.spacing(.md))
            }
            .overlay(alignment: .bottom) {
                if selectionModel.moveableIDs.count >= 2 {
                    AlignDistributeToolbar(document: document, selectionModel: selectionModel)
                        .padding(.bottom, 60)
                }
            }
            .background(Tokens.color(.canvasBackground))
        }
    }

    @ViewBuilder
    private func background(configW: CGFloat, configH: CGFloat) -> some View {
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
    }

    private func nudge(dx: Int, dy: Int) {
        let mult = NSEvent.modifierFlags.contains(.shift) ? 10 : 1
        let deltas: [DocumentIntent.MoveTarget] = selectionModel.moveableIDs.compactMap { id in
            switch id {
            case .item(let i): return .init(target: .item(id: i), dx: dx * mult, dy: dy * mult)
            case .image(let i): return .init(target: .imageDecoration(index: i),
                                              dx: dx * mult, dy: dy * mult)
            case .arrow: return nil
            }
        }
        guard !deltas.isEmpty else { return }
        try? document.apply(.moveMany(deltas: deltas))
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

private struct ZoomControlBar: View {
    @Binding var zoomPercent: Int
    let paneSize: CGSize
    let canvasSize: CGSize

    var body: some View {
        HStack(spacing: Tokens.spacing(.xs)) {
            Button(action: { zoomPercent = ZoomController.stepDown(from: zoomPercent) }) {
                Image(systemName: "minus")
            }.keyboardShortcut("-", modifiers: .command)
            Text("\(zoomPercent)%")
                .font(Typography.chromeSmall)
                .frame(minWidth: 42)
            Button(action: { zoomPercent = ZoomController.stepUp(from: zoomPercent) }) {
                Image(systemName: "plus")
            }.keyboardShortcut("+", modifiers: .command)
            Button("Fit") {
                zoomPercent = ZoomController.fitPercent(canvas: canvasSize, pane: paneSize)
            }.keyboardShortcut("0", modifiers: .command)
            Button("100%") { zoomPercent = 100 }.keyboardShortcut("1", modifiers: .command)
        }
        .buttonStyle(.plain)
        .padding(Tokens.spacing(.sm))
        .background(Tokens.color(.panelBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
    }
}
