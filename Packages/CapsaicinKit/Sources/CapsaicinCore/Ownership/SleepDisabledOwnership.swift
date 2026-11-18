/// disablesleep を立てる必要が生じたときの扱い。
public enum RaiseSleepDisabledAction: Hashable, Sendable {
    /// 所有の「立てた」を保存できてから、ヘルパーの `on` を実行する。
    case claimThenTurnOn
    /// 前に自分が立てたまま残ったものとみなし、`on` を実行せずに引き継ぐ。
    case adoptOwn
    /// 外部のものとみなし、`on` を実行しない。所有は「立てていない」にする。
    case leaveExternal
    /// `SleepDisabled` を読めなかった。`on` の失敗と同じに扱う。
    case failUnreadable
}

/// disablesleep を下ろす必要が生じたときの扱い。所有が「立てた」のときだけ使う。
public enum LowerSleepDisabledAction: Hashable, Sendable {
    /// すでに 0 なので、`off` を実行せずに所有を「立てていない」にする。
    case releaseOwnership
    /// ヘルパーの `off` を実行し、成功したら所有を「立てていない」にする。
    case turnOff
    /// `SleepDisabled` を読めなかった。`off` の失敗と同じに扱い、「立てた」を保つ。
    case failUnreadable
}

public enum SleepDisabledOwnership {
    /// - Parameter sleepDisabled: `SleepDisabled` の値。読めなければ nil。
    public static func raiseAction(sleepDisabled: Bool?, owned: Bool) -> RaiseSleepDisabledAction {
        switch sleepDisabled {
        case nil: .failUnreadable
        case false: .claimThenTurnOn
        case true: owned ? .adoptOwn : .leaveExternal
        }
    }

    /// - Parameter sleepDisabled: `SleepDisabled` の値。読めなければ nil。
    public static func lowerAction(sleepDisabled: Bool?) -> LowerSleepDisabledAction {
        switch sleepDisabled {
        case nil: .failUnreadable
        case false: .releaseOwnership
        case true: .turnOff
        }
    }
}
