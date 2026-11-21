import CapsaicinCore
import CapsaicinCoreTesting
import CapsaicinPlatform
import Foundation
import Testing

extension SettingsTests {
    @Test("SPEC-SET-005 SPEC-SET-003 ヘルパーの4状態と保存値に応じて選択肢、スイッチ、説明文を出し分ける",
          arguments: [false, true], [HelperInstallationState.notInstalled, .requiresApproval, .unavailable, .installed])
    func helperAvailability(hasLid: Bool, helper: HelperInstallationState) {
        let capabilities = MachineCapabilities(hasLid: hasLid, hasInternalBattery: hasLid)
        let installed = helper == .installed
        for savedOn in [false, true] {
            var settings = CapsaicinCore.Settings()
            settings.blocksManualSleep = savedOn
            let rows = SettingsSleepRow.rows(settings: settings, capabilities: capabilities, helper: helper,
                                             brightnessUnavailable: false)
            let row = rows[1]
            #expect(rows[0].isToggleEnabled && rows[0].warning.isEmpty)
            #expect(rows[0].help == SettingsSection.sleep.text("display.help"))
            #expect(row.isOn == savedOn)
            if hasLid {
                let choices = SettingsLidCloseChoice.allCases.filter { row.canSelect($0) }
                #expect(choices == (installed ? [.sleep, .turnOff, .zeroBrightness, .keepOn] : [.sleep]))
            } else {
                #expect(row.isToggleEnabled == (installed || savedOn))
            }

            var lines: [String] = []
            let expectedWarning = !installed && savedOn ? SettingsSection.sleep.text("helperInactive") : ""
            #expect(row.warning == expectedWarning)
            #expect(row.warningLabel.isEmpty == expectedWarning.isEmpty)
            if !expectedWarning.isEmpty {
                lines.append(expectedWarning)
            } else if !installed {
                lines.append(SettingsSection.sleep.text(row.key + ".helperRequired"))
            }
            if !hasLid {
                lines.append(SettingsSection.sleep.text("manual.help"))
            }
            #expect(row.help == lines.joined(separator: "\n"))
        }
    }

    @Test("SPEC-SET-005 ヘルパーを使えないときに閉じたときの動作を選んでも、設定を保存せず確認も出さない",
          arguments: [HelperInstallationState.notInstalled, .requiresApproval, .unavailable],
          [SettingsLidCloseChoice.turnOff, .zeroBrightness, .keepOn])
    func ignoresUnavailableLidCloseChoice(state: HelperInstallationState, choice: SettingsLidCloseChoice) async {
        let fixture = AppFixture()
        let before = fixture.model.settings
        var current = HelperInstallationState.installed
        let model = SettingsModel(app: fixture.model, helper: .init(state: { current },
                                                                    perform: { _ in
                                                                        Issue.record("スリープ設定から登録した"); return .cancelled
                                                                    },
                                                                    completed: { _, _ in },
                                                                    openSystemSettings: { Issue.record("システム設定を開いた") }))
        model.confirm = { _ in Issue.record("スリープ設定から確認を出した"); return false }
        model.showError = { _, _ in Issue.record("選べない値でエラーを出した") }
        current = state // 開いているポップアップの表示より先にヘルパーの状態が変わった場合を確かめる。
        await model.changeLidClose(to: choice)
        #expect(model.helperState == state)
        #expect(model.lidCloseChoice == .sleep)
        #expect(fixture.model.settings == before && fixture.savedSettings.isEmpty)
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
        #expect(model.sleepRows[1].help.hasPrefix(SettingsSection.sleep.text("helperInactive")))
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

    @Test("SPEC-SET-005 ヘルパーを使えるときだけスイッチをオンにでき、使えなくてもオフに戻せる",
          arguments: [HelperInstallationState.notInstalled, .requiresApproval, .unavailable, .installed])
    func desktopManual(state: HelperInstallationState) async {
        let system = FakeSystem()
        var saves: [CapsaicinCore.Settings] = []
        let app = AppModel(controller: BlockingController(settings: CapsaicinCore.Settings(),
                                                          capabilities: MachineCapabilities(
                                                              hasLid: false,
                                                              hasInternalBattery: false,
                                                          ),
                                                          ports: system.ports), saveSettings: { saves.append($0) })
        var current = HelperInstallationState.installed
        let model = SettingsModel(app: app, helper: SettingsHelperActions(
            state: { current },
            perform: { _ in Issue.record("スリープ設定から登録した"); return .cancelled },
            completed: { _, _ in }, openSystemSettings: { Issue.record("システム設定を開いた") },
        ))
        model.confirm = { _ in Issue.record("スリープ設定から確認を出した"); return false }
        model.showError = { _, _ in Issue.record("選べない値でエラーを出した") }
        let row = model.sleepRows[1]
        current = state
        await model.changeSleep(row, to: true)
        let installed = state == .installed
        #expect(model.helperState == state)
        #expect(app.settings.blocksManualSleep == installed)
        #expect(saves.count == (installed ? 1 : 0))
        if !installed {
            var preset = app.settings
            preset.blocksManualSleep = true
            app.changeSettings(preset)
        }
        await model.changeSleep(model.sleepRows[1], to: false)
        #expect(!app.settings.blocksManualSleep)
        #expect(saves.count == 2 && saves.last == app.settings)
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
        var keys: [String] = []
        if choice != .sleep, helper != .installed {
            keys.append("helperInactive")
        }
        if choice == .zeroBrightness {
            keys.append("brightnessUnavailable")
        }
        let warnings = keys.map { SettingsSection.sleep.text($0) }.joined(separator: "\n")
        #expect(row.warning == warnings && row.help.hasPrefix(warnings))
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
