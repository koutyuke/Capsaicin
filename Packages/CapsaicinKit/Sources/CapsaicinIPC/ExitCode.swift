/// CLI の終了コード（sysexits.h）。
public enum ExitCode: Int32, Hashable, Sendable {
    case success = 0
    /// `status` で停止中。
    case stopped = 1
    /// 使い方の誤り（EX_USAGE）。
    case usage = 64
    /// 要求を完了できなかった（EX_UNAVAILABLE）。アプリに接続できなかったときも使う。
    case unavailable = 69
}

public extension IPCResponse {
    /// 応答から CLI の終了コードを決める。
    var exitCode: ExitCode {
        switch outcome {
        case .started, .timeLimitReplaced, .alreadyBlocking:
            .success
        case .released, .alreadyStopped:
            // 解除の要求は、合わせられていない制御が残るか記録を保存できなければ完了していない。
            status.hasWarnings ? .unavailable : .success
        case .status:
            // 合わせられていない制御の有無によらず、状態だけで決める。
            status.isBlocking ? .success : .stopped
        case .startRejected, .cliRequestsDisabled, .unsupportedVersion:
            .unavailable
        }
    }
}
