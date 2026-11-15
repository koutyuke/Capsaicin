public enum SleepSettingRowState: Hashable, Sendable {
    case editable(isOn: Bool)
    /// ヘルパーが要る行の保存値がオンなのに、ヘルパーが正しく設置されていない。保存値のオンを注意の記号付きで表示する。
    case onWithoutHelper
}

public struct SleepSettingsPresentation: Hashable, Sendable {
    public var displaySleep: SleepSettingRowState
    public var manualSleep: SleepSettingRowState

    public init(settings: Settings, isHelperInstalled: Bool) {
        displaySleep = .editable(isOn: settings.blocksDisplaySleep)

        manualSleep = settings.blocksManualSleep && !isHelperInstalled
            ? .onWithoutHelper
            : .editable(isOn: settings.blocksManualSleep)
    }
}
