/// 電源の状態。
public struct PowerState: Hashable, Sendable {
    /// 内蔵バッテリーの残量（%）。内蔵バッテリーがないか読めなければ nil。
    public var batteryLevel: Int?
    public var isOnACPower: Bool

    public init(batteryLevel: Int?, isOnACPower: Bool) {
        self.batteryLevel = batteryLevel
        self.isOnACPower = isOnACPower
    }
}

/// 抑止に使うバッテリー残量の条件。
public struct BatteryCondition: Hashable, Sendable, Codable {
    public var threshold: BatteryThreshold
    public var ignoresOnACPower: Bool

    public init(threshold: BatteryThreshold, ignoresOnACPower: Bool) {
        self.threshold = threshold
        self.ignoresOnACPower = ignoresOnACPower
    }

    /// 残量がしきい値を下回り、電源アダプターによって無視されないときに成り立つ。残量が分からなければ成り立たない。
    public func isMet(by power: PowerState) -> Bool {
        guard let level = power.batteryLevel, level < threshold.percent else { return false }
        return !(power.isOnACPower && ignoresOnACPower)
    }
}
