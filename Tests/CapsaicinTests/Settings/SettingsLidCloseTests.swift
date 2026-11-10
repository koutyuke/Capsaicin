import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Testing

extension SettingsTests {
    @Test("SPEC-SET-005 ポップアップは保存値の3通りを表示し、オフの間はディスプレイの保存値を隠す",
          arguments: [false, true], LidCloseDisplay.allCases)
    func lidCloseSelection(manual: Bool, display: LidCloseDisplay) {
        var settings = CapsaicinCore.Settings()
        settings.blocksManualSleep = manual
        settings.lidCloseDisplay = display
        #expect(SettingsLidCloseChoice(settings: settings) == (manual
                ? (display == .turnOff ? .turnOff : .keepOn) : .sleep))
        #expect(SettingsLidCloseChoice.allCases == [.sleep, .turnOff, .keepOn])
    }

    @Test("SPEC-SET-005 ヘルパー設置済みなら2値を1回で保存し、スリープを選ぶとディスプレイの保存値を保つ",
          arguments: [SettingsLidCloseChoice.turnOff, .keepOn])
    func installedLidClose(choice: SettingsLidCloseChoice) async {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { .installed }, perform: { _ in Issue.record("設置済みなのに設置を要求した"); return .cancelled },
            completed: { _, _ in },
        ))
        await model.changeLidClose(to: choice)
        #expect(model.lidCloseChoice == choice)
        #expect(fixture.model.settings.blocksManualSleep)
        let savedDisplay: LidCloseDisplay = choice == .turnOff ? .turnOff : .keepOn
        #expect(fixture.model.settings.lidCloseDisplay == savedDisplay)
        #expect(fixture.savedSettings == [fixture.model.settings])
        await model.changeLidClose(to: .sleep)
        #expect(model.lidCloseChoice == .sleep)
        #expect(!fixture.model.settings.blocksManualSleep)
        #expect(fixture.model.settings.lidCloseDisplay == savedDisplay)
        #expect(fixture.savedSettings.count == 2)
    }

    @Test("SPEC-SET-005 壊れたヘルパーでも保存した選択を表示し、設置せずスリープへ戻せる",
          arguments: LidCloseDisplay.allCases)
    func brokenHelperLidClose(display: LidCloseDisplay) async {
        let fixture = AppFixture()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        settings.lidCloseDisplay = display
        fixture.model.changeSettings(settings)
        fixture.savedSettings.removeAll()
        let model = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { .partial }, perform: { _ in Issue.record("スリープへ戻すのに設置を要求した"); return .cancelled },
            completed: { _, _ in },
        ))
        #expect(model.lidCloseChoice == (display == .turnOff ? .turnOff : .keepOn))
        #expect(model.sleepRows[1].state == .onWithoutHelper)
        #expect(model.sleepRows[1].help.hasPrefix(SettingsSection.sleep.text("helperNotReady")))
        await model.changeLidClose(to: .sleep)
        #expect(model.sleepRows[1].state == .editable(isOn: false))
        #expect(model.lidCloseChoice == .sleep)
        #expect(fixture.model.settings.lidCloseDisplay == display)
        #expect(fixture.savedSettings == [fixture.model.settings])
    }

    @Test("SPEC-SET-005 SPEC-BLK-009 反映失敗ではポップアップと2値をまとめて戻す")
    func lidCloseRollback() async {
        let fixture = AppFixture()
        fixture.model.launch()
        fixture.model.requestStart(from: .menu)
        fixture.system.failing = [.helperOn]
        let before = fixture.model.settings
        let model = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        var errors = 0
        model.showError = { _, _ in errors += 1 }
        await model.changeLidClose(to: .keepOn)
        #expect(model.lidCloseChoice == .sleep)
        #expect(fixture.model.settings == before)
        #expect(fixture.savedSettings.isEmpty && errors == 1)
    }

    @Test("SPEC-SET-005 SPEC-HLP-001 蓋のない Mac のスイッチも設置成功後だけ保存する",
          arguments: [false, true])
    func desktopManual(accepts: Bool) async throws {
        let system = FakeSystem()
        let app = AppModel(controller: BlockingController(settings: CapsaicinCore.Settings(),
                                                          capabilities: MachineCapabilities(
                                                              hasLid: false,
                                                              hasInternalBattery: false,
                                                          ),
                                                          ports: system.ports), saveSettings: { _ in })
        var installed = false
        let model = SettingsModel(app: app, helper: SettingsHelperActions(
            state: { installed ? .installed : .notInstalled }, perform: { _ in installed = true; return .success },
            completed: { _, _ in },
        ))
        model.confirm = { _, fromSetting in
            #expect(fromSetting && model.pendingManual && model.isBusy)
            #expect(!app.settings.blocksManualSleep)
            return accepts
        }
        let row = try #require(model.sleepRows.first { $0.key == "manual" })
        await model.changeSleep(row, to: true)
        #expect(app.settings.blocksManualSleep == accepts)
        #expect(installed == accepts)
        #expect(!model.pendingManual && !model.isBusy)
    }
}
