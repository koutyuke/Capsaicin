import AppKit

/// 終了試行の判定。保存する終了理由とは別で、判定不能も表す。
public enum TerminationReason: Hashable, Sendable {
    case userQuit
    case sessionEnd
    case unknown
}

/// その終了試行の材料だけを使う。イベントの取得、通知の監視、前の試行の記憶は行わない。
public enum TerminationReasonDetector {
    /// 呼び出し側は非同期処理に入る前に現在の Apple Event を採取する。
    /// 明示的な利用者終了がなければ、quit Event の文書化されたセッション終了理由だけを採用する。
    public static func classify(explicitUserQuit: Bool, appleEvent: NSAppleEventDescriptor?) -> TerminationReason {
        if explicitUserQuit {
            return .userQuit
        }
        guard let appleEvent,
              appleEvent.descriptorType == DescType(typeAppleEvent),
              appleEvent.eventClass == AEEventClass(kCoreEventClass),
              appleEvent.eventID == AEEventID(kAEQuitApplication),
              let reason = appleEvent.paramDescriptor(forKeyword: AEKeyword(kAEQuitReason)),
              reason.descriptorType == DescType(typeType),
              reason.data.count == MemoryLayout<OSType>.size
        else { return .unknown }

        // typeCodeValue は型を強制変換するため、上で元の型と長さを確認する。
        switch reason.typeCodeValue {
        case OSType(kAEShutDown), OSType(kAERestart), OSType(kAEReallyLogOut):
            return .sessionEnd
        default:
            return .unknown
        }
    }
}
