/// 「防止するスリープ」の1行の表示。
public enum SleepSettingRowState: Hashable, Sendable {
    /// その Mac にないハードウェアの項目なので表示しない。
    case hidden
    /// 保存値を表示し、操作できる。
    case editable(isOn: Bool)
    /// ヘルパーが要る行の保存値がオンなのに、ヘルパーが正しく設置されていない。保存値のオンを注意の記号付きで表示する。
    case onWithoutHelper
    /// 前提による無効。保存値を無効のコントロールで表示する。
    case prerequisiteUnmet(isOn: Bool)
}

/// 設定画面の「防止するスリープ」の各行の表示。
public struct SleepSettingsPresentation: Hashable, Sendable {
    public var displaySleep: SleepSettingRowState
    public var manualSleep: SleepSettingRowState
    public var lidCloseDisplay: SleepSettingRowState

    public init(settings: Settings, capabilities: MachineCapabilities, isHelperInstalled: Bool) {
        displaySleep = .editable(isOn: settings.blocksDisplaySleep)

        manualSleep = settings.blocksManualSleep && !isHelperInstalled
            ? .onWithoutHelper
            : .editable(isOn: settings.blocksManualSleep)
        if capabilities.hasLid {
            let turnsOff = settings.lidCloseDisplay == .turnOff
            lidCloseDisplay = settings.blocksManualSleep && isHelperInstalled
                ? .editable(isOn: turnsOff)
                : .prerequisiteUnmet(isOn: turnsOff)
        } else {
            lidCloseDisplay = .hidden
        }
    }
}
