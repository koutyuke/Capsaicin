/// 保存値と機器の能力から求めた、抑止と解除の判定に使う設定値。
public struct EffectiveSettings: Hashable, Sendable {
    public var blocksIdleSleep: Bool
    public var blocksDisplaySleep: Bool
    /// ヘルパーの状態によらず保存値を使う。ヘルパーが使えないときの扱いは開始の判定が持つ。
    public var blocksManualSleep: Bool
    /// 変種 A で蓋のある Mac のときだけ保存値。
    public var blocksLidSleep: Bool
    /// 蓋を閉じたら画面を消すか。蓋のある Mac で、蓋閉じスリープが実際に止まるときだけ true。
    public var turnsOffDisplayOnLidClose: Bool
    /// 内蔵バッテリーのある Mac で条件がオンのときだけある。
    public var batteryCondition: BatteryCondition?
    public var notifiesWithLED: Bool

    public init(settings: Settings, capabilities: MachineCapabilities) {
        blocksIdleSleep = settings.blocksIdleSleep
        blocksDisplaySleep = settings.blocksDisplaySleep
        blocksManualSleep = settings.blocksManualSleep
        blocksLidSleep = capabilities.usesLidSleepControl && settings.blocksLidSleep
        // 手動スリープを止めると蓋閉じスリープも止まる（DEC-BLK-004）。
        turnsOffDisplayOnLidClose = capabilities.hasLid && settings.turnsOffDisplayOnLidClose
            && (blocksLidSleep || blocksManualSleep)
        batteryCondition = capabilities.hasInternalBattery && settings.batteryConditionEnabled
            ? BatteryCondition(threshold: settings.batteryThreshold, ignoresOnACPower: settings.ignoresBatteryOnACPower)
            : nil
        notifiesWithLED = settings.notifiesWithLED
    }

    /// 抑止中に適用する仕組み。止めるスリープの含意は仕組みの側で成り立つ（DEC-BLK-001、DEC-BLK-004）ので、設定と1対1に対応させる。
    public var mechanisms: Set<Mechanism> {
        var result: Set<Mechanism> = []
        if blocksIdleSleep {
            result.insert(.idleSleepAssertion)
        }
        if blocksDisplaySleep {
            result.insert(.displaySleepAssertion)
        }
        if blocksLidSleep {
            result.insert(.lidSleepControl)
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
