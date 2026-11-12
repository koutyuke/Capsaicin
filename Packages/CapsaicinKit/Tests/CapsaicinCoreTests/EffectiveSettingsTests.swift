@testable import CapsaicinCore
import Testing

struct EffectiveSettingsTests {
    @Test("SPEC-BLK-001 自動スリープはすべての設定の組み合わせで常に止める",
          arguments: [false, true], [false, true])
    func idleAlwaysBlocked(display: Bool, manual: Bool) {
        let settings = Settings.premise {
            $0.blocksDisplaySleep = display
            $0.blocksManualSleep = manual
            $0.notifiesWithLED = false
        }
        let mechanisms = EffectiveSettings(settings: settings, capabilities: .laptop).mechanisms
        #expect(mechanisms.contains(.idleSleepAssertion))
        #expect(mechanisms.contains(.displaySleepAssertion) == display)
        #expect(mechanisms.contains(.systemSleepDisabled) == manual)
        #expect(mechanisms.count == 1 + (display ? 1 : 0) + (manual ? 1 : 0))
    }

    @Test("SPEC-BLK-001 既定値は自動スリープと画面の自動消灯を止め、LED を点灯する")
    func defaults() {
        let effective = EffectiveSettings(settings: Settings(), capabilities: .laptop)
        #expect(effective.mechanisms == [.idleSleepAssertion, .displaySleepAssertion, .led])
    }

    @Test("SPEC-BLK-012 手動スリープは機器によらず保存値を使う")
    func manualSleepUsesSavedValue() {
        let settings = Settings.premise { $0.blocksManualSleep = true }
        #expect(EffectiveSettings(settings: settings, capabilities: .laptop).blocksManualSleep)
        #expect(EffectiveSettings(settings: settings, capabilities: .desktop).blocksManualSleep)
    }

    @Test("SPEC-BLK-012 内蔵バッテリーのない Mac ではバッテリー残量の条件を持たない")
    func batteryConditionNeedsInternalBattery() {
        #expect(EffectiveSettings(settings: Settings(), capabilities: .laptop).batteryCondition != nil)
        #expect(EffectiveSettings(settings: Settings(), capabilities: .desktop).batteryCondition == nil)
        #expect(EffectiveSettings(settings: .premise(), capabilities: .laptop).batteryCondition == nil)
    }

    @Test("SPEC-BLK-002 蓋のある Mac で手動スリープを止めて消灯を選んだときだけ画面を消す",
          arguments: [false, true], LidCloseDisplay.allCases)
    func lidCloseDisplayNeedsManualAndTurnOff(manual: Bool, display: LidCloseDisplay) {
        let settings = Settings.premise {
            $0.blocksManualSleep = manual
            $0.lidCloseDisplay = display
        }
        #expect(EffectiveSettings(settings: settings, capabilities: .laptop).shouldSleepDisplayOnLidClose
            == (manual && display == .turnOff))
        #expect(!EffectiveSettings(settings: settings, capabilities: .desktop).shouldSleepDisplayOnLidClose)
    }

    @Test("SPEC-BLK-013 蓋のあるMacで手動スリープを止めて明るさを0を選ぶときだけ暗くする",
          arguments: [false, true], LidCloseDisplay.allCases)
    func brightnessNeedsLidManualAndChoice(manual: Bool, display: LidCloseDisplay) {
        let settings = Settings.premise {
            $0.blocksManualSleep = manual
            $0.lidCloseDisplay = display
        }
        let effective = EffectiveSettings(settings: settings, capabilities: .laptop)
        #expect(effective.shouldZeroBrightnessOnLidClose == (manual && display == .zeroBrightness))
        #expect(!EffectiveSettings(settings: settings, capabilities: .desktop).shouldZeroBrightnessOnLidClose)
        var other = settings
        other.lidCloseDisplay = .keepOn
        #expect(effective.mechanisms == EffectiveSettings(settings: other, capabilities: .laptop).mechanisms)
    }
}
