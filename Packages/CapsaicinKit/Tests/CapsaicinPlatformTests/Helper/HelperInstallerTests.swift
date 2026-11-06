@testable import CapsaicinPlatform
import Foundation
import Testing

@MainActor
struct HelperInstallerTests {
    @Test("SPEC-HLP-001 SPEC-HLP-004 SPEC-HLP-006 管理操作は10分期限で成功・取り消し・失敗を区別する")
    func outcomes() async {
        for output in ["success\n", "cancelled\n", "failed:1:permission denied\n", "unexpected\n"] {
            let installer = HelperInstaller(run: { executable, arguments, timeout in
                #expect(executable == "/usr/bin/osascript")
                #expect(arguments.count == 2)
                #expect(arguments.first == "-e")
                #expect(timeout == 600)
                return Data(output.utf8)
            })
            let results: [(HelperManagementOperation, HelperManagementResult)] = await [
                (.install, installer.install(bundledHelperPath: "/App/helper", uid: 501)),
                (.repair, installer.repair(bundledHelperPath: "/App/helper", uid: 501)),
                (.remove, installer.remove(restoreSleep: true)),
            ]
            for (operation, result) in results {
                switch result {
                case .success: #expect(output == "success\n")
                case .cancelled: #expect(output == "cancelled\n")
                case let .failure(actual, details, readback):
                    #expect(output != "success\n" && output != "cancelled\n")
                    #expect(actual == operation)
                    #expect(!details.isEmpty)
                    #expect(readback == (operation == .remove))
                }
            }
        }
    }

    @Test("SPEC-HLP-004 削除の失敗・期限切れは読み直しが必要なことを返す")
    func removalFailure() async {
        for error in [CommandRunnerError.timedOut, .alreadyRunning, .unsuccessfulExit(1)] {
            let installer = HelperInstaller(run: { _, _, _ in throw error })
            guard case let .failure(operation, details, readback) = await installer.remove(restoreSleep: false) else {
                Issue.record("失敗として返さなかった")
                continue
            }
            #expect(operation == .remove)
            #expect(details == String(describing: error))
            #expect(readback)
        }
    }

    @Test("SPEC-HLP-001 SPEC-HLP-004 不正な入力は認証前に拒否し、修復は設置と同じスクリプトにする")
    func validationAndRepair() async throws {
        let invalid = HelperInstaller(run: { _, _, _ in Issue.record("不正入力で認証した"); return Data() })
        guard case .failure(.install, _, false) = await invalid.install(bundledHelperPath: "relative", uid: 501) else {
            Issue.record("入力の失敗として返さなかった")
            return
        }
        let expected = try HelperScripts.appleScript(HelperScripts.install(
            paths: .current,
            bundledHelperPath: "/App/helper",
            uid: 501,
        ))
        let installer = HelperInstaller(run: { _, arguments, _ in
            #expect(arguments == ["-e", expected])
            return Data("success\n".utf8)
        })
        guard case .success = await installer.repair(bundledHelperPath: "/App/helper", uid: 501) else {
            Issue.record("修復に失敗した")
            return
        }
    }
}
