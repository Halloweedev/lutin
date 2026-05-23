import SwiftUI
import LutinDocument

public struct ConflictSheet: View {
    let resolver: ConflictResolver
    let onResolved: () -> Void
    @State private var diff: UnifiedDiff?
    @State private var showingDiff: Bool = false

    public init(resolver: ConflictResolver, onResolved: @escaping () -> Void) {
        self.resolver = resolver
        self.onResolved = onResolved
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.md)) {
            Text("lutin.yml changed on disk")
                .font(.headline)
            Text("You have unsaved changes. How should this be resolved?")
                .font(Typography.chromeSmall)
                .foregroundStyle(.secondary)

            if showingDiff, let diff {
                DiffView(diff: diff)
                    .frame(minWidth: 480, minHeight: 240)
            }

            HStack {
                LutinButton("Show diff") {
                    if diff == nil { diff = try? resolver.computeDiff() }
                    showingDiff.toggle()
                }
                Spacer()
                LutinButton("Take disk") {
                    try? resolver.takeDisk()
                    onResolved()
                }
                LutinButton("Keep mine", role: .primary) {
                    try? resolver.keepMine()
                    onResolved()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Tokens.spacing(.xl))
        .frame(minWidth: 480)
    }
}

private struct DiffView: View {
    let diff: UnifiedDiff
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(diff.hunks.enumerated()), id: \.offset) { _, hunk in
                    Text("@@ -\(hunk.leftStart),0 +\(hunk.rightStart),0 @@")
                        .font(Typography.logLine)
                        .foregroundStyle(.secondary)
                        .padding(.top, Tokens.spacing(.sm))
                    ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 0) {
                            Text(prefix(line.kind))
                            Text(line.text)
                        }
                        .font(Typography.logLine)
                        .foregroundStyle(color(line.kind))
                    }
                }
            }
            .padding(Tokens.spacing(.sm))
        }
        .background(Tokens.color(.sheetBackground))
        .clipShape(SquareShape())
    }

    private func prefix(_ k: UnifiedDiff.Line.Kind) -> String {
        switch k { case .added: return "+ "; case .removed: return "- "; case .context: return "  " }
    }

    private func color(_ k: UnifiedDiff.Line.Kind) -> Color {
        switch k {
        case .added: return Tokens.color(.logSuccess)
        case .removed: return Tokens.color(.logError)
        case .context: return Tokens.color(.logStdout)
        }
    }
}
