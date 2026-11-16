import SwiftUI

struct SettingsLicensesView: View {
    var bundle: Bundle = .main
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(bundle.localizedString(forKey: "licenses.label", value: nil, table: "SettingsAbout"))
                .font(.headline).accessibilityAddTraits(.isHeader)
                .padding([.top, .horizontal], 20)
            licenses
            HStack {
                Spacer()
                Button(bundle.localizedString(forKey: "licenses.done", value: nil, table: "SettingsAbout")) {
                    dismiss()
                }
                .buttonStyle(.bordered).keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 560, height: 420)
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
                            Text(verbatim: source).textSelection(.enabled)
                        }
                        switch Result(catching: { try license.text(in: bundle) }) {
                        case let .success(text):
                            Text(verbatim: text).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        case .failure:
                            Text(bundle.localizedString(
                                forKey: "licenses.unavailable",
                                value: nil,
                                table: "SettingsAbout",
                            ))
                        }
                    }
                    .font(.callout).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        self == .sparkle ? "Sparkle 2.10.1\nhttps://github.com/sparkle-project/Sparkle" : nil
    }

    func text(in bundle: Bundle) throws -> String {
        guard let url = bundle.url(forResource: rawValue + "-LICENSE", withExtension: "txt") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
