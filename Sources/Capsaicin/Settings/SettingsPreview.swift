#if DEBUG
    import CapsaicinCore
    import CapsaicinPlatform
    import SwiftUI

    /// OS に触れないポート。抑止の操作はすべて成功したことにする。
    @MainActor
    private final class PreviewSystem: PowerAssertionControlling, HelperSleepControlling, CapsLockLEDControlling,
        PowerStateProviding, BootTimeProviding, ResumeRecordStoring, TimeProviding, BuiltInDisplayBrightnessControlling
    {
        let isHelperInstalled: Bool
        let isAvailable = true
        let isKnownUnavailable = false
        let powerState = PowerState(batteryLevel: 80, isOnACPower: true)
        let bootTime = Date.distantPast
        var now: Date {
            Date()
        }

        let calendar = Calendar.current

        init(isHelperInstalled: Bool) {
            self.isHelperInstalled = isHelperInstalled
        }

        func createAssertion(_: AssertionKind) {}
        func releaseAssertion(_: AssertionKind) {}
        func readSleepDisabled() -> Bool {
            false
        }

        func turnOn() {}
        func turnOff() {}
        func setLit(_: Bool) {}
        func readBrightness() -> Float? {
            nil
        }

        func setBrightness(_: Float) {}
        func load() -> ResumeRecord? {
            nil
        }

        func save(_: ResumeRecord) -> Bool {
            true
        }
    }

    /// 設定画面を Xcode の Canvas に出す。ウィンドウ（ツールバー、確認のシート）は `SettingsWindowController` の役割なので再現しない。
    @MainActor
    private func settingsPreview(capabilities: MachineCapabilities, helper: HelperInstallationState,
                                 launchAgent: LaunchAgentStatus) -> some View
    {
        let system = PreviewSystem(isHelperInstalled: helper == .installed)
        let app = AppModel(
            controller: BlockingController(
                settings: Settings(),
                capabilities: capabilities,
                ports: .init(assertions: system, helper: system, led: system, brightness: system, power: system,
                             bootTime: system, records: system, time: system),
            ),
            saveSettings: { _ in },
        )
        app.launchAgentStatus = launchAgent
        let model = SettingsModel(
            app: app,
            helper: SettingsHelperActions(state: { helper }, perform: { _ in .cancelled }, completed: { _, _ in }),
        )
        // 選んだセクションを Canvas の再描画をまたいで残す。アプリの設定とは別の領域に書く。
        let defaults = UserDefaults(suiteName: "io.github.koutyuke.capsaicin.preview") ?? .standard
        return SettingsView(model: model, hotkey: HotkeyController(save: { _ in true }),
                            selection: SettingsSelection(defaults: defaults), quit: {})
            .frame(width: 720, height: 500)
    }

    #Preview("ノート、ヘルパーあり") {
        settingsPreview(capabilities: MachineCapabilities(hasLid: true, hasInternalBattery: true),
                        helper: .installed, launchAgent: .ready)
    }

    #Preview("デスクトップ、ヘルパーなし、バックグラウンド無効") {
        settingsPreview(capabilities: MachineCapabilities(hasLid: false, hasInternalBattery: false),
                        helper: .notInstalled, launchAgent: .disabled)
    }
#endif
