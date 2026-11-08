/// 保存値と機器の能力から求めた、抑止と解除の判定に使う設定値。
public struct EffectiveSettings: Hashable, Sendable {
    public var blocksDisplaySleep: Bool
    /// ヘルパーの状態によらず保存値を使う。ヘルパーが使えないときの扱いは開始の判定が持つ。
    public var blocksManualSleep: Bool
    /// 蓋を閉じたら画面を消すか。蓋のある Mac で、手動スリープと蓋閉じスリープを止め、閉じたときの画面が「消灯」のときだけ true。
    public var shouldSleepDisplayOnLidClose: Bool
    /// 内蔵バッテリーのある Mac で条件がオンのときだけある。
    public var batteryCondition: BatteryCondition?
    public var notifiesWithLED: Bool

    public init(settings: Settings, capabilities: MachineCapabilities) {
        blocksDisplaySleep = settings.blocksDisplaySleep
        blocksManualSleep = settings.blocksManualSleep
        shouldSleepDisplayOnLidClose = capabilities.hasLid && blocksManualSleep && settings.lidCloseDisplay == .turnOff
        batteryCondition = capabilities.hasInternalBattery && settings.batteryConditionEnabled
            ? BatteryCondition(threshold: settings.batteryThreshold, ignoresOnACPower: settings.ignoresBatteryOnACPower)
            : nil
        notifiesWithLED = settings.notifiesWithLED
    }

    /// 抑止中に適用する仕組み。自動スリープは常に止める。
    public var mechanisms: Set<Mechanism> {
        var result: Set<Mechanism> = [.idleSleepAssertion]
        if blocksDisplaySleep {
            result.insert(.displaySleepAssertion)
        }
        if blocksManualSleep {
            result.insert(.systemSleepDisabled)
        }
        if notifiesWithLED {
            result.insert(.led)
        }
        return result
    }
}
