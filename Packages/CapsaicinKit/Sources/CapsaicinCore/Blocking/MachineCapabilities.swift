/// 使っている間に変わらない機器の能力。起動時に判定して渡す。
public struct MachineCapabilities: Hashable, Sendable {
    public var hasLid: Bool
    public var hasInternalBattery: Bool
    public init(hasLid: Bool, hasInternalBattery: Bool) {
        self.hasLid = hasLid
        self.hasInternalBattery = hasInternalBattery
    }
}
