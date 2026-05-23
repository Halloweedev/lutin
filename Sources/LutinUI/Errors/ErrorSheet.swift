import SwiftUI
import AppKit
import LutinCore

public struct ErrorSheet: View {
    let error: LutinError
    let onDismiss: () -> Void

    public init(error: LutinError, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Tokens.spacing(.lg)) {
            HStack {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(Tokens.color(.logError))
                    .font(.title)
                Text(error.code).font(.headline.monospaced())
            }
            Text(error.message).font(Typography.chromeSmall)
            if let suggestion = FixSuggestions.suggestion(for: error.code) {
                GroupBox("Suggested fix") {
                    Text(suggestion).font(Typography.chromeSmall)
                }
            }
            if let details = error.details, !details.isEmpty {
                GroupBox("Details") {
                    VStack(alignment: .leading) {
                        ForEach(details.keys.sorted(), id: \.self) { k in
                            HStack(alignment: .top) {
                                Text(k + ":").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                Text(details[k] ?? "").font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
            }
            HStack {
                LutinButton("Copy as JSON") {
                    let json = (try? JSONEncoder().encode(error)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(json, forType: .string)
                }
                Spacer()
                LutinButton("Dismiss", role: .primary) { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Tokens.spacing(.xl))
        .frame(minWidth: 480)
    }
}
