import CapsaicinCore

/// CLI とアプリの間の要求と応答の形式のバージョン。形式を変えたら上げる。
public enum IPCProtocol {
    public static let version = 3
}

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

public enum IPCOutcome: Hashable, Sendable, Codable {
    case started
    case timeLimitReplaced
    /// すでに抑止中で、時間の指定がないので何も変えなかった。
    case alreadyBlocking
    case startRejected(StartRejection)
    case released
    case alreadyStopped
    case status
    /// 「CLI からの操作を受け付ける」がオフなので拒んだ。
    case cliRequestsDisabled
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
