import Darwin
import Foundation
import OSLog
import Security
import ServiceManagement

public enum HelperInstallationState: Sendable {
    case notInstalled, requiresApproval, installed, unavailable
}

public enum HelperManagementOperation: Sendable {
    case install, remove
}

public enum HelperManagementResult: Sendable {
    case success
    case cancelled
    /// details はログ用。アラートには operation に応じた説明だけを出す。
    case failure(operation: HelperManagementOperation, details: String, needsSleepDisabledReadback: Bool)
}

enum HelperRegistrationError: Error {
    case unsignedBuild, translocated
}

enum HelperIdentity {
    static var appIdentifier: String {
        #if DEBUG
            "io.github.koutyuke.capsaicin.debug"
        #else
            "io.github.koutyuke.capsaicin"
        #endif
    }

    static var serviceName: String {
        appIdentifier + ".helper"
    }

    static let signingIdentifier = "io.github.koutyuke.capsaicin.helper"

    /// 自分の署名は動いている間に変わらないので、一度だけ読む。
    static let cachedTeamIdentifier = teamIdentifier()

    static func teamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &information) == errSecSuccess,
            let values = information as? [String: Any],
            let team = values[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty
        else { return nil }
        return team
    }
}

@MainActor
public final class HelperRegistration {
    private let serviceStatus: () -> SMAppService.Status
    private let registerService: () throws -> Void
    private let unregisterService: () async throws -> Void
    private let openSettings: () -> Void
    private let teamIdentifier: () -> String?
    private let bundleURL: URL
    private let version: String
    private let registeredVersion: () -> String?
    private let saveVersion: (String?) -> Void
    private let wait: (Duration) async throws -> Void

    public convenience init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        let service = SMAppService.daemon(plistName: HelperIdentity.serviceName + ".plist")
        self.init(status: { service.status }, register: { try service.register() },
                  unregister: { try await service.unregister() },
                  openSettings: { SMAppService.openSystemSettingsLoginItems() },
                  teamIdentifier: { HelperIdentity.cachedTeamIdentifier }, bundleURL: bundle.bundleURL,
                  version: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
                  registeredVersion: { defaults.string(forKey: "helperRegisteredBundleVersion") },
                  saveVersion: { defaults.set($0, forKey: "helperRegisteredBundleVersion") })
    }

    init(status: @escaping () -> SMAppService.Status,
         register: @escaping () throws -> Void,
         unregister: @escaping () async throws -> Void,
         openSettings: @escaping () -> Void = {},
         teamIdentifier: @escaping () -> String?, bundleURL: URL, version: String,
         registeredVersion: @escaping () -> String?, saveVersion: @escaping (String?) -> Void,
         wait: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) })
    {
        serviceStatus = status
        registerService = register
        unregisterService = unregister
        self.openSettings = openSettings
        self.teamIdentifier = teamIdentifier
        self.bundleURL = bundleURL
        self.version = version
        self.registeredVersion = registeredVersion
        self.saveVersion = saveVersion
        self.wait = wait
    }

    public var state: HelperInstallationState {
        guard teamIdentifier() != nil else { return .unavailable }
        switch serviceStatus() {
        case .enabled: return .installed
        case .requiresApproval: return .requiresApproval
        case .notRegistered, .notFound: return .notInstalled
        @unknown default: return .notInstalled
        }
    }

    public var isTranslocated: Bool {
        bundleURL.path.contains("/AppTranslocation/")
    }

    public func openSystemSettings() {
        openSettings()
    }

    public func register() throws {
        guard state != .unavailable else { throw HelperRegistrationError.unsignedBuild }
        guard !isTranslocated else { throw HelperRegistrationError.translocated }
        if state == .requiresApproval {
            openSettings()
            return
        }
        do {
            try registerService()
        } catch {
            // 初めての登録は、承認待ちの状態にしたうえで EPERM を返す。
            guard state == .requiresApproval else { throw error }
        }
        saveVersion(version)
        if state == .requiresApproval {
            openSettings()
        }
    }

    /// disablesleep の所有を解放してから、呼び出し元が登録を外す。
    public func unregister() async throws {
        try await unregisterService()
        saveVersion(nil)
    }

    @discardableResult
    public func reregisterIfNeeded() async -> HelperInstallationState {
        let initial = state
        guard initial == .installed || initial == .requiresApproval,
              registeredVersion() != version else { return initial }
        do {
            guard !isTranslocated else { throw HelperRegistrationError.translocated }
            try await AppServiceRegistration.replace(status: serviceStatus, register: registerService,
                                                     unregister: unregisterService, wait: wait)
            saveVersion(version)
        } catch {
            Logger(subsystem: HelperIdentity.appIdentifier, category: "Helper")
                .error("Helper re-registration failed: \(String(describing: error), privacy: .private)")
        }
        return state
    }
}

/// agent と daemon は同じ順序と待機で登録し直す。版の記録は呼び出し元ごとに持つ。
@MainActor
enum AppServiceRegistration {
    static func replace(status: () -> SMAppService.Status, register: () throws -> Void,
                        unregister: () async throws -> Void, wait: (Duration) async throws -> Void) async throws
    {
        let awaitingApproval = status() == .requiresApproval
        // 同期版は対象の終了を待たないので、完了ハンドラー版を await してから登録する。
        try await unregister()
        for retry in 0 ... 3 {
            do {
                try register()
                return
            } catch {
                guard isPermissionError(error as NSError) else { throw error }
                // 許可待ちの登録は済んでいるので、同じ EPERM を繰り返さない。
                if awaitingApproval, status() == .requiresApproval {
                    return
                }
                guard retry < 3 else { throw error }
                try await wait(.seconds(3))
            }
        }
    }

    static func isPermissionError(_ error: NSError) -> Bool {
        if error.domain == NSPOSIXErrorDomain || error.domain == SMAppServiceErrorDomain, error.code == Int(EPERM) {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlying.domain == NSPOSIXErrorDomain && underlying.code == Int(EPERM)
        }
        return false
    }
}
