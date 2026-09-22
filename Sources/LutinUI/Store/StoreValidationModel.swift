import Foundation
import LutinStoreConnect
import LutinStoreMetadata

/// §7's Validation section, as data: asc's findings grouped by scope and
/// locale, errors and warnings distinguished. Pure, so every grouping rule is
/// asserted without rendering.
public struct StoreValidationModel: Equatable {
    public enum Severity: Equatable { case error, warning }

    public struct Finding: Equatable, Identifiable {
        public let id: String
        public let scope: String?
        public let locale: String?
        public let version: String?
        public let field: String?
        public let file: String?
        public let severity: Severity
        public let message: String
        public let length: Int?
        public let limit: Int?

        public var isOverLimit: Bool {
            guard let length, let limit else { return false }
            return length > limit
        }
        /// `41/30` when asc reported a budget, else nil.
        public var budget: String? {
            guard let length, let limit else { return nil }
            return "\(length)/\(limit)"
        }
        /// `name · en-US` for a field finding, the path for a tree finding,
        /// `metadata tree` otherwise.
        public var title: String {
            if let field { return locale.map { "\(field) · \($0)" } ?? field }
            if let file { return file }
            return "metadata tree"
        }
    }

    public struct LocaleGroup: Equatable, Identifiable {
        public let id: String
        public let locale: String?
        public let findings: [Finding]
    }

    public struct Group: Equatable, Identifiable {
        public let id: String
        public let title: String
        public let localeGroups: [LocaleGroup]
        public let errorCount: Int
        public let warningCount: Int
    }

    public let groups: [Group]
    public let fileCount: Int
    public let offline: Bool
    public let errorCount: Int
    public let warningCount: Int
    public let valid: Bool
    public let headline: String
    public let fix: String?

    public static func make(report: StoreLogic.StoreValidateReport) -> StoreValidationModel {
        var groups: [Group] = []
        for (scopeKey, title) in [("app-info", "App info"), ("version", "Version")] {
            let scoped = report.issues.filter { $0.scope == scopeKey }
            guard !scoped.isEmpty else { continue }
            groups.append(group(id: scopeKey, title: title, findings: scoped))
        }
        // Unscoped findings — stray paths and the empty tree — are about the
        // tree itself, and get their own group rather than being hidden.
        let unscoped = report.issues.filter { $0.scope == nil || !["app-info", "version"].contains($0.scope!) }
        if !unscoped.isEmpty {
            groups.append(group(id: "tree", title: "Metadata tree", findings: unscoped))
        }

        let headline: String
        if report.offline {
            headline = report.issues.isEmpty
                ? "Offline subset: asc isn't installed, so structure and decoding were checked — and they are clean."
                : "Offline subset: asc isn't installed, so only structure and decoding were checked."
        } else if report.errorCount > 0 {
            headline = "asc reports \(report.errorCount) error\(report.errorCount == 1 ? "" : "s")"
                     + (report.warningCount > 0 ? " and \(report.warningCount) warning\(report.warningCount == 1 ? "" : "s")" : "") + "."
        } else if report.warningCount > 0 {
            headline = "asc reports no errors and \(report.warningCount) warning\(report.warningCount == 1 ? "" : "s")."
        } else {
            headline = "asc found no problems in \(report.fileCount) file\(report.fileCount == 1 ? "" : "s")."
        }

        return StoreValidationModel(
            groups: groups, fileCount: report.fileCount, offline: report.offline,
            errorCount: report.errorCount, warningCount: report.warningCount,
            valid: report.valid, headline: headline,
            fix: report.offline ? FixSuggestions.suggestion(for: "store_asc_missing") : nil)
    }

    private static func group(id: String, title: String,
                              findings: [StoreMetadataIssue]) -> Group {
        let byLocale = Dictionary(grouping: findings) { $0.locale }
        let localeGroups = byLocale.keys.sorted { ($0 ?? "") < ($1 ?? "") }.map { locale in
            let rows = byLocale[locale]!
                .sorted { a, b in
                    if a.isError != b.isError { return a.isError }
                    return (a.field ?? "") < (b.field ?? "")
                }
                .enumerated()
                .map { index, issue in
                    Finding(id: "\(id)-\(locale ?? "none")-\(index)",
                            scope: issue.scope, locale: issue.locale, version: issue.version,
                            field: issue.field, file: issue.file,
                            severity: issue.isError ? .error : .warning,
                            message: issue.message, length: issue.length, limit: issue.limit)
                }
            return LocaleGroup(id: "\(id)-\(locale ?? "none")", locale: locale, findings: rows)
        }
        return Group(id: id, title: title, localeGroups: localeGroups,
                     errorCount: findings.filter(\.isError).count,
                     warningCount: findings.filter { !$0.isError }.count)
    }
}
