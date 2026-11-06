import Foundation

public enum HelperManagementOperation: Sendable {
    case install, repair, remove
}

public enum HelperManagementResult: Sendable {
    case success
    case cancelled
    /// details はログ用。アラートには operation に応じた説明だけを出す。
    case failure(operation: HelperManagementOperation, details: String, needsSleepDisabledReadback: Bool)
}

/// 管理操作後の所有・設定の更新と、削除失敗後の読み直しは呼び出し元が行う。
@MainActor
public final class HelperInstaller {
    private let paths: HelperPaths
    private let run: HelperCommand

    public convenience init() {
        let runner = CommandRunner(executable: "/usr/bin/osascript", arguments: [], outputLimit: 65536)
        self.init(run: { try runner.run(executable: $0, arguments: $1, timeout: $2) })
    }

    init(paths: HelperPaths = .current, run: @escaping HelperCommand) {
        self.paths = paths
        self.run = run
    }

    public func install(bundledHelperPath: String, uid: UInt32) async -> HelperManagementResult {
        await place(.install, bundledHelperPath: bundledHelperPath, uid: uid)
    }

    public func repair(bundledHelperPath: String, uid: UInt32) async -> HelperManagementResult {
        await place(.repair, bundledHelperPath: bundledHelperPath, uid: uid)
    }

    public func remove(restoreSleep: Bool) async -> HelperManagementResult {
        await execute(.remove, script: HelperScripts.remove(paths: paths, restoreSleep: restoreSleep))
    }

    private func place(_ operation: HelperManagementOperation, bundledHelperPath: String,
                       uid: UInt32) async -> HelperManagementResult
    {
        do {
            let script = try HelperScripts.install(paths: paths, bundledHelperPath: bundledHelperPath, uid: uid)
            return await execute(operation, script: script)
        } catch {
            return .failure(operation: operation, details: String(describing: error), needsSleepDisabledReadback: false)
        }
    }

    private func execute(_ operation: HelperManagementOperation, script: String) async -> HelperManagementResult {
        let run = run
        let appleScript = HelperScripts.appleScript(script)
        do {
            let data = try await Task.detached { try run("/usr/bin/osascript", ["-e", appleScript], 600) }.value
            guard let text = String(data: data, encoding: .utf8) else { throw HelperError.unexpectedInstallerOutput }
            let output = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if output == "success" {
                return .success
            }
            if output == "cancelled" {
                return .cancelled
            }
            if output.hasPrefix("failed:") {
                return .failure(operation: operation, details: output, needsSleepDisabledReadback: operation == .remove)
            }
            throw HelperError.unexpectedInstallerOutput
        } catch {
            return .failure(operation: operation, details: String(describing: error),
                            needsSleepDisabledReadback: operation == .remove)
        }
    }
}
