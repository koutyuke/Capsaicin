/// 使っている間に変わらない機器の能力。起動時に判定して渡す。
public struct MachineCapabilities: Hashable, Sendable {
    public var hasLid: Bool
    public var hasInternalBattery: Bool
    /// 蓋閉じスリープだけをヘルパーなしで止められるか。true なら設定画面は変種 A、false なら変種 B。
    public var canBlockLidSleepAlone: Bool

    /// 蓋閉じスリープの制御を使うか。変種 A で蓋のある Mac のときだけ使う。
    public var usesLidSleepControl: Bool {
        hasLid && canBlockLidSleepAlone
    }

    public init(hasLid: Bool, hasInternalBattery: Bool, canBlockLidSleepAlone: Bool) {
        self.hasLid = hasLid
        self.hasInternalBattery = hasInternalBattery
        self.canBlockLidSleepAlone = canBlockLidSleepAlone
    }
}
