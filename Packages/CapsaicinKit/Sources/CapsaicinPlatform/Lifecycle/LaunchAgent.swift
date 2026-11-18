import Darwin
import Foundation
import OSLog
import ServiceManagement

public enum LaunchAgentStatus: Equatable, Sendable {
    case ready
    case registrationFailed
    case launchFailed
    case disabled
    case unavailable
}

/// 呼び出し元の終了やプロセスの管理は行わない。
@MainActor
public final class LaunchAgent {
    public let label: String
    private let domain: String
    private let runLaunchctl: ([String], TimeInterval) async throws -> String
    private let executableURL: URL?
    private let executablePath: (pid_t) -> String?
    private let now: () -> ContinuousClock.Instant
    private let serviceStatus: () -> SMAppService.Status
    private let registerService: () throws -> Void
    private let unregisterService: () async throws -> Void
    private let loginStatus: () -> SMAppService.Status
    private let registerLogin: () throws -> Void
    private let unregisterLogin: () throws -> Void
    private let version: String
    private let registeredVersion: () -> String?
    private let saveVersion: (String) -> Void
    private let wait: (Duration) async throws -> Void

    public convenience init(bundle: Bundle = .main, defaults: UserDefaults = .standard, isDebug: Bool) {
        let label = "io.github.koutyuke.capsaicin" + (isDebug ? ".debug" : "")
        let service = SMAppService.agent(plistName: label + ".plist")
        let login = SMAppService.mainApp
        self.init(label: label, uid: getuid(), status: { service.status },
                  register: { try service.register() }, unregister: { try await service.unregister() },
                  loginStatus: { login.status }, registerLogin: { try login.register() },
                  unregisterLogin: { try login.unregister() },
                  version: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                  registeredVersion: { defaults.string(forKey: "agentRegisteredBundleVersion") },
                  saveVersion: { defaults.set($0, forKey: "agentRegisteredBundleVersion") },
                  executableURL: bundle.executableURL, executablePath: Self.processExecutablePath,
                  runLaunchctl: { arguments, timeout in
                      let runner = CommandRunner(executable: "/bin/launchctl", arguments: arguments, outputLimit: 65536)
                      let data = try await Task.detached { try runner.run(timeout: timeout) }.value
                      return String(data: data, encoding: .utf8) ?? ""
                  })
    }

    init(label: String, uid: uid_t, status: @escaping () -> SMAppService.Status,
         register: @escaping () throws -> Void, unregister: @escaping () async throws -> Void,
         loginStatus: @escaping () -> SMAppService.Status,
         registerLogin: @escaping () throws -> Void, unregisterLogin: @escaping () throws -> Void,
         version: String, registeredVersion: @escaping () -> String?, saveVersion: @escaping (String) -> Void,
         executableURL: URL?, executablePath: @escaping (pid_t) -> String?,
         runLaunchctl: @escaping ([String], TimeInterval) async throws -> String,
         now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now },
         wait: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) })
    {
        self.label = label
        domain = "gui/\(uid)"
        serviceStatus = status
        registerService = register
        unregisterService = unregister
        self.loginStatus = loginStatus
        self.registerLogin = registerLogin
        self.unregisterLogin = unregisterLogin
        self.version = version
        self.registeredVersion = registeredVersion
        self.saveVersion = saveVersion
        self.runLaunchctl = runLaunchctl
        self.executableURL = executableURL?.resolvingSymlinksInPath()
        self.executablePath = executablePath
        self.now = now
        self.wait = wait
    }

    /// mainApp の登録解除は実行中のアプリや agent を止めず、次のログインだけに効く。
    public func updateLaunchAtLogin(_ enabled: Bool) throws {
        switch loginStatus() {
        case .enabled, .requiresApproval:
            if !enabled {
                try unregisterLogin()
            }
        case .notRegistered, .notFound:
            if enabled {
                try registerLogin()
            }
        @unknown default:
            if enabled {
                try registerLogin()
            }
        }
    }

    /// agent 自身が unregister すると自分も終了するため、直接起動した個体だけが呼ぶ。
    public func registerAndStart() async -> LaunchAgentStatus {
        let initial = serviceStatus()
        do {
            if initial == .enabled || initial == .requiresApproval, registeredVersion() != version {
                try await AppServiceRegistration.replace(status: serviceStatus, register: registerService,
                                                         unregister: unregisterService, wait: wait)
                saveVersion(version)
            } else if initial != .requiresApproval {
                do {
                    // 手動でジョブを外した Debug 起動でも、現在のバンドルから登録を要求する。
                    try registerService()
                } catch {
                    let error = error as NSError
                    let alreadyRegistered = error.domain == SMAppServiceErrorDomain
                        && error.code == kSMErrorAlreadyRegistered && serviceStatus() == .enabled
                    let awaitingApproval = AppServiceRegistration.isPermissionError(error)
                        && serviceStatus() == .requiresApproval
                    guard alreadyRegistered || awaitingApproval else { throw error }
                }
                saveVersion(version)
            }
        } catch {
            Logger(subsystem: label, category: "LaunchAgent")
                .error("Agent registration failed: \(String(describing: error), privacy: .private)")
            return serviceStatus() == .requiresApproval ? .disabled : .registrationFailed
        }
        let status = restartStatus()
        guard status == .ready else { return status }
        do {
            _ = try await runLaunchctl(["kickstart", "\(domain)/\(label)"], 5)
        } catch {
            Logger(subsystem: label, category: "LaunchAgent")
                .error("Agent kickstart failed: \(String(describing: error), privacy: .private)")
            return .launchFailed
        }
        return await confirmLaunch()
    }

    private func confirmLaunch() async -> LaunchAgentStatus {
        let logger = Logger(subsystem: label, category: "LaunchAgent")
        guard let executableURL else {
            logger.error("Agent launch failed: bundle executable is unavailable")
            return .launchFailed
        }
        let deadline = now().advanced(by: .seconds(5))
        var reason = "Agent job has no PID"
        var path: String?
        while now() < deadline {
            let output: String
            do {
                // kickstart の PID は exec 前のものになりうるので、現在のジョブを毎回読み直す。
                output = try await runLaunchctl(["print", "\(domain)/\(label)"], 2)
            } catch {
                logger.error("Agent job is unavailable: \(String(describing: error), privacy: .private)")
                return .launchFailed
            }
            path = nil
            if let pid = Self.jobPID(output) {
                if pid == getpid() {
                    reason = "Agent job PID is the current process"
                } else {
                    path = executablePath(pid)
                    reason = path == nil ? "Agent executable path is unavailable" : "Agent executable differs"
                    // 期限の後でも、一致したら agent は動いているので、2つ目のアプリとして残らない。
                    if let path, URL(fileURLWithPath: path).resolvingSymlinksInPath() == executableURL {
                        return .ready
                    }
                }
            } else {
                reason = "Agent job has no PID"
            }
            do {
                let remaining = now().duration(to: deadline)
                guard remaining > .zero else { break }
                try await wait(min(.milliseconds(100), remaining))
            } catch {
                logger.error("Agent launch confirmation cancelled: \(String(describing: error), privacy: .private)")
                return .launchFailed
            }
        }
        logger
            .error(
                "Agent launch timed out: \(reason, privacy: .public); executable: \(path ?? "", privacy: .private); expected: \(executableURL.path, privacy: .private)",
            )
        return .launchFailed
    }

    /// 許可状態の照会であり、プロセスの稼働やクラッシュ復旧の成功は保証しない。
    public func restartStatus() -> LaunchAgentStatus {
        switch serviceStatus() {
        case .enabled: .ready
        case .requiresApproval: .disabled
        case .notRegistered, .notFound: .registrationFailed
        @unknown default: .unavailable
        }
    }

    public func wasLaunchedByLaunchd(environment: [String: String]) -> Bool {
        environment["XPC_SERVICE_NAME"] == label
    }
}
