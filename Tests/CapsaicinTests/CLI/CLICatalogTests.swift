import CapsaicinCore
import CapsaicinIPC
import Foundation
import Testing

private final class CLICatalogLocator: NSObject {}

struct CLICatalogTests {
    @Test("SPEC-CLI-003 SPEC-CLI-007 CLI カタログがアプリに収録され、全キーを日本語で読める")
    func localizedCatalog() throws {
        let products = Bundle(for: CLICatalogLocator.self).bundleURL.deletingLastPathComponent()
        let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
        #expect(app.url(forResource: "CLI", withExtension: "strings", subdirectory: "ja.lproj") != nil)
        for key in CLITextKey.allCases {
            let value = app.localizedString(forKey: key.rawValue, value: nil, table: "CLI")
            #expect(value != key.rawValue)
            #expect(!value.contains("\n"))
        }
        let text = CLIText(bundle: app)
        #expect(text(.alreadyBlocking).contains("指定した条件は適用していません"))
        #expect(text(.battery, "35").contains("35%"))
        #expect(text(.timer, "1970-01-01T00:00:00Z").contains("1970-01-01T00:00:00Z"))
    }

    @Test("SPEC-CLI-001 SPEC-CLI-007 置き換えの出力は変更したことと新しい解除時刻を日本語で伝える",
          arguments: [TimeLimitSource.timer, .specifiedTime])
    func replacementOutput(source: TimeLimitSource) throws {
        let products = Bundle(for: CLICatalogLocator.self).bundleURL.deletingLastPathComponent()
        let app = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
        let status = BlockingStatus(
            session: BlockingSession(timeLimit: TimeLimit(date: Date(timeIntervalSince1970: 0), source: source)),
            batteryCondition: nil, misalignments: [:], isRecordUnsaved: true,
        )
        let output = CLIOutput.response(
            IPCResponse(outcome: .timeLimitReplaced, status: status),
            text: CLIText(bundle: app),
        )
        #expect(output.exitCode == .success)
        #expect(output.standardError.isEmpty)
        #expect(output.standardOutput == "スリープ防止をオフにする時刻を変更しました。 / スリープ防止: オン / "
            + (source == .timer ? "タイマー" : "指定時刻")
            + ": 1970-01-01T00:00:00Zにオフ / 警告: 状態を保存できていません\n")
    }
}
