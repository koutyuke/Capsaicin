import CapsaicinCore

/// CLI とアプリの間の要求と応答の形式のバージョン。形式を変えたら上げる。
public enum IPCProtocol {
    public static let version = 1
}

/// CLI の要求。
public enum IPCCommand: Hashable, Sendable, Codable {
    /// `capsaicin on`。時間の指定がなければ、設定のタイマーと指定時刻を使う。
    case start(StartTimeOverride?)
    /// `capsaicin off`。
    case stop
    /// `capsaicin status`。
    case status
}

public struct IPCRequest: Hashable, Sendable, Codable {
    public var version: Int
    public var command: IPCCommand

    public init(command: IPCCommand) {
        version = IPCProtocol.version
        self.command = command
    }
}

/// 要求に対する結果。
public enum IPCOutcome: Hashable, Sendable, Codable {
    case started
    /// すでに抑止中なので、指定した条件は適用していない。
    case alreadyBlocking
    case startRejected(StartRejection)
    case released
    case alreadyStopped
    case status
    /// 「CLI からの操作を受け付ける」がオフなので拒んだ。
    case cliRequestsDisabled
    /// 要求の形式のバージョンが違う。
    case unsupportedVersion
}

public struct IPCResponse: Hashable, Sendable, Codable {
    public var version: Int
    public var outcome: IPCOutcome
    /// 要求を処理した後の状態。
    public var status: BlockingStatus

    public init(outcome: IPCOutcome, status: BlockingStatus) {
        version = IPCProtocol.version
        self.outcome = outcome
        self.status = status
    }
}
