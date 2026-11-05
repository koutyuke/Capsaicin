/// 含意によってオンになっている原因。
public enum ImplicationCause: Hashable, Sendable {
    case displaySleep
    /// 手動スリープ（変種 B ではまとめた行）。
    case manualSleep
}

/// 「止めるスリープ」の1行の表示。
public enum SleepSettingRowState: Hashable, Sendable {
    /// その Mac にないハードウェアの項目なので表示しない。
    case hidden
    /// 保存値を表示し、操作できる。
    case editable(isOn: Bool)
    /// ヘルパーが要る行の保存値がオンなのに、ヘルパーが正しく設置されていない。保存値のオンを注意の記号付きで表示する。
    case onWithoutHelper
    /// 含意による無効。オンを無効のスイッチで表示する。原因は表示の順に並べる。
    case implied([ImplicationCause])
    /// 前提による無効。保存値を無効のスイッチで表示する。
    case prerequisiteUnmet(isOn: Bool)
}

/// 設定画面の「止めるスリープ」の各行の表示。
public struct SleepSettingsPresentation: Hashable, Sendable {
    public var idleSleep: SleepSettingRowState
    public var displaySleep: SleepSettingRowState
    /// 手動スリープの行。`manualRowIncludesLidSleep` が true なら「手動スリープと蓋閉じスリープ」の行。
    public var manualSleep: SleepSettingRowState
    /// 変種 A だけの行。
    public var lidSleep: SleepSettingRowState
    public var turnsOffDisplayOnLidClose: SleepSettingRowState
    /// 変種 B で蓋のある Mac のとき、手動スリープの行が蓋閉じスリープをまとめた行になる。
    public var manualRowIncludesLidSleep: Bool

    public init(settings: Settings, capabilities: MachineCapabilities, isHelperInstalled: Bool) {
        let isVariantA = capabilities.canBlockLidSleepAlone
        // 「手動」: 保存値がオンでヘルパーが正しく設置されているときだけ、含意に数える。
        let manualActive = settings.blocksManualSleep && isHelperInstalled

        var idleCauses: [ImplicationCause] = []
        if settings.blocksDisplaySleep {
            idleCauses.append(.displaySleep)
        }
        if manualActive {
            idleCauses.append(.manualSleep)
        }
        idleSleep = idleCauses.isEmpty ? .editable(isOn: settings.blocksIdleSleep) : .implied(idleCauses)

        displaySleep = .editable(isOn: settings.blocksDisplaySleep)

        manualSleep = settings.blocksManualSleep && !isHelperInstalled
            ? .onWithoutHelper
            : .editable(isOn: settings.blocksManualSleep)
        manualRowIncludesLidSleep = !isVariantA && capabilities.hasLid

        if isVariantA, capabilities.hasLid {
            lidSleep = manualActive ? .implied([.manualSleep]) : .editable(isOn: settings.blocksLidSleep)
        } else {
            lidSleep = .hidden
        }

        if capabilities.hasLid {
            let lidSleepBlocked = manualActive || (isVariantA && settings.blocksLidSleep)
            turnsOffDisplayOnLidClose = lidSleepBlocked
                ? .editable(isOn: settings.turnsOffDisplayOnLidClose)
                : .prerequisiteUnmet(isOn: settings.turnsOffDisplayOnLidClose)
        } else {
            turnsOffDisplayOnLidClose = .hidden
        }
    }
}
