import ServiceManagement

@MainActor
public enum LoginItem {
    public static func update(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        try update(enabled, status: service.status,
                   register: { try service.register() }, unregister: { try service.unregister() })
    }

    /// mainApp の登録解除は実行中のアプリを止めず、次のログインだけに効く。
    static func update(_ enabled: Bool, status: SMAppService.Status,
                       register: () throws -> Void, unregister: () throws -> Void) throws
    {
        switch status {
        case .enabled, .requiresApproval:
            if !enabled {
                try unregister()
            }
        case .notRegistered, .notFound:
            if enabled {
                try register()
            }
        @unknown default:
            if enabled {
                try register()
            }
        }
    }
}
