import Foundation

/// 利用者の設定の保存値。既定値はこの型のプロパティの初期値だけが持つ。
///
/// ホットキーの割り当ては KeyboardShortcuts が保存するので、ここには持たない（DEC-KEY-002）。
public struct Settings: Hashable, Sendable {
    // MARK: 一般

    public var launchesAtLogin = true
    public var showsHUD = true
    public var showsMenuBarIcon = true
    public var showsDockIcon = false

    // MARK: 防止するスリープ

    public var blocksDisplaySleep = true
    /// 手動スリープと蓋閉じスリープをまとめて止める。
    public var blocksManualSleep = false
    public var lidCloseDisplay = LidCloseDisplay.turnOff

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
        case launchesAtLogin, showsHUD, showsMenuBarIcon, showsDockIcon
        case blocksDisplaySleep, blocksManualSleep, lidCloseDisplay
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
        showsHUD = value(.showsHUD, or: defaults.showsHUD)
        showsMenuBarIcon = value(.showsMenuBarIcon, or: defaults.showsMenuBarIcon)
        showsDockIcon = value(.showsDockIcon, or: defaults.showsDockIcon)
        blocksDisplaySleep = value(.blocksDisplaySleep, or: defaults.blocksDisplaySleep)
        blocksManualSleep = value(.blocksManualSleep, or: defaults.blocksManualSleep)
        lidCloseDisplay = value(.lidCloseDisplay, or: defaults.lidCloseDisplay)
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
