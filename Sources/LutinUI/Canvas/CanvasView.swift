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
                FinderWindowChrome(title: document.config.output.volumeName.isEmpty
                                   ? document.config.project.name
                                   : document.config.output.volumeName,
                                   contentSize: CGSize(width: configW, height: configH)) {
                ZStack(alignment: .topLeading) {
                    background(configW: configW, configH: configH)
                    ArrowLayer(document: document,
                               selection: Binding(
                                   get: { selectionModel.selection },
                                   set: { selectionModel.replace(with: $0) }),
                               iconSize: document.config.window?.iconSize ?? 96)
                    ImageDecorationLayer(document: document,
                                         selectionModel: selectionModel,
                                         guideState: guideState)
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
                    // Equal-spacing pills — render two distance badges
                    // between the dragged item and its flanking siblings.
                    if let hint = guideState.equalSpacingX {
                        equalSpacingPillsHorizontal(hint, axisY: configH / 2)
                    }
                    if let hint = guideState.equalSpacingY {
                        equalSpacingPillsVertical(hint, axisX: configW / 2)
                    }
                }
                .frame(width: configW, height: configH)
                .coordinateSpace(.named("canvas"))
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
                    Button("Add App…") { // allow-menu-button
                        CanvasFileDropDelegate.addLibrary(.app, at: contextLocation, document: document)
                    }
                    Button("Add Applications folder") { // allow-menu-button
                        CanvasFileDropDelegate.addLibrary(.applications, at: contextLocation, document: document)
                    }
                    Button("Add Image…") { // allow-menu-button
                        CanvasFileDropDelegate.addLibrary(.image, at: contextLocation, document: document)
                    }
                }
                .onDrop(of: [LibraryItem.dragType, .fileURL],
                        delegate: CanvasFileDropDelegate(document: document) { $0 })
                // Re-render whenever the background or window dimensions
                // change. document.id is stable across edits, so we hash
                // the render-relevant fields into a fingerprint string.
                .task(id: renderFingerprint) { await render() }
                } // FinderWindowChrome content
                .scaleEffect(scale, anchor: .topLeading)
                .padding(Tokens.spacing(.xl))
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

    @ViewBuilder
    private func equalSpacingPillsHorizontal(_ hint: CanvasGuideState.EqualSpacingHint,
                                             axisY: CGFloat) -> some View {
        let leftMid = CGFloat(hint.leftOrTop + hint.midpoint) / 2
        let rightMid = CGFloat(hint.midpoint + hint.rightOrBottom) / 2
        ZStack {
            pill(distance: hint.distance).position(x: leftMid, y: axisY)
            pill(distance: hint.distance).position(x: rightMid, y: axisY)
            Rectangle()
                .fill(Tokens.color(.alignmentGuide))
                .frame(width: CGFloat(hint.rightOrBottom - hint.leftOrTop),
                       height: Tokens.Size.hairline)
                .position(x: CGFloat(hint.leftOrTop + hint.rightOrBottom) / 2, y: axisY)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func equalSpacingPillsVertical(_ hint: CanvasGuideState.EqualSpacingHint,
                                           axisX: CGFloat) -> some View {
        let topMid = CGFloat(hint.leftOrTop + hint.midpoint) / 2
        let bottomMid = CGFloat(hint.midpoint + hint.rightOrBottom) / 2
        ZStack {
            pill(distance: hint.distance).position(x: axisX, y: topMid)
            pill(distance: hint.distance).position(x: axisX, y: bottomMid)
            Rectangle()
                .fill(Tokens.color(.alignmentGuide))
                .frame(width: Tokens.Size.hairline,
                       height: CGFloat(hint.rightOrBottom - hint.leftOrTop))
                .position(x: axisX, y: CGFloat(hint.leftOrTop + hint.rightOrBottom) / 2)
        }
        .allowsHitTesting(false)
    }

    private func pill(distance: Int) -> some View {
        Text("\(distance)")
            .font(Typography.chromeSmall.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(
                Capsule().fill(Tokens.color(.alignmentGuide))
            )
    }

    /// Stable string fingerprint of every config field the renderer
    /// consumes. Changing any of these re-fires the canvas's background
    /// render task; pure item/arrow moves don't.
    private var renderFingerprint: String {
        let bg = document.config.background
        let win = document.config.window
        return [
            String(describing: bg?.type),
            String(describing: bg?.template),
            String(describing: bg?.path),
            String(describing: bg?.scale),
            String(describing: bg?.colorA),
            String(describing: bg?.colorB),
            String(describing: bg?.angle),
            String(describing: bg?.grid),
            String(describing: bg?.noise),
            String(describing: bg?.cornerRadius),
            String(describing: win?.width),
            String(describing: win?.height),
            // app.path participates because Finder-chrome rendering may
            // reflect the icon (e.g. for a future preview that bakes
            // icons into the background).
            document.config.app.path,
        ].joined(separator: "|")
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
            LutinIconButton(systemName: "minus", accessibilityLabel: "Zoom out") {
                zoomPercent = ZoomController.stepDown(from: zoomPercent)
            }
            .keyboardShortcut("-", modifiers: .command)
            Text("\(zoomPercent)%")
                .font(Typography.chromeSmall)
                .frame(minWidth: 42)
            LutinIconButton(systemName: "plus", accessibilityLabel: "Zoom in") {
                zoomPercent = ZoomController.stepUp(from: zoomPercent)
            }
            .keyboardShortcut("+", modifiers: .command)
            LutinButton("Fit") {
                zoomPercent = ZoomController.fitPercent(canvas: canvasSize, pane: paneSize)
            }
            .keyboardShortcut("0", modifiers: .command)
            LutinButton("100%") { zoomPercent = 100 }
            .keyboardShortcut("1", modifiers: .command)
        }
        .padding(Tokens.spacing(.sm))
        .background(Tokens.color(.panelBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
    }
}
