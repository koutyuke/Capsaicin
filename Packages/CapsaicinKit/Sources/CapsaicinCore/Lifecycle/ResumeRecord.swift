import Foundation

/// 前回の正常な終了の理由。
public enum ExitReason: String, Hashable, Sendable, Codable {
    case userQuit
    case sessionEnd
}

/// 再開用の記録。通常の設定とは別に保存する（DEC-SET-002）。
public struct ResumeRecord: Hashable, Sendable {
    public var session: BlockingSession?
    /// 蓋を閉じて暗くする前の、内蔵ディスプレイの輝度。
    public var savedBrightness: Float?
    /// disablesleep を自分が立てたか（所有）。
    public var ownsSleepDisabled = false
    /// アプリが動いている間だけ立つ印。
    public var isRunning = false
    /// 正常終了の理由。実行中の印が下りていて nil なら、理由不明の終了。
    public var exitReason: ExitReason?
    public var misalignments: Misalignments = [:]
    /// 記録を最後に書いた壁時計の時刻。
    public var lastUpdated: Date
    /// 直近のクラッシュ後の起動の時刻。
    public var crashLaunches: [Date] = []

    public init(lastUpdated: Date) {
        self.lastUpdated = lastUpdated
    }
}

/// 保存の形式。未知のキーは無視し、欠けたキーは既定値で補う。
/// 値が不正な場合や最終更新の時刻がない場合は、読めない記録として throw する。
extension ResumeRecord: Codable {
    private enum CodingKeys: String, CodingKey {
        case session, ownsSleepDisabled, isRunning, exitReason, misalignments, lastUpdated, crashLaunches
        case savedBrightness
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys) throws -> T? {
            guard container.contains(key) else { return nil }
            return try container.decode(T.self, forKey: key)
        }
        try self.init(lastUpdated: container.decode(Date.self, forKey: .lastUpdated))
        session = try container.decodeIfPresent(BlockingSession.self, forKey: .session)
        savedBrightness = try container.decodeIfPresent(Float.self, forKey: .savedBrightness)
        ownsSleepDisabled = try value(.ownsSleepDisabled) ?? false
        isRunning = try value(.isRunning) ?? false
        exitReason = try container.decodeIfPresent(ExitReason.self, forKey: .exitReason)
        misalignments = try value(.misalignments) ?? [:]
        crashLaunches = try value(.crashLaunches) ?? []
    }
}
