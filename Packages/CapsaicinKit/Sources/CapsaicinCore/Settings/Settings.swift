import Foundation

/// 利用者の設定の保存値。既定値はこの型のプロパティの初期値だけが持つ。
///
/// ホットキーの割り当ては KeyboardShortcuts が保存するので、ここには持たない（DEC-KEY-002）。
public struct Settings: Hashable, Sendable {
    // MARK: 一般

    public var launchesAtLogin = true
    public var resumePolicy = ResumePolicy.never
    public var showsHUD = true

    // MARK: 止めるスリープ

    public var blocksIdleSleep = true
    public var blocksDisplaySleep = false
    /// 手動スリープ。変種 B のまとめた行も、この値を使う。
    public var blocksManualSleep = false
    public var blocksLidSleep = false
    public var turnsOffDisplayOnLidClose = true

    // MARK: 解除の条件

    public var timerEnabled = false
    public var timerDuration = TimerDuration(minutes: 60)!
    public var specifiedTimeEnabled = false
    public var specifiedTime = TimeOfDay(hour: 4, minute: 0)!
    public var batteryConditionEnabled = true
    public var batteryThreshold = BatteryThreshold(percent: 20)!
    public var ignoresBatteryOnACPower = true

    // MARK: LED

    public var notifiesWithLED = true

    // MARK: 操作

    public var acceptsCLIRequests = true

    public init() {}
}

/// 保存の形式。未知のキーは無視し、欠けたキーと読めない値は既定値で補う。
extension Settings: Codable {
    private enum CodingKeys: String, CodingKey {
        case launchesAtLogin, resumePolicy, showsHUD
        case blocksIdleSleep, blocksDisplaySleep, blocksManualSleep, blocksLidSleep, turnsOffDisplayOnLidClose
        case timerEnabled, timerDuration, specifiedTimeEnabled, specifiedTime
        case batteryConditionEnabled, batteryThreshold, ignoresBatteryOnACPower
        case notifiesWithLED, acceptsCLIRequests
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, or fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let defaults = Settings()
        launchesAtLogin = value(.launchesAtLogin, or: defaults.launchesAtLogin)
        resumePolicy = value(.resumePolicy, or: defaults.resumePolicy)
        showsHUD = value(.showsHUD, or: defaults.showsHUD)
        blocksIdleSleep = value(.blocksIdleSleep, or: defaults.blocksIdleSleep)
        blocksDisplaySleep = value(.blocksDisplaySleep, or: defaults.blocksDisplaySleep)
        blocksManualSleep = value(.blocksManualSleep, or: defaults.blocksManualSleep)
        blocksLidSleep = value(.blocksLidSleep, or: defaults.blocksLidSleep)
        turnsOffDisplayOnLidClose = value(.turnsOffDisplayOnLidClose, or: defaults.turnsOffDisplayOnLidClose)
        timerEnabled = value(.timerEnabled, or: defaults.timerEnabled)
        timerDuration = value(.timerDuration, or: defaults.timerDuration)
        specifiedTimeEnabled = value(.specifiedTimeEnabled, or: defaults.specifiedTimeEnabled)
        specifiedTime = value(.specifiedTime, or: defaults.specifiedTime)
        batteryConditionEnabled = value(.batteryConditionEnabled, or: defaults.batteryConditionEnabled)
        batteryThreshold = value(.batteryThreshold, or: defaults.batteryThreshold)
        ignoresBatteryOnACPower = value(.ignoresBatteryOnACPower, or: defaults.ignoresBatteryOnACPower)
        notifiesWithLED = value(.notifiesWithLED, or: defaults.notifiesWithLED)
        acceptsCLIRequests = value(.acceptsCLIRequests, or: defaults.acceptsCLIRequests)
    }
}
