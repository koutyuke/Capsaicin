@testable import CapsaicinCore
import Testing

struct SleepSettingsPresentationTests {
    private func present(
        _ settings: Settings,
        _ capabilities: MachineCapabilities = .laptop,
        helper: Bool = true,
    ) -> SleepSettingsPresentation {
        SleepSettingsPresentation(settings: settings, capabilities: capabilities, isHelperInstalled: helper)
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

    @Test("SPEC-SET-005 閉じたときの画面は親がオンでヘルパーがあるときだけ操作でき、保存値は保つ",
          arguments: [false, true], [false, true])
    func lidDisplayPrerequisites(manual: Bool, helper: Bool) {
        for display in LidCloseDisplay.allCases {
            let settings = Settings.premise {
                $0.blocksManualSleep = manual
                $0.lidCloseDisplay = display
            }
            let rows = present(settings, helper: helper)
            let selected = display == .turnOff
            #expect(rows.lidCloseDisplay == (manual && helper
                    ? .editable(isOn: selected) : .prerequisiteUnmet(isOn: selected)))
        }
    }

    @Test("SPEC-SET-006 蓋のない Mac では閉じたときの画面を表示しない")
    func noLid() {
        let rows = present(.premise { $0.blocksManualSleep = true }, .desktop)
        #expect(rows.displaySleep == .editable(isOn: false))
        #expect(rows.manualSleep == .editable(isOn: true))
        #expect(rows.lidCloseDisplay == .hidden)
    }
}
