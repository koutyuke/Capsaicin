public struct EffectiveSettings: Hashable, Sendable {
    public var blocksDisplaySleep: Bool
    /// ヘルパーの状態によらず保存値を使う。ヘルパーが使えないときの扱いは開始の判定が持つ。
    public var blocksManualSleep: Bool
    public var shouldSleepDisplayOnLidClose: Bool
    public var shouldZeroBrightnessOnLidClose: Bool
    public var batteryCondition: BatteryCondition?
    public var notifiesWithLED: Bool

    public init(settings: Settings, capabilities: MachineCapabilities) {
        blocksDisplaySleep = settings.blocksDisplaySleep
        blocksManualSleep = settings.blocksManualSleep
        shouldSleepDisplayOnLidClose = capabilities.hasLid && blocksManualSleep && settings.lidCloseDisplay == .turnOff
        shouldZeroBrightnessOnLidClose = capabilities.hasLid && blocksManualSleep
            && settings.lidCloseDisplay == .zeroBrightness
        batteryCondition = capabilities.hasInternalBattery && settings.batteryConditionEnabled
            ? BatteryCondition(threshold: settings.batteryThreshold, ignoresOnACPower: settings.ignoresBatteryOnACPower)
            : nil
        notifiesWithLED = settings.notifiesWithLED
    }

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
