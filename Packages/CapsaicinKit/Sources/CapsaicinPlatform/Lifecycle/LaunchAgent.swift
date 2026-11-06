import Darwin
import Foundation
import ServiceManagement

public enum LaunchAgentStatus: Equatable, Sendable {
    case ready
    case registrationFailed
    case launchFailed
    case disabled
    case unavailable
}

/// 登録と起動の要求だけを扱い、呼び出し元の終了やプロセスの管理は行わない。
@MainActor
public final class LaunchAgent {
    public let label: String
    public let plistURL: URL
    private let executableURL: URL
    private let directory: URL
    private let domain: String
    private let runLaunchctl: ([String]) async throws -> Void
    private let serviceStatus: (URL) -> SMAppService.Status

    public convenience init(executableURL: URL, isDebug: Bool) {
        self.init(
            executableURL: executableURL, isDebug: isDebug,
            directory: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"),
            uid: getuid(),
            runLaunchctl: { arguments in
                let runner = CommandRunner(executable: "/bin/launchctl", arguments: arguments)
                _ = try await Task.detached { try runner.run(timeout: 5) }.value
            },
            serviceStatus: { SMAppService.statusForLegacyPlist(at: $0) },
        )
    }

    /// テストでは保存先、コマンド実行、システム設定の照会を差し替える。
    init(
        executableURL: URL, isDebug: Bool, directory: URL, uid: uid_t,
        runLaunchctl: @escaping ([String]) async throws -> Void,
        serviceStatus: @escaping (URL) -> SMAppService.Status,
    ) {
        label = "io.github.koutyuke.capsaicin" + (isDebug ? ".debug" : "")
        plistURL = directory.appendingPathComponent("\(label).plist")
        self.executableURL = executableURL
        self.directory = directory
        domain = "gui/\(uid)"
        self.runLaunchctl = runLaunchctl
        self.serviceStatus = serviceStatus
    }

    public func propertyList(launchAtLogin: Bool) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: [
            "Label": label,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": launchAtLogin,
            "KeepAlive": ["Crashed": true],
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ], format: .xml, options: 0)
    }

    /// ログイン設定の変更は次回ログインから効かせ、実行中のジョブは外さない。
    public func updateLaunchAtLogin(_ enabled: Bool) throws {
        let data = try propertyList(launchAtLogin: enabled)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
    }

    public func registerAndStart(launchAtLogin: Bool) async -> LaunchAgentStatus {
        do {
            try updateLaunchAtLogin(launchAtLogin)
        } catch {
            return .registrationFailed
        }
        // 利用者がアプリを終了した後もジョブは読み込まれたままなので、bootstrap は失敗しうる。
        // 失敗を確定させるのは、続く kickstart も失敗したときだけにする。
        let bootstrapped = await (try? runLaunchctl(["bootstrap", domain, plistURL.path])) != nil
        do {
            try await runLaunchctl(["kickstart", "\(domain)/\(label)"])
        } catch {
            return bootstrapped ? .launchFailed : .registrationFailed
        }
        return restartStatus()
    }

    /// 許可状態の照会であり、プロセスの稼働やクラッシュ復旧の成功は保証しない。
    public func restartStatus() -> LaunchAgentStatus {
        switch serviceStatus(plistURL) {
        case .enabled: .ready
        case .requiresApproval: .disabled
        default: .unavailable
        }
    }

    public func wasLaunchedByLaunchd(environment: [String: String]) -> Bool {
        environment["XPC_SERVICE_NAME"] == label
    }
}
