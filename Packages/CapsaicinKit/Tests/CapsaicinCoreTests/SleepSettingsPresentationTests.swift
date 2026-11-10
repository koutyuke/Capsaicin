@testable import CapsaicinCore
import Testing

struct SleepSettingsPresentationTests {
    private func present(
        _ settings: Settings,
        helper: Bool = true,
    ) -> SleepSettingsPresentation {
        SleepSettingsPresentation(settings: settings, isHelperInstalled: helper)
    }

    @Test("SPEC-SET-005 画面の行は保存値のまま常に操作できる", arguments: [false, true], [false, true])
    func displayAlwaysEditable(saved: Bool, helper: Bool) {
        let rows = present(.premise { $0.blocksDisplaySleep = saved }, helper: helper)
        #expect(rows.displaySleep == .editable(isOn: saved))
    }

    @Test("SPEC-SET-005 手動の行はヘルパー不足で保存値がオンのときだけ注意を表示する")
    func manualWithoutHelper() {
        #expect(present(.premise(), helper: false).manualSleep == .editable(isOn: false))
        #expect(present(.premise { $0.blocksManualSleep = true }, helper: false).manualSleep == .onWithoutHelper)
        #expect(present(.premise { $0.blocksManualSleep = true }).manualSleep == .editable(isOn: true))
    }

    @Test("SPEC-SET-005 閉じたときのディスプレイの保存値で操作可否は変わらない",
          arguments: [false, true], [false, true])
    func lidDisplayDoesNotDisableRow(manual: Bool, helper: Bool) {
        for display in LidCloseDisplay.allCases {
            let settings = Settings.premise {
                $0.blocksManualSleep = manual
                $0.lidCloseDisplay = display
            }
            let rows = present(settings, helper: helper)
            #expect(rows.manualSleep == (manual && !helper ? .onWithoutHelper : .editable(isOn: manual)))
        }
    }
}
