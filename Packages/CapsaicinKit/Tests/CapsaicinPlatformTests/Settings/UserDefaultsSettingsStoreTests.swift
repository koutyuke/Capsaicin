import CapsaicinCore
@testable import CapsaicinPlatform
import Foundation
import Testing

@MainActor
struct UserDefaultsSettingsStoreTests {
    @Test("SPEC-SET-002 未保存なら Core の既定値を返し、書き込まない")
    func absent() throws {
        try withDefaults { defaults, suite in
            #expect(UserDefaultsSettingsStore(defaults: defaults).load() == Settings())
            #expect(defaults.persistentDomain(forName: suite) == nil)
        }
    }

    @Test("SPEC-SET-002 全設定を一つの Data として往復し、無関係な値を保つ")
    func roundTrip() throws {
        try withDefaults { defaults, suite in
            var settings = Settings()
            settings.launchesAtLogin = false
            settings.resumePolicy = .afterAppOrMacRestart
            settings.showsHUD = false
            settings.blocksDisplaySleep = false
            settings.blocksManualSleep = true
            settings.lidCloseDisplay = .keepOn
            settings.timerEnabled = true
            settings.timerDuration = try #require(TimerDuration(minutes: 90))
            settings.specifiedTimeEnabled = true
            settings.specifiedTime = try #require(TimeOfDay(hour: 23, minute: 5))
            settings.batteryConditionEnabled = false
            settings.batteryThreshold = try #require(BatteryThreshold(percent: 35))
            settings.ignoresBatteryOnACPower = false
            settings.notifiesWithLED = false
            settings.acceptsCLIRequests = false
            defaults.set("untouched", forKey: "unrelated")
            #expect(UserDefaultsSettingsStore(defaults: defaults).save(settings))
            #expect(UserDefaultsSettingsStore(defaults: defaults).load() == settings)
            let domain = try #require(defaults.persistentDomain(forName: suite))
            #expect(domain.count == 2)
            let encoded = try #require(domain.values.first { $0 is Data } as? Data)
            #expect(try JSONDecoder().decode(Settings.self, from: encoded) == settings)
            #expect(defaults.string(forKey: "unrelated") == "untouched")
        }
    }

    @Test("SPEC-SET-002 個別の不正値だけを既定値にし、正常な設定を保つ")
    func partialInvalidData() throws {
        try withDefaults { defaults, suite in
            let store = UserDefaultsSettingsStore(defaults: defaults)
            #expect(store.save(Settings()))
            let key = try #require(defaults.persistentDomain(forName: suite)?.keys.first)
            let data = Data(#"{"timerDuration":0,"showsHUD":"bad","lidCloseDisplay":"keepOn","future":7}"#.utf8)
            defaults.set(data, forKey: key)
            var expected = Settings()
            expected.lidCloseDisplay = .keepOn
            #expect(store.load() == expected)
            #expect(defaults.data(forKey: key) == data)
        }
    }

    @Test("SPEC-SET-002 破損した全体や Data でない値を読み直しても上書きしない", arguments: [
        "nonData", "not json", "[]", "null",
    ])
    func invalidRoot(value: String) throws {
        try withDefaults { defaults, suite in
            let store = UserDefaultsSettingsStore(defaults: defaults)
            #expect(store.save(Settings()))
            let key = try #require(defaults.persistentDomain(forName: suite)?.keys.first)
            if value == "nonData" {
                defaults.set(value, forKey: key)
                #expect(store.load() == Settings())
                #expect(defaults.string(forKey: key) == value)
            } else {
                let data = Data(value.utf8)
                defaults.set(data, forKey: key)
                #expect(store.load() == Settings())
                #expect(defaults.data(forKey: key) == data)
            }
        }
    }

    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let suite = "io.github.capsaicin.storage-tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            let remaining = defaults.persistentDomain(forName: suite) ?? [:]
            #expect(remaining.isEmpty)
        }
        try body(defaults, suite)
    }
}
