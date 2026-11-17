import CapsaicinCore
import Testing

struct UpdatePolicyTests {
    @Test("SPEC-SET-007 確認がオフならダウンロードの設定によらずオフ", arguments: [false, true])
    func disabledChecks(downloads: Bool) {
        #expect(AutomaticUpdateMode(automaticallyChecksForUpdates: false,
                                    automaticallyDownloadsUpdates: downloads) == .off)
    }

    @Test("SPEC-SET-007 確認のみと自動インストールを2つの設定へ対応させる",
          arguments: AutomaticUpdateMode.allCases)
    func roundTrip(mode: AutomaticUpdateMode) {
        #expect(mode.automaticallyChecksForUpdates == (mode != .off))
        #expect(mode.automaticallyDownloadsUpdates == (mode == .downloadAndInstall))
        #expect(AutomaticUpdateMode(automaticallyChecksForUpdates: mode.automaticallyChecksForUpdates,
                                    automaticallyDownloadsUpdates: mode.automaticallyDownloadsUpdates) == mode)
    }

    @Test("SPEC-LCY-008 抑止を止めて設定ウインドウを閉じたときだけ自動インストールする",
          arguments: [false, true], [false, true])
    func installationTiming(blocking: Bool, settingsOpen: Bool) {
        #expect(UpdatePolicy.canInstallAutomatically(isBlocking: blocking, settingsWindowIsOpen: settingsOpen)
            == (!blocking && !settingsOpen))
    }

    @Test("SPEC-SET-007 ビルド構成によらず配信元と公開鍵がそろった場合だけ更新を有効にする",
          arguments: [("", ""), ("feed", ""), ("", "key"), ("feed", "key")])
    func availability(configuration: (String, String)) {
        #expect(UpdatePolicy.isEnabled(feedURL: configuration.0, publicKey: configuration.1)
            == (!configuration.0.isEmpty && !configuration.1.isEmpty))
    }
}
