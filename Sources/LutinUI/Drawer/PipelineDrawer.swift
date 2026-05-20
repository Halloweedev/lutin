import SwiftUI
import LutinDocument

public struct PipelineDrawer: View {
    @Bindable var runner: PipelineRunner
    @State private var isExpanded: Bool = true

    public init(runner: PipelineRunner) {
        self.runner = runner
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                Divider()
                logBody
            }
        }
        .background(Tokens.color(.surfaceElevated))
        .overlay(alignment: .top) { Rectangle().frame(height: 1).foregroundStyle(Tokens.color(.divider)) }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var header: some View {
        HStack(spacing: Tokens.spacing(.md)) {
            statusIcon
            Text(headerText).font(Typography.drawerStage)
            if case .running(_, let progress) = runner.state {
                ProgressView(value: progress).controlSize(.small).frame(width: 100)
            }
            Spacer()
            Button(isExpanded ? "Hide" : "Show") { isExpanded.toggle() }
                .buttonStyle(.borderless)
                .font(Typography.chromeSmall)
        }
        .padding(.horizontal, Tokens.spacing(.lg))
        .padding(.vertical, Tokens.spacing(.sm))
    }

    @ViewBuilder private var statusIcon: some View {
        switch runner.state {
        case .idle:        Image(systemName: "circle").foregroundStyle(.secondary)
        case .running:     ProgressView().controlSize(.small)
        case .succeeded:   Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.color(.logSuccess))
        case .failed:      Image(systemName: "xmark.octagon.fill").foregroundStyle(Tokens.color(.logError))
        }
    }

    private var headerText: String {
        switch runner.state {
        case .idle:                                 return "Pipeline idle"
        case .running(let stage, _):                return stage
        case .succeeded(let path):                  return "Build complete — \(URL(fileURLWithPath: path).lastPathComponent)"
        case .failed(let error):                    return "Failed — \(error.code)"
        }
    }

    private var logBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(runner.log.enumerated()), id: \.offset) { idx, line in
                        Text(line.text)
                            .font(Typography.logLine)
                            .foregroundStyle(color(for: line.kind))
                            .id(idx)
                    }
                }
                .padding(Tokens.spacing(.sm))
            }
            .frame(maxHeight: 220)
            .onChange(of: runner.log.count) { _, _ in
                proxy.scrollTo((runner.log.count - 1), anchor: .bottom)
            }
        }
    }

    private func color(for kind: PipelineRunner.LogLine.Kind) -> Color {
        switch kind {
        case .stdout:  return Tokens.color(.logStdout)
        case .stderr:  return Tokens.color(.logStderr)
        case .stage:   return Tokens.color(.logProgress)
        case .success: return Tokens.color(.logSuccess)
        case .error:   return Tokens.color(.logError)
        }
    }
}
