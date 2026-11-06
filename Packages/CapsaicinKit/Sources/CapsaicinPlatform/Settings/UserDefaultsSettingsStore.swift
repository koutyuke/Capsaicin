import CapsaicinCore
import Foundation
import os

/// Core の設定全体を一つの JSON Data としてアプリの UserDefaults に保存する。
@MainActor
public final class UserDefaultsSettingsStore {
    private let defaults: UserDefaults
    private let key = "capsaicin.settings"
    private let logger = Logger(subsystem: "io.github.koutyuke.capsaicin", category: "SettingsStore")

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> Settings {
        guard let object = defaults.object(forKey: key) else { return Settings() }
        guard let data = object as? Data else {
            logger.error("保存された設定が Data ではありません。")
            return Settings()
        }
        do {
            return try JSONDecoder().decode(Settings.self, from: data)
        } catch {
            logger.error("保存された設定の形式が不正です。")
            return Settings()
        }
    }

    /// true は値を UserDefaults に渡したことを示す。ディスクへの同期完了ではない。
    @discardableResult
    public func save(_ settings: Settings) -> Bool {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(data, forKey: key)
            return true
        } catch {
            logger.error("設定をエンコードできません。")
            return false
        }
    }
}
