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

/// 登録と起動の要求だけを扱い、呼び出し元の終了やプロセスの管理は行わない。
@MainActor
public final class LaunchAgent {
    public let label: String
    private let domain: String
    private let runLaunchctl: ([String]) async throws -> Void
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
                  runLaunchctl: { arguments in
                      let runner = CommandRunner(executable: "/bin/launchctl", arguments: arguments)
                      _ = try await Task.detached { try runner.run(timeout: 5) }.value
                  })
    }

    /// テストでは SMAppService、版の記録、コマンド実行、再試行の待機を差し替える。
    init(label: String, uid: uid_t, status: @escaping () -> SMAppService.Status,
         register: @escaping () throws -> Void, unregister: @escaping () async throws -> Void,
         loginStatus: @escaping () -> SMAppService.Status,
         registerLogin: @escaping () throws -> Void, unregisterLogin: @escaping () throws -> Void,
         version: String, registeredVersion: @escaping () -> String?, saveVersion: @escaping (String) -> Void,
         runLaunchctl: @escaping ([String]) async throws -> Void,
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
            // 引き渡しの成否は許可状態ではなく、起動要求の成功で決める。
            try await runLaunchctl(["kickstart", "\(domain)/\(label)"])
            return .ready
        } catch {
            return .launchFailed
        }
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
