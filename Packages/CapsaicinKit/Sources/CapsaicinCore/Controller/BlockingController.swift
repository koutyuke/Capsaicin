import Foundation

/// 抑止を制御する。OS への作用はすべてポート越しに行い、状態が変わったら `onEvent` で通知する。
///
/// 時刻の経過は、少なくとも 1 分ごとと解除の時刻に `timePassed()` で伝える。
@MainActor
public final class BlockingController {
    public struct Ports {
        public var assertions: any PowerAssertionControlling
        public var helper: any HelperSleepControlling
        public var led: any CapsLockLEDControlling
        public var brightness: any BuiltInDisplayBrightnessControlling
        public var power: any PowerStateProviding
        public var brightnessRecords: any BrightnessRecordStoring
        public var time: any TimeProviding

        public init(
            assertions: any PowerAssertionControlling,
            helper: any HelperSleepControlling,
            led: any CapsLockLEDControlling,
            brightness: any BuiltInDisplayBrightnessControlling,
            power: any PowerStateProviding,
            brightnessRecords: any BrightnessRecordStoring,
            time: any TimeProviding,
        ) {
            self.assertions = assertions
            self.helper = helper
            self.led = led
            self.brightness = brightness
            self.power = power
            self.brightnessRecords = brightnessRecords
            self.time = time
        }
    }

    static let reconcileInterval: TimeInterval = 60

    public internal(set) var settings: Settings
    public let capabilities: MachineCapabilities
    public internal(set) var session: BlockingSession?
    public internal(set) var misalignments: Misalignments = [:]
    public var onEvent: ((BlockingEvent) -> Void)?

    let ports: Ports
    var ownsSleepDisabled = false
    /// SleepDisabled の値が残っていても、後片付けの役目があるとは限らない。
    var helperCleanupLost = false
    var savedBrightness: Float?
    var brightnessSaveFailed = false
    public internal(set) var nextBrightnessDeletionAttempt: Date?
    /// 仕組みごとの、適用していると見込める状態。キーがなければ分からない。
    var observed: [Mechanism: Bool]
    var lastAlignment: Date?
    var keepsBrightnessZero = false

    public init(settings: Settings, capabilities: MachineCapabilities, ports: Ports) {
        self.settings = settings
        self.capabilities = capabilities
        self.ports = ports
        // アサーションはプロセスとともに消えるので、作っていないと分かる。ほかは前のプロセスから残っているかもしれない。
        observed = [.idleSleepAssertion: false, .displaySleepAssertion: false]
    }

    public var isBlocking: Bool {
        session != nil
    }

    public var effectiveSettings: EffectiveSettings {
        EffectiveSettings(settings: settings, capabilities: capabilities)
    }

    public var isBrightnessKnownUnavailable: Bool {
        ports.brightness.isKnownUnavailable
    }

    var brightnessWarnings: Set<BrightnessRecordWarning> {
        var warnings: Set<BrightnessRecordWarning> = []
        if brightnessSaveFailed {
            warnings.insert(.saveFailed)
        }
        if nextBrightnessDeletionAttempt != nil {
            warnings.insert(.deletionFailed)
        }
        return warnings
    }

    public var status: BlockingStatus {
        BlockingStatus(
            session: session,
            batteryCondition: effectiveSettings.batteryCondition,
            misalignments: misalignments,
            brightnessWarnings: brightnessWarnings,
        )
    }

    // MARK: 要求

    /// 開始を要求する。抑止中は、時間の指定があるときだけ解除の時刻を置き換える。
    @discardableResult
    public func requestStart(from origin: RequestOrigin, override: StartTimeOverride? = nil) -> StartResult {
        notifyingWarnings {
            let now = ports.time.now
            if let session {
                guard override != nil else { return .alreadyBlocking }
                if let limit = session.timeLimit, TimeLimitRule.isReached(limit, now: now) {
                    release(.timeLimit(limit.source))
                    return .released
                }
            }
            let newSession = BlockingSession(timeLimit: TimeLimitRule.timeLimit(
                override: override, settings: settings, now: now, calendar: ports.time.calendar,
            ))
            guard isBlocking else { return start(newSession, from: origin) }
            session = newSession
            onEvent?(.timeLimitReplaced(origin))
            return .timeLimitReplaced
        }
    }

    /// 解除を要求する。停止中なら、合わせられていない制御があるときだけ合わせ直す。
    @discardableResult
    public func requestStop(from origin: RequestOrigin) -> StopResult {
        notifyingWarnings {
            guard isBlocking else {
                if !misalignments.isEmpty {
                    reconcileListed()
                }
                return .alreadyStopped
            }
            release(.user(origin))
            return .released
        }
    }

    public func toggleByHotkey() {
        if isBlocking {
            requestStop(from: .hotkey)
        } else {
            requestStart(from: .hotkey)
        }
    }

    /// 設定を変える。抑止中は、仕組みを足すか外す変更を反映できたときだけ受け入れる。時間の条件はいまの抑止に効かない。
    @discardableResult
    public func changeSettings(_ newSettings: Settings) -> SettingsChangeResult {
        notifyingWarnings { applySettings(newSettings) }
    }

    // MARK: 時刻と電源

    public func timePassed() {
        notifyingWarnings {
            if let retry = nextBrightnessDeletionAttempt, ports.time.now >= retry {
                removeBrightnessRecord()
            }
            if releaseIfConditionMet() {
                return
            }
            keepBrightnessZeroWhileClosed()
            let isDue = lastAlignment.map { ports.time.now.timeIntervalSince($0) >= Self.reconcileInterval } ?? true
            if !misalignments.isEmpty, isDue {
                reconcileListed()
            }
        }
    }

    public func powerStateChanged() {
        notifyingWarnings { releaseIfConditionMet() }
    }

    /// ヘルパーの設置と修復の後に呼ぶ。
    public func reconcile() {
        notifyingWarnings { reconcileListed() }
    }
}
