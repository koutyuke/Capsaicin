public enum AutomaticUpdateMode: String, CaseIterable, Sendable {
    case off
    case checkOnly
    case downloadAndInstall

    public init(automaticallyChecksForUpdates: Bool, automaticallyDownloadsUpdates: Bool) {
        self = if !automaticallyChecksForUpdates {
            .off
        } else if automaticallyDownloadsUpdates {
            .downloadAndInstall
        } else {
            .checkOnly
        }
    }

    public var automaticallyChecksForUpdates: Bool {
        self != .off
    }

    public var automaticallyDownloadsUpdates: Bool {
        self == .downloadAndInstall
    }
}

public enum UpdatePolicy {
    public static func canInstallAutomatically(isBlocking: Bool, settingsWindowIsOpen: Bool) -> Bool {
        !isBlocking && !settingsWindowIsOpen
    }

    public static func isEnabled(feedURL: String, publicKey: String) -> Bool {
        !feedURL.isEmpty && !publicKey.isEmpty
    }
}
