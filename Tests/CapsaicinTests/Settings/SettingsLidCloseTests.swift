import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Testing

extension SettingsTests {
    @Test("SPEC-SET-003 SPEC-SET-005 状態の文は保存値がヘルパーを必要とし、ヘルパーを使えない行だけに出す",
          arguments: [false, true], [HelperInstallationState.notInstalled, .requiresApproval, .unavailable, .installed])
    func helperStatusSubtitle(hasLid: Bool, helper: HelperInstallationState) {
        var settings = CapsaicinCore.Settings()
        let capabilities = MachineCapabilities(hasLid: hasLid, hasInternalBattery: hasLid)
        let disabled = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: helper,
                                             brightnessUnavailable: false)
        #expect(disabled.allSatisfy { $0.subtitle == nil })
        settings.blocksManualSleep = true
        let enabled = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: helper,
                                            brightnessUnavailable: false)
        #expect(enabled[0].subtitle == nil)
        #expect(enabled[1].subtitle == (helper == .installed ? nil : SettingsSection.sleep.text("helperNotEnabled")))
        #expect((enabled[1].subtitle != nil) == !enabled[1].warningLabel.isEmpty)
    }

    @Test("SPEC-SET-005 ポップアップは保存値の4通りを表示し、オフの間はディスプレイの保存値を隠す",
          arguments: [false, true], LidCloseDisplay.allCases)
    func lidCloseSelection(manual: Bool, display: LidCloseDisplay) {
        var settings = CapsaicinCore.Settings()
        settings.blocksManualSleep = manual
        settings.lidCloseDisplay = display
        #expect(SettingsLidCloseChoice(settings: settings).rawValue == (manual ? display.rawValue : "sleep"))
        #expect(SettingsLidCloseChoice.allCases == [.sleep, .turnOff, .zeroBrightness, .keepOn])
    }

    @Test("SPEC-SET-005 ヘルパー設置済みなら2値を1回で保存し、スリープを選ぶとディスプレイの保存値を保つ",
          arguments: [SettingsLidCloseChoice.turnOff, .zeroBrightness, .keepOn])
    func installedLidClose(choice: SettingsLidCloseChoice) async throws {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { .installed }, perform: { _ in Issue.record("設置済みなのに設置を要求した"); return .cancelled },
            completed: { _, _ in },
        ))
        await model.changeLidClose(to: choice)
        #expect(model.lidCloseChoice == choice)
        #expect(fixture.model.settings.blocksManualSleep)
        let savedDisplay = try #require(LidCloseDisplay(rawValue: choice.rawValue))
        #expect(fixture.model.settings.lidCloseDisplay == savedDisplay)
        #expect(fixture.savedSettings == [fixture.model.settings])
        await model.changeLidClose(to: .sleep)
        #expect(model.lidCloseChoice == .sleep)
        #expect(!fixture.model.settings.blocksManualSleep)
        #expect(fixture.model.settings.lidCloseDisplay == savedDisplay)
        #expect(fixture.savedSettings.count == 2)
    }

    @Test("SPEC-SET-005 承認待ちでも保存した選択を表示し、設置せずスリープへ戻せる",
          arguments: LidCloseDisplay.allCases)
    func brokenHelperLidClose(display: LidCloseDisplay) async {
        let fixture = AppFixture()
        var settings = fixture.model.settings
        settings.blocksManualSleep = true
        settings.lidCloseDisplay = display
        fixture.model.changeSettings(settings)
        fixture.savedSettings.removeAll()
        let model = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { .requiresApproval }, perform: { _ in Issue.record("スリープへ戻すのに設置を要求した"); return .cancelled },
            completed: { _, _ in },
        ))
        #expect(model.lidCloseChoice.rawValue == display.rawValue)
        #expect(model.sleepRows[1].state == .onWithoutHelper)
        #expect(model.sleepRows[1].help.hasPrefix(SettingsSection.sleep.text("helperRequiresApproval")))
        await model.changeLidClose(to: .sleep)
        #expect(model.sleepRows[1].state == .editable(isOn: false))
        #expect(model.lidCloseChoice == .sleep)
        #expect(fixture.model.settings.lidCloseDisplay == display)
        #expect(fixture.savedSettings == [fixture.model.settings])
    }

    @Test("SPEC-SET-005 SPEC-BLK-009 反映失敗ではポップアップと2値をまとめて戻す")
    func lidCloseRollback() async {
        let fixture = AppFixture()
        fixture.model.finishLaunching()
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

    @Test("SPEC-SET-005 SPEC-HLP-001 MacBook以外のスイッチも設置成功後だけ保存する",
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

    @Test("SPEC-SET-005 明るさを0を選んだときだけ輝度の注意を出し、ヘルパーの注意を先頭に置く",
          arguments: SettingsLidCloseChoice.allCases, [
              HelperInstallationState.installed,
              .requiresApproval,
              .notInstalled,
              .unavailable,
          ])
    func brightnessWarning(choice: SettingsLidCloseChoice, helper: HelperInstallationState) async throws {
        let fixture = AppFixture()
        let model = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { .installed }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        await model.changeLidClose(to: choice)
        #expect(model.sleepRows[1].warningLabel.isEmpty)
        fixture.system.isKnownUnavailable = true
        let unavailable = SettingsModel(app: fixture.model, helper: SettingsHelperActions(
            state: { helper }, perform: { _ in .cancelled }, completed: { _, _ in },
        ))
        let row = unavailable.sleepRows[1]
        #expect(row.subtitle == (choice != .sleep && helper != .installed
                ? SettingsSection.sleep.text("helperNotEnabled") : nil))
        var keys: [String] = []
        if choice != .sleep, helper != .installed {
            let key = switch helper {
            case .notInstalled: "helperNotInstalled"
            case .requiresApproval: "helperRequiresApproval"
            case .unavailable: "helperUnavailable"
            case .installed: ""
            }
            keys.append(key)
        }
        if choice == .zeroBrightness {
            keys.append("brightnessUnavailable")
        }
        #expect(row.help == (keys + ["lidClose.help"]).map { SettingsSection.sleep.text($0) }.joined(separator: "\n"))
        #expect(row.warningLabel == keys.map { SettingsSection.sleep.text($0 + ".a11y") }.formatted(.list(type: .and)))
        #expect(unavailable.lidCloseChoice == choice)
        #expect(!unavailable.isBusy)
        let bundle = try localizedAppBundle("ja")
        #expect(bundle.localizedString(forKey: "brightnessUnavailable.a11y", value: nil, table: "SettingsSleep")
            == "警告、画面の明るさを変更できません")
        #expect(bundle
            .localizedString(forKey: "lidClose.zeroBrightness", value: nil, table: "SettingsSleep") == "明るさを0")
    }
}
