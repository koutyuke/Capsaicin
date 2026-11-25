import Sparkle
import SwiftUI

struct SettingsLicensesView: View {
    var bundle: Bundle = .main
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text(bundle.localizedString(forKey: "licenses.label", value: nil, table: "SettingsAbout"))
                .font(.title3).fontWeight(.semibold).accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)
            Divider()
            licenses
            Divider()
            HStack {
                Spacer()
                Button(bundle.localizedString(forKey: "licenses.done", value: nil, table: "SettingsAbout")) {
                    dismiss()
                }
                .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 540, height: 400)
        .background {
            // 本文にフォーカスがなくても Esc で閉じられるよう、Return とは別に登録する。
            Button("") { dismiss() }.keyboardShortcut(.cancelAction).hidden().accessibilityHidden(true)
        }
    }

    private var licenses: some View {
        Form {
            ForEach(SettingsLicense.allCases, id: \.self) { license in
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if let source = license.source {
                            Text(verbatim: source).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        switch Result(catching: { try license.text(in: bundle) }) {
                        case let .success(text):
                            Text(verbatim: SettingsLicense.reflowed(text)).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        case .failure:
                            Text(bundle.localizedString(
                                forKey: "licenses.unavailable", value: nil, table: "SettingsAbout",
                            ))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                } header: {
                    Text(verbatim: license.rawValue)
                }
            }
        }
        .formStyle(.grouped)
    }
}

enum SettingsLicense: String, CaseIterable {
    case capsaicin = "Capsaicin", keyboardShortcuts = "KeyboardShortcuts", sparkle = "Sparkle"

    var source: String? {
        guard self == .sparkle else { return nil }
        let version = Bundle(for: SPUUpdater.self).object(forInfoDictionaryKey: "CFBundleShortVersionString")
        return "Sparkle \(version as? String ?? "")\nhttps://github.com/sparkle-project/Sparkle"
    }

    func text(in bundle: Bundle) throws -> String {
        guard let url = bundle.url(forResource: rawValue + "-LICENSE", withExtension: "txt") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 原文は固定幅で改行してあるので、段落の中の改行を空白に変え、シートの幅で折り返せるようにする。
    /// 50 字に満たない行（著作権者の列挙や見出し）の後と、番号付きの項目の前では改行を残す。
    static func reflowed(_ text: String) -> String {
        var lines: [String] = []
        var previousLength = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if previousLength >= 50, !trimmed.isEmpty, trimmed.firstMatch(of: /^\d+\.\s/) == nil,
               let last = lines.popLast()
            {
                lines.append(last.replacing(/\s+$/, with: "") + " " + trimmed)
            } else {
                lines.append(String(line))
            }
            previousLength = line.count
        }
        return lines.joined(separator: "\n")
    }
}
