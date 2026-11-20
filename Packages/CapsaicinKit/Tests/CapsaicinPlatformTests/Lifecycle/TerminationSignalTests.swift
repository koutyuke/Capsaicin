import CapsaicinPlatform
import Darwin
import Dispatch
import Testing

struct TerminationSignalTests {
    @Test("SPEC-LCY-002 SIGTERM を複数回送っても終了処理を一度だけ呼ぶ")
    func handlesSIGTERMOnce() async {
        // SIGTERM の設定がほかのテストに影響しないよう、子プロセスに分ける。
        await #expect(processExitsWith: .success) {
            await Self.sendSIGTERM()
        }
    }

    @MainActor
    private static func sendSIGTERM() async {
        var calls = 0
        let source = TerminationSignal.makeSource { calls += 1 }
        await withCheckedContinuation { continuation in
            // 監視の登録後に送って、登録前に取りこぼさないようにする。
            source.setRegistrationHandler {
                precondition(kill(getpid(), SIGTERM) == 0)
            }
            source.setCancelHandler { continuation.resume() }
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(5)) {
                fatalError("SIGTERM の監視が終了しなかった")
            }
            source.activate()
        }
        precondition(kill(getpid(), SIGTERM) == 0)
        precondition(calls == 1, "終了処理のクロージャーが一度だけ呼ばれる")
    }
}
