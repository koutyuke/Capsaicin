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

    @Test("SPEC-SET-005 画面の自動消灯を止めると、自動スリープは保存値によらず含意による無効になる")
    func displayImpliesIdle() {
        let rows = present(.premise {
            $0.blocksIdleSleep = false
            $0.blocksDisplaySleep = true
        })
        #expect(rows.idleSleep == .implied([.displaySleep]))
        #expect(rows.displaySleep == .editable(isOn: true))
    }

    @Test("SPEC-SET-005 含意している側がオフなら保存値の表示に戻る")
    func backToSavedValue() {
        let rows = present(.premise { $0.blocksIdleSleep = false })
        #expect(rows.idleSleep == .editable(isOn: false))
        #expect(rows.lidSleep == .editable(isOn: false))
    }

    @Test("SPEC-SET-005 手動スリープは自動スリープと蓋閉じスリープを含意し、原因が2つなら両方を示す")
    func manualImpliesIdleAndLid() {
        let rows = present(.premise {
            $0.blocksDisplaySleep = true
            $0.blocksManualSleep = true
        })
        #expect(rows.idleSleep == .implied([.displaySleep, .manualSleep]))
        #expect(rows.lidSleep == .implied([.manualSleep]))
        #expect(rows.turnsOffDisplayOnLidClose == .editable(isOn: true))
    }

    @Test("SPEC-SET-005 ヘルパーが正しく設置されていなければ、手動スリープは注意付きで含意に数えない")
    func manualWithoutHelper() {
        let rows = present(.premise {
            $0.blocksIdleSleep = false
            $0.blocksManualSleep = true
        }, helper: false)
        #expect(rows.manualSleep == .onWithoutHelper)
        #expect(rows.idleSleep == .editable(isOn: false))
        #expect(rows.lidSleep == .editable(isOn: false))
        #expect(rows.turnsOffDisplayOnLidClose == .prerequisiteUnmet(isOn: true))
    }

    @Test("SPEC-SET-005 蓋を閉じたら画面を消すは、変種 A では蓋閉じスリープを止めているときだけ使える")
    func lidCloseDisplayVariantA() {
        #expect(present(.premise()).turnsOffDisplayOnLidClose == .prerequisiteUnmet(isOn: true))
        let lid = present(.premise { $0.blocksLidSleep = true })
        #expect(lid.turnsOffDisplayOnLidClose == .editable(isOn: true))
    }

    @Test("SPEC-SET-005 変種 B は蓋閉じスリープをまとめた1行にし、蓋閉じスリープの保存値では画面を消す行を使えない")
    func variantB() {
        let rows = present(.premise { $0.blocksLidSleep = true }, .laptopVariantB)
        #expect(rows.manualRowIncludesLidSleep)
        #expect(rows.lidSleep == .hidden)
        #expect(rows.turnsOffDisplayOnLidClose == .prerequisiteUnmet(isOn: true))
        let manual = present(.premise { $0.blocksManualSleep = true }, .laptopVariantB)
        #expect(manual.turnsOffDisplayOnLidClose == .editable(isOn: true))
    }

    @Test("SPEC-SET-006 蓋のない Mac では蓋に関する行を表示せず、まとめた行にもしない")
    func noLid() {
        let rows = present(.premise(), .desktop)
        #expect(rows.lidSleep == .hidden)
        #expect(rows.turnsOffDisplayOnLidClose == .hidden)
        #expect(!rows.manualRowIncludesLidSleep)
        let variantB = MachineCapabilities(hasLid: false, hasInternalBattery: false, canBlockLidSleepAlone: false)
        #expect(!present(.premise(), variantB).manualRowIncludesLidSleep)
    }
}
