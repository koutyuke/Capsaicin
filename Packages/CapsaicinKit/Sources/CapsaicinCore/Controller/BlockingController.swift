import Foundation

/// 抑止を制御する。OS への作用はすべてポート越しに行い、状態が変わったら `onEvent` で通知する。
///
/// アプリは起動したら `launch()` を呼ぶ。時刻の経過は、少なくとも 1 分ごとと解除の時刻に `timePassed()` で伝える。
@MainActor
public final class BlockingController {
    public struct Ports {
        public var assertions: any PowerAssertionControlling
        public var helper: any HelperSleepControlling
        public var led: any CapsLockLEDControlling
        public var brightness: any BuiltInDisplayBrightnessControlling
        public var power: any PowerStateProviding
        public var bootTime: any BootTimeProviding
        public var records: any ResumeRecordStoring
        public var time: any TimeProviding

        public init(
            assertions: any PowerAssertionControlling,
            helper: any HelperSleepControlling,
            led: any CapsLockLEDControlling,
            brightness: any BuiltInDisplayBrightnessControlling,
            power: any PowerStateProviding,
            bootTime: any BootTimeProviding,
            records: any ResumeRecordStoring,
            time: any TimeProviding,
        ) {
            self.assertions = assertions
            self.helper = helper
            self.led = led
            self.brightness = brightness
            self.power = power
            self.bootTime = bootTime
            self.records = records
            self.time = time
        }
    }

    /// 合わせ直しを試みる間隔。
    static let reconcileInterval: TimeInterval = 60

    public internal(set) var settings: Settings
    public let capabilities: MachineCapabilities
    /// 抑止中だけある。
    public internal(set) var session: BlockingSession?
    public internal(set) var isRecordUnsaved = false
    public var onEvent: ((BlockingEvent) -> Void)?

    let ports: Ports
    /// メモリー上の再開用の記録。保存できない間も、動いている間はこれを正とする。
    var record: ResumeRecord
    /// 仕組みごとの、適用していると見込める状態。キーがなければ分からない。
    var observed: [Mechanism: Bool]
    var lastAlignment: Date?
    var isLidClosed = false

    public init(settings: Settings, capabilities: MachineCapabilities, ports: Ports) {
        self.settings = settings
        self.capabilities = capabilities
        self.ports = ports
        record = ResumeRecord(lastUpdated: ports.time.now)
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

    public var misalignments: Misalignments {
        record.misalignments
    }

    public var status: BlockingStatus {
        BlockingStatus(
            session: session,
            batteryCondition: effectiveSettings.batteryCondition,
            misalignments: misalignments,
            isRecordUnsaved: isRecordUnsaved,
        )
    }

    // MARK: 要求

    /// 開始を要求する。抑止中なら何も変えない。
    @discardableResult
    public func requestStart(from origin: RequestOrigin, override: StartTimeOverride? = nil) -> StartResult {
        guard !isBlocking else { return .alreadyBlocking }
        let limit = TimeLimitRule.timeLimit(
            override: override, settings: settings, now: ports.time.now, calendar: ports.time.calendar,
        )
        return notifyingWarnings { start(BlockingSession(timeLimit: limit), trigger: .user(origin)) }
    }

    /// 解除を要求する。停止中なら、合わせられていない制御か保存できていない記録があるときだけ合わせ直す。
    @discardableResult
    public func requestStop(from origin: RequestOrigin) -> StopResult {
        notifyingWarnings {
            guard isBlocking else {
                if status.hasWarnings {
                    reconcileListed()
                }
                return .alreadyStopped
            }
            release(.user(origin))
            return .released
        }
    }

    /// ホットキー。停止中なら指定なしで開始し、抑止中なら解除する。
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

    /// 解除の条件を確かめ、閉じた間の輝度を保ち、合わせ直しの間隔が過ぎていれば合わせ直す。
    public func timePassed() {
        notifyingWarnings {
            if releaseIfConditionMet() {
                return
            }
            keepBrightnessZeroWhileClosed()
            let isDue = lastAlignment.map { ports.time.now.timeIntervalSince($0) >= Self.reconcileInterval } ?? true
            if status.hasWarnings, isDue {
                reconcileListed()
            }
        }
    }

    public func powerStateChanged() {
        notifyingWarnings { releaseIfConditionMet() }
    }

    /// 合わせ直す。ヘルパーの設置と修復の後に呼ぶ。
    public func reconcile() {
        notifyingWarnings { reconcileListed() }
    }
}
