/// コントローラーが通知する状態の変化。通知の時点で、コントローラーの状態は更新済みである。
///
/// HUD を出すかは画面の側が、きっかけと理由から決める。
public enum BlockingEvent: Hashable, Sendable {
    case started(StartTrigger)
    case startRejected(StartTrigger, StartRejection)
    case released(ReleaseReason)
    /// 合わせられていない制御か、記録を保存できていないことが変わった。
    case warningsChanged
}

/// 開始の要求の結果。
public enum StartResult: Hashable, Sendable {
    case started
    /// すでに抑止中なので何も変えなかった。
    case alreadyBlocking
    case rejected(StartRejection)
}

/// 解除の要求の結果。
public enum StopResult: Hashable, Sendable {
    case released
    /// すでに停止中だった。合わせられていない制御があれば、合わせ直しを試みた。
    case alreadyStopped
}

/// 設定の変更の結果。
public enum SettingsChangeResult: Hashable, Sendable {
    /// 反映した。アプリは新しい設定を保存する。
    case applied
    /// 反映できなかったので変更前に戻した。アプリは保存せず、スイッチを戻してエラーのダイアログを出す。
    case reverted(failed: Set<Mechanism>)
}

/// メニューと CLI に見せる状態。
public struct BlockingStatus: Hashable, Sendable, Codable {
    public var session: BlockingSession?
    /// 抑止に使うバッテリー残量の条件。
    public var batteryCondition: BatteryCondition?
    public var misalignments: Misalignments
    /// 再開用の記録を保存できていない。
    public var isRecordUnsaved: Bool

    public init(
        session: BlockingSession?,
        batteryCondition: BatteryCondition?,
        misalignments: Misalignments,
        isRecordUnsaved: Bool,
    ) {
        self.session = session
        self.batteryCondition = batteryCondition
        self.misalignments = misalignments
        self.isRecordUnsaved = isRecordUnsaved
    }

    public var isBlocking: Bool {
        session != nil
    }

    /// メニューの警告の行を出すか。
    public var hasWarnings: Bool {
        !misalignments.isEmpty || isRecordUnsaved
    }
}
