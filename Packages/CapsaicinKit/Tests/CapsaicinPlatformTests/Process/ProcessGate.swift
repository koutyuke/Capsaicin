@testable import CapsaicinPlatform
import Foundation
import Synchronization

/// テストが開くまで終わらない子プロセスを作る。
/// 短い sleep と短い期限の差に頼ると、混み合った CI では期限を確かめる前に子が終わり、結果が揺れる。
/// 子は印のファイルを見つけると、それを消して終わる。開いた後は同じ引数で起動し直さない。
final class ProcessGate: Sendable {
    let path = FileManager.default.temporaryDirectory.appending(path: "capsaicin-gate-\(UUID().uuidString)").path
    private let opened = Mutex(false)

    /// `/bin/sh` に渡す引数。CommandRunner は環境変数を空にするので、コマンドは絶対パスで書く。
    var arguments: [String] {
        ["-c", #"while [ ! -e "$0" ]; do /bin/sleep 0.01; done; /bin/rm -f "$0""#, path]
    }

    func open() {
        let isFirst = opened.withLock { isOpened in
            defer { isOpened = true }
            return !isOpened
        }
        if isFirst {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
    }

    /// テストが途中で失敗しても、子を残さない。
    deinit { open() }
}

extension CommandRunner {
    /// 見届けが終わって次の起動を受け付けるまで、起動を試し続ける。
    func runWhenIdle(executable: String? = nil, arguments: [String]? = nil) async throws -> Data {
        let deadline = ContinuousClock.now + .seconds(10)
        while true {
            do {
                return try run(executable: executable ?? self.executable, arguments: arguments ?? self.arguments,
                               timeout: 5)
            } catch CommandRunnerError.alreadyRunning where ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
    }
}
