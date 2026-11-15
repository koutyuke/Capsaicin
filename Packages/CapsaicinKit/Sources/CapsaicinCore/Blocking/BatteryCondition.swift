public struct PowerState: Hashable, Sendable {
    /// 内蔵バッテリーの残量（%）。内蔵バッテリーがないか読めなければ nil。
    public var batteryLevel: Int?
    public var isOnACPower: Bool

    public init(batteryLevel: Int?, isOnACPower: Bool) {
        self.batteryLevel = batteryLevel
        self.isOnACPower = isOnACPower
    }
}

public struct BatteryCondition: Hashable, Sendable, Codable {
    public var threshold: BatteryThreshold
    public var ignoresOnACPower: Bool

    public init(threshold: BatteryThreshold, ignoresOnACPower: Bool) {
        self.threshold = threshold
        self.ignoresOnACPower = ignoresOnACPower
    }

    public func isMet(by power: PowerState) -> Bool {
        guard let level = power.batteryLevel, level < threshold.percent else { return false }
        return !(power.isOnACPower && ignoresOnACPower)
    }
}
