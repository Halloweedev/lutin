import SwiftUI
import CoreGraphics
import ImageIO
import AppKit
import LutinCore
import LutinConfig
import LutinRender
import LutinRelease
import LutinDocument
import LutinAppKit

/// Process-wide cache of icon visible-pixel bounds (alpha-derived),
/// normalised to the icon's full frame: `CGRect(0,0,1,1)` would mean
/// "fills the iconSize box edge-to-edge". `IconBoundsCache.shared` is
/// safe to access from any thread; the lock cost is negligible
/// relative to the bitmap scan it gates.
///
/// Why a singleton rather than `@State` on `CanvasView`: state mutation
/// inside a render pass triggers a re-render, and alpha analysis must
/// only run once per icon source. A reference type held outside the
/// view tree lets us look up cached entries without disturbing
/// SwiftUI's diff.
private final class IconBoundsCache {
    static let shared = IconBoundsCache()
    private var cache: [String: CGRect] = [:]
    private let lock = NSLock()
    func bounds(forKey key: String, compute: () -> CGRect) -> CGRect {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let computed = compute()
        cache[key] = computed
        return computed
    }
}

public struct CanvasView: View {
    @Bindable var document: LutinProjectDocument
    @Bindable var selectionModel: CanvasSelectionModel
    @Bindable var editorState: EditorState
    @Bindable var runner: PipelineRunner
    @Binding var showingDoctor: Bool
    @Binding var sidePanelHidden: Bool
    let projectName: String?
    let registryStore: RegistryStore?
    @State private var backgroundImage: CGImage?
    @State private var renderError: String?
    @State private var renderTask: Task<Void, Never>?
    @State private var contextLocation: CGPoint = .zero
    @State private var marqueeStart: CGPoint?
    @State private var marqueeCurrent: CGPoint?
    @State private var guideState = CanvasGuideState()
    /// True while the Option key is held. Drives the Figma-style
    /// distance overlay (`MeasurementGuides`) — magenta dashed lines
    /// from the selection's bounding box to each canvas edge with
    /// numeric distance pills. Hidden when no element is selected.
    @State private var optionPressed = false

    public init(document: LutinProjectDocument,
                selectionModel: CanvasSelectionModel,
                editorState: EditorState,
                runner: PipelineRunner,
                showingDoctor: Binding<Bool>,
                sidePanelHidden: Binding<Bool>,
                projectName: String? = nil,
                registryStore: RegistryStore? = nil) {
        self.document = document
        self.selectionModel = selectionModel
        self.editorState = editorState
        self.runner = runner
        self._showingDoctor = showingDoctor
        self._sidePanelHidden = sidePanelHidden
        self.projectName = projectName
        self.registryStore = registryStore
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
                                   volumeIconURL: resolvedVolumeIconURL,
                                   appBundleURL: resolvedAppBundleURL,
                                   contentSize: CGSize(width: configW, height: configH)) {
                ZStack(alignment: .topLeading) {
                    background(configW: configW, configH: configH)
                    ImageDecorationLayer(document: document,
                                         selectionModel: selectionModel,
                                         guideState: guideState,
                                         configW: configW,
                                         configH: configH)
                    ItemLayer(document: document,
                              selectionModel: selectionModel,
                              guideState: guideState,
                              configW: configW,
                              configH: configH)
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
                    // Canvas-center snap — solid magenta lines at the
                    // canvas centerlines. Distinct from the Option-hover
                    // measurement overlay (also magenta) by line style:
                    // these are solid; the measurement overlay is dashed.
                    if guideState.canvasCenterX {
                        Rectangle()
                            .fill(Tokens.color(.measurementGuide))
                            .frame(width: Tokens.Size.hairline, height: configH)
                            .position(x: configW / 2, y: configH / 2)
                            .allowsHitTesting(false)
                    }
                    if guideState.canvasCenterY {
                        Rectangle()
                            .fill(Tokens.color(.measurementGuide))
                            .frame(width: configW, height: Tokens.Size.hairline)
                            .position(x: configW / 2, y: configH / 2)
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
                // Option-key measurement overlay lives in an
                // `.overlay` (not as a ZStack sibling of `ItemLayer`)
                // so it draws AFTER every ItemLayer overlay — most
                // importantly the blue selection-ring `.strokeBorder`
                // overlay on selected icons. As a ZStack child, the
                // magenta endpoints were getting visually clipped by
                // the selection ring at the same iconSize edge,
                // making the line appear to "stop at the blue
                // selection" rather than at the icon's drawn box.
                // The overlay form guarantees the magenta is on top.
                .overlay {
                    if optionPressed,
                       let sel = selectionBoundingBox(iconSize: CGFloat(document.config.window?.iconSize ?? 96)) {
                        if let hovered = guideState.hoveredID,
                           !selectionModel.selection.contains(hovered),
                           let hov = boundingBox(for: hovered,
                                                 iconSize: CGFloat(document.config.window?.iconSize ?? 96)) {
                            MeasurementBetweenGuides(from: sel, to: hov)
                        } else {
                            MeasurementGuides(itemBounds: sel,
                                              canvasSize: CGSize(width: configW, height: configH))
                        }
                    }
                }
                .coordinateSpace(.named("canvas"))
                .background(Tokens.color(.canvasBackground))
                .contentShape(Rectangle())
                // Canvas-level hover tracking for the Option-key
                // measurement overlay. Hit-tests against the *same*
                // `boundingBox(for:iconSize:)` we use for distance
                // computation, so the hover region matches the
                // measurement region exactly — no view-stacking
                // surprises (the icon glyph used to absorb hover
                // events from a Color.clear catcher behind it),
                // no asymmetry from variable-width labels.
                .onContinuousHover(coordinateSpace: .named("canvas")) { phase in
                    let iconSize = CGFloat(document.config.window?.iconSize ?? 96)
                    switch phase {
                    case .active(let location):
                        guideState.hoveredID = hitTestForHover(at: location, iconSize: iconSize)
                    case .ended:
                        guideState.hoveredID = nil
                    }
                }
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
                // Track Option key for the measurement overlay. The
                // mask form fires twice per press (down + up), so we
                // just mirror the new flag set into `optionPressed`.
                // Losing focus while Option is held leaves the flag
                // stale; that's caught next time focus returns and
                // the key state is re-read by `.onAppear` below.
                .onModifierKeysChanged(mask: .option) { _, new in
                    optionPressed = new.contains(.option)
                }
                .onAppear {
                    // Initial sync — covers the "user holds Option,
                    // then clicks into the canvas" case where the
                    // change event predates focus.
                    optionPressed = NSEvent.modifierFlags.contains(.option)
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
            // Bottom-leading: Preview/Build/Release actions.
            .overlay(alignment: .bottomLeading) {
                CanvasActionsBar(document: document,
                                 runner: runner,
                                 projectName: projectName,
                                 registryStore: registryStore)
                    .padding(Tokens.spacing(.md))
            }
            // Bottom-trailing: zoom controls. Split from the action bar
            // (used to share an HStack on the leading side) so the canvas
            // floor reads as a balanced toolbar — actions on the left,
            // viewport controls on the right.
            .overlay(alignment: .bottomTrailing) {
                ZoomControlBar(zoomPercent: $editorState.zoomPercent,
                               paneSize: proxy.size,
                               canvasSize: CGSize(width: configW, height: configH))
                    .padding(Tokens.spacing(.md))
            }
            // Top-trailing: + Add menu
            .overlay(alignment: .topTrailing) {
                CanvasAddMenu(document: document)
                    .padding(Tokens.spacing(.md))
            }
            // Top-leading: Show sidebar button (visible only when panel is hidden)
            .overlay(alignment: .topLeading) {
                if sidePanelHidden {
                    LutinIconButton(systemName: "sidebar.left",
                                    accessibilityLabel: "Show sidebar",
                                    action: { sidePanelHidden = false })
                        .padding(Tokens.spacing(.md))
                }
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
            // Centred empty-state-style render-failure display: the
            // shared blocked-status glyph + the renderer's human
            // message. The renderer's messages are written to name
            // a user-facing action ("Pick one in the Design tab")
            // rather than YAML field paths, so we surface them
            // unchanged — no "Render failed:" prefix needed.
            VStack(spacing: Tokens.spacing(.sm)) {
                Image(systemName: StatusKind.blocked.systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(StatusKind.blocked.color)
                Text(renderError)
                    .font(Typography.chromeSmall)
                    .foregroundStyle(Tokens.color(.textPrimary))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: configW, height: configH)
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

    /// Resolves `config.app.path` against the project directory. Empty
    /// paths and missing files both return `nil` so `FinderWindowChrome`
    /// can fall back to its generic disk glyph instead of asking
    /// NSWorkspace for a non-existent file.
    private var resolvedAppBundleURL: URL? {
        let path = document.config.app.path
        guard !path.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let url = URL(fileURLWithPath: path,
                      relativeTo: document.projectDirectory).standardizedFileURL
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Resolves the project's custom volume icon, if one exists at the
    /// convention path `assets/VolumeIcon.icns`. Matches the lookup that
    /// `ReleasePipeline.resolveVolumeIcon` performs at build time, so the
    /// canvas preview shows the same glyph that Finder will show when the
    /// DMG mounts. Returns nil when absent — the chrome then falls back
    /// to the .app's AppIcon (which is also Finder's fallback).
    private var resolvedVolumeIconURL: URL? {
        let convention = document.projectDirectory
            .appendingPathComponent("assets/VolumeIcon.icns")
        return FileManager.default.fileExists(atPath: convention.path)
            ? convention : nil
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

    /// Union bounding box of every selected element, in canvas
    /// coordinates. Returns nil when nothing is selected — the caller
    /// then suppresses the measurement overlay.
    ///
    /// Items are squares centered at (item.x, item.y) with `iconSize`
    /// side length. Image decorations are rectangles with top-left at
    /// (deco.x, deco.y), width as configured, and height derived from
    /// the source image's aspect ratio (matches the renderer's
    /// contract — see `ImageDecorationLayer.imageView`). Loading the
    /// image once per call is fine here because the overlay only
    /// renders while Option is held and selections rarely span many
    /// images.
    private func selectionBoundingBox(iconSize: CGFloat) -> CGRect? {
        let rects = selectionModel.selection.compactMap {
            boundingBox(for: $0, iconSize: iconSize)
        }
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    /// Returns the topmost element whose measurement bbox contains
    /// `point`. Used by the canvas-level hover tracker — items beat
    /// image decorations on overlap (items render above images), and
    /// hidden elements are skipped.
    private func hitTestForHover(at point: CGPoint, iconSize: CGFloat) -> CanvasSelectionID? {
        for item in (document.config.items ?? []).filter({ !($0.hidden ?? false) }) {
            if let bbox = boundingBox(for: .item(id: item.id), iconSize: iconSize),
               bbox.contains(point) {
                return .item(id: item.id)
            }
        }
        if let decorations = document.config.decorations {
            for (i, deco) in decorations.enumerated() where !(deco.hidden ?? false) {
                _ = deco
                if let bbox = boundingBox(for: .image(index: i), iconSize: iconSize),
                   bbox.contains(point) {
                    return .image(index: i)
                }
            }
        }
        return nil
    }

    /// Bounding box in canvas coordinates for a single element.
    /// Returns nil if the element is no longer in the document (stale
    /// hover or selection target that survived a delete).
    ///
    /// For items: the **visible-pixel** rect within the iconSize
    /// frame, not the full iconSize square. Different icons have
    /// different amounts of transparent padding around their actual
    /// glyph (compare a Daub-style app icon whose squircle fills the
    /// frame to the Applications folder icon whose folder graphic
    /// has clear margins). Using a one-size-fits-all `iconSize`
    /// bbox makes magenta measurement lines land at different visual
    /// distances from the rendered icon edge depending on which icon
    /// it is — inconsistent. We alpha-scan each icon image once
    /// (cached in `IconBoundsCache`) to get its tight bounding box,
    /// then map that fraction onto the iconSize frame.
    ///
    /// For image decorations: width × (width × source aspect ratio),
    /// top-left anchored — matches the renderer's contract (see
    /// `ImageDecorationLayer.imageView`).
    private func boundingBox(for id: CanvasSelectionID, iconSize: CGFloat) -> CGRect? {
        switch id {
        case .item(let itemID):
            guard let item = document.config.items?.first(where: { $0.id == itemID }) else { return nil }
            let visible = visibleIconBoundsNormalized(for: item)
            let frameOriginX = CGFloat(item.x) - iconSize / 2
            let frameOriginY = CGFloat(item.y) - iconSize / 2
            return CGRect(x: frameOriginX + visible.minX * iconSize,
                          y: frameOriginY + visible.minY * iconSize,
                          width: visible.width * iconSize,
                          height: visible.height * iconSize)
        case .image(let index):
            guard let decos = document.config.decorations,
                  decos.indices.contains(index) else { return nil }
            let deco = decos[index]
            let w = CGFloat(deco.width ?? 100)
            let h = imageHeight(forDecoration: deco, width: w)
            return CGRect(x: CGFloat(deco.x ?? 0),
                          y: CGFloat(deco.y ?? 0),
                          width: w, height: h)
        }
    }

    /// Normalised (0…1) bounding box of an item's visible (non-fully-
    /// transparent) pixels within its iconSize frame. Cached
    /// process-wide keyed by what determines the icon's content:
    /// `applications` always returns the system folder glyph;
    /// `app` icons key on `config.app.path` (changing the path
    /// produces a new key naturally; replacing the file at the same
    /// path leaves a stale entry until restart — acceptable for v1).
    /// Falls back to the full frame `(0,0,1,1)` when the icon can't
    /// be loaded or the scan finds no opaque pixels.
    private func visibleIconBoundsNormalized(for item: LutinConfig.Item) -> CGRect {
        let cacheKey: String
        switch item.type {
        case "applications":
            cacheKey = "__system_applications_folder__"
        case "app":
            cacheKey = "app:\(document.config.app.path)"
        default:
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        return IconBoundsCache.shared.bounds(forKey: cacheKey) {
            // Scan at 256pt for accurate sub-pixel bounds on retina
            // assets without blowing alpha analysis time past a few ms.
            guard let cgImage = loadIconImage(for: item, sizePoints: 256) else {
                return CGRect(x: 0, y: 0, width: 1, height: 1)
            }
            return Self.scanVisibleBoundsNormalized(of: cgImage)
        }
    }

    /// Same icon resolution as `ItemLayer.loadIcon` — `applications`
    /// returns the system folder glyph, `app` resolves the bundle
    /// against `projectDirectory`. Kept here (rather than reusing the
    /// ItemLayer helper) so CanvasView can compute bounds without
    /// depending on a sibling view's private surface.
    private func loadIconImage(for item: LutinConfig.Item, sizePoints: Int) -> CGImage? {
        switch item.type {
        case "applications":
            return AppIconLoader.applicationsFolderIcon(sizePoints: sizePoints)
        case "app":
            let url = URL(fileURLWithPath: document.config.app.path,
                          relativeTo: document.projectDirectory).standardizedFileURL
            return AppIconLoader.appBundleIcon(at: url, sizePoints: sizePoints)
        default:
            return nil
        }
    }

    /// Scans a CGImage's alpha channel and returns the tightest
    /// rectangle (normalised to the image's pixel dimensions) that
    /// contains every pixel with alpha > 10/255 — i.e., everything
    /// the user would perceive as part of the glyph. Threshold of 10
    /// (≈4%) filters anti-aliased halo pixels that have effectively
    /// zero visual weight; without it, soft drop shadows in the icon
    /// asset would push the bounds out to the full frame and defeat
    /// the purpose. Coordinate origin is top-left to match Core
    /// Graphics' image space, but the returned rect is normalised
    /// so the caller can apply it to any frame size.
    private static func scanVisibleBoundsNormalized(of image: CGImage) -> CGRect {
        let w = image.width
        let h = image.height
        guard w > 0, h > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: w * h * bytesPerPixel)
        defer { buffer.deallocate() }
        // Zero-fill so an unwritten pixel reads as fully transparent.
        buffer.initialize(repeating: 0, count: w * h * bytesPerPixel)
        guard let ctx = CGContext(data: buffer, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                   space: colorSpace, bitmapInfo: bitmapInfo) else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var minX = w, minY = h, maxX = -1, maxY = -1
        let threshold: UInt8 = 10
        for y in 0..<h {
            let rowBase = y * bytesPerRow
            for x in 0..<w {
                if buffer[rowBase + x * bytesPerPixel + 3] > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        guard maxX >= minX, maxY >= minY else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let fw = CGFloat(w), fh = CGFloat(h)
        return CGRect(x: CGFloat(minX) / fw,
                      y: CGFloat(minY) / fh,
                      width: CGFloat(maxX - minX + 1) / fw,
                      height: CGFloat(maxY - minY + 1) / fh)
    }

    private func imageHeight(forDecoration deco: LutinConfig.Decoration,
                             width: CGFloat) -> CGFloat {
        guard let path = deco.path else { return width }
        let url = URL(fileURLWithPath: path,
                      relativeTo: document.projectDirectory).standardizedFileURL
        guard let ns = NSImage(contentsOf: url), ns.size.width > 0 else {
            return width
        }
        return width * (ns.size.height / ns.size.width)
    }

    private func nudge(dx: Int, dy: Int) {
        let mult = NSEvent.modifierFlags.contains(.shift) ? 10 : 1
        let deltas: [DocumentIntent.MoveTarget] = selectionModel.moveableIDs.compactMap { id in
            switch id {
            case .item(let i):  return .init(target: .item(id: i),               dx: dx * mult, dy: dy * mult)
            case .image(let i): return .init(target: .imageDecoration(index: i), dx: dx * mult, dy: dy * mult)
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
                // Canvas preview = background only. Arrows + image overlays
                // are drawn live by ArrowLayer / ImageDecorationLayer on top
                // of this PNG; baking them in here would double them.
                let url = try LutinRenderer.renderBackground(
                    config: configSnapshot, projectDirectory: projectDirSnapshot,
                    includeDecorations: false)
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

    // Minimal zoom bar — `−`, current-zoom readout, `+`. The "Fit" and
    // "100%" buttons were removed at the user's request; ⌘0 / ⌘1 went
    // with them. Re-add as hidden buttons elsewhere if those shortcuts
    // are wanted back without re-surfacing the UI.
    var body: some View {
        HStack(spacing: Tokens.spacing(.xs)) {
            LutinIconButton(systemName: "minus.magnifyingglass", accessibilityLabel: "Zoom out") {
                zoomPercent = ZoomController.stepDown(from: zoomPercent)
            }
            .keyboardShortcut("-", modifiers: .command)
            // 60pt minWidth so the zoom bar's total content width matches
            // CanvasActionsBar (`28*4 + 4*3` = `28*2 + 60 + 4*2` = 124pt)
            // — both bars then share the same outer rectangle.
            Text("\(zoomPercent)%")
                .font(Typography.chromeSmall)
                .foregroundStyle(Tokens.color(.textSecondary))
                .frame(minWidth: 60)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            LutinIconButton(systemName: "plus.magnifyingglass", accessibilityLabel: "Zoom in") {
                zoomPercent = ZoomController.stepUp(from: zoomPercent)
            }
            .keyboardShortcut("+", modifiers: .command)
        }
        .padding(Tokens.spacing(.sm))
        .background(Tokens.color(.panelBackground))
        .overlay(SquareShape().stroke(Tokens.color(.divider), lineWidth: Tokens.Size.hairline))
    }
}
