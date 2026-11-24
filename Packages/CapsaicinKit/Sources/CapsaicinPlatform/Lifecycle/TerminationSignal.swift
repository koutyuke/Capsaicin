import Darwin
import Dispatch

@MainActor
public enum TerminationSignal {
    /// SIGTERM の既定動作を止める。呼び出し元がソースを有効化し、終了まで保持する。
    public static func makeSource(onTermination: @escaping @MainActor () -> Void) -> any DispatchSourceSignal {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak source] in
            // 後片付け中の SIGTERM は、監視を止めてもそのまま無視する。
            source?.cancel()
            MainActor.assumeIsolated { onTermination() }
        }
        return source
    }
}
