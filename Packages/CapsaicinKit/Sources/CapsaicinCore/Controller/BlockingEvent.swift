/// 通知の時点で、コントローラーの状態は更新済みである。
/// HUD を出すかは画面の側が、きっかけと理由から決める。
public enum BlockingEvent: Hashable, Sendable {
    case started(RequestOrigin)
    case timeLimitReplaced(RequestOrigin)
    case startRejected(RequestOrigin, StartRejection)
    case released(ReleaseReason)
    case warningsChanged
}

public enum StartResult: Hashable, Sendable {
    case started
    case timeLimitReplaced
    /// 置き換えより先に、時刻による自動の解除を行った。
    case released
    case alreadyBlocking
    case rejected(StartRejection)
}

public enum StopResult: Hashable, Sendable {
    case released
    /// 合わせられていない制御があれば、合わせ直しを試みた。
    case alreadyStopped
}

public enum SettingsChangeResult: Hashable, Sendable {
    /// 反映した。アプリは新しい設定を保存する。
    case applied
    /// 反映できなかったので変更前に戻した。アプリは保存せず、スイッチを戻してエラーのダイアログを出す。
    case reverted(failed: Set<Mechanism>)
}

public enum BrightnessRecordWarning: String, CaseIterable, Hashable, Sendable, Codable {
    case saveFailed
    case deletionFailed
}

public struct BlockingStatus: Hashable, Sendable, Codable {
    public var session: BlockingSession?
    public var batteryCondition: BatteryCondition?
    public var misalignments: Misalignments
    public var brightnessWarnings: Set<BrightnessRecordWarning>

    public init(
        session: BlockingSession?,
        batteryCondition: BatteryCondition?,
        misalignments: Misalignments,
        brightnessWarnings: Set<BrightnessRecordWarning> = [],
    ) {
        self.session = session
        self.batteryCondition = batteryCondition
        self.misalignments = misalignments
        self.brightnessWarnings = brightnessWarnings
    }

    public var isBlocking: Bool {
        session != nil
    }

    public var hasWarnings: Bool {
        !misalignments.isEmpty || !brightnessWarnings.isEmpty
    }
}
