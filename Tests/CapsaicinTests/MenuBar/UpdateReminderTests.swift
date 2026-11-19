import CapsaicinCore
import Foundation
import Testing

struct UpdateReminderTests {
    @Test("SPEC-MENU-001 SPEC-MENU-009 停止中も抑止中も見出しと警告の後に更新と区切りを置く",
          arguments: [false, true], [false, true])
    func placement(isBlocking: Bool, hasWarnings: Bool) throws {
        let status = BlockingStatus(session: isBlocking ? BlockingSession(timeLimit: nil) : nil,
                                    batteryCondition: nil, misalignments: [:],
                                    brightnessWarnings: hasWarnings ? [.deletionFailed] : [])
        let bundle = try localizedAppBundle("ja")
        func rows(version: String?) -> [MenuEntry] {
            MenuContent.make(status: status, settings: Settings(), isOnACPower: false, hasInternalBattery: false,
                             sleepRows: [], pendingUpdateVersion: version, bundle: bundle)
        }
        let reminder = rows(version: "1.2.0")
        var prefix = [isBlocking ? "menu.header.active" : "menu.header.idle"]
        if hasWarnings {
            prefix.append("menu.warning.brightnessDeletionFailed.title")
        }
        prefix += ["menu.update.available", "separator.update"]
        #expect(Array(reminder.prefix(prefix.count).map(\.id)) == prefix)
        let item = try #require(reminder.first { $0.id == "menu.update.available" })
        #expect(item.title == "アップデートがあります")
        #expect(item.subtitle == "バージョン1.2.0")
        #expect(item.command == .checkForUpdates)
        #expect(!item.isChecked && !item.isWarning)
        // 画面を見たときと更新の処理終了時は、モデルが保留中の版を nil に戻す。
        let dismissed = rows(version: nil)
        #expect(!dismissed.contains { $0.id == "menu.update.available" || $0.id == "separator.update" })
        #expect(dismissed.map(\.id) == reminder.filter {
            $0.id != "menu.update.available" && $0.id != "separator.update"
        }.map(\.id))
    }
}
