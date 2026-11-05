/// 抑止の仕組み。電源管理アサーションは種類ごとに別の仕組みとして扱う。
///
/// 並びは操作の順序である。disablesleep を先に扱い、所有の保存をほかの仕組みの適用より前にする。
public enum Mechanism: String, Hashable, Sendable, Codable, CodingKeyRepresentable, CaseIterable {
    /// ヘルパーで立てる disablesleep。
    case systemSleepDisabled
    /// 蓋閉じスリープの制御（kPMSetClamshellSleepState）。
    case lidSleepControl
    /// 自動スリープを止めるアサーション（PreventUserIdleSystemSleep）。
    case idleSleepAssertion
    /// 画面の自動消灯を止めるアサーション（PreventUserIdleDisplaySleep）。
    case displaySleepAssertion
    /// Caps Lock の LED の点灯。開始の全部か無しかには含めない。
    case led
}

/// 電源管理アサーションの種類。
public enum AssertionKind: Hashable, Sendable {
    case preventUserIdleSystemSleep
    case preventUserIdleDisplaySleep
}

/// 合わせられていない制御の向き。
public enum MisalignmentDirection: String, Hashable, Sendable, Codable {
    /// 戻すべきなのに残っている。
    case leftApplied
    /// 止めるべきなのに適用できていない。
    case notApplied
}

/// 合わせられていない制御の一覧。仕組みごとに1項目で、向きを持つ。
public typealias Misalignments = [Mechanism: MisalignmentDirection]
