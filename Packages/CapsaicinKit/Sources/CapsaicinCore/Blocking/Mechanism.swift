/// 並びは操作の順序である。disablesleep を先に扱い、所有の保存をほかの仕組みの適用より前にする。
public enum Mechanism: String, Hashable, Sendable, Codable, CodingKeyRepresentable, CaseIterable {
    /// ヘルパーで立てる disablesleep。
    case systemSleepDisabled
    case idleSleepAssertion
    case displaySleepAssertion
    /// Caps Lock の LED の点灯。開始の全部か無しかには含めない。
    case led
}

public enum AssertionKind: Hashable, Sendable {
    case preventUserIdleSystemSleep
    case preventUserIdleDisplaySleep
}

public enum MisalignmentDirection: String, Hashable, Sendable, Codable {
    /// 戻すべきなのに残っている。
    case leftApplied
    /// 止めるべきなのに適用できていない。
    case notApplied
}

public typealias Misalignments = [Mechanism: MisalignmentDirection]
