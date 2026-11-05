@testable import CapsaicinCore
import Testing

struct EffectiveSettingsTests {
    @Test("SPEC-BLK-001 止めるスリープの設定と使う仕組みが1対1に対応する")
    func mechanismsFollowSettings() {
        let settings = Settings.premise {
            $0.blocksIdleSleep = true
            $0.blocksDisplaySleep = true
            $0.blocksManualSleep = true
            $0.blocksLidSleep = true
            $0.notifiesWithLED = false
        }
        let effective = EffectiveSettings(settings: settings, capabilities: .laptop)
        #expect(effective.mechanisms == [
            .idleSleepAssertion, .displaySleepAssertion, .systemSleepDisabled, .lidSleepControl,
        ])
    }

    @Test("SPEC-BLK-001 自動スリープだけなら自動スリープのアサーションと LED だけを使う")
    func idleOnly() {
        let effective = EffectiveSettings(settings: .premise(), capabilities: .laptop)
        #expect(effective.mechanisms == [.idleSleepAssertion, .led])
    }

    @Test("SPEC-BLK-012 変種 B と蓋のない Mac では蓋閉じスリープの保存値を使わず、保存値は残す")
    func lidSleepNeedsVariantAAndLid() {
        let settings = Settings.premise { $0.blocksLidSleep = true }
        #expect(EffectiveSettings(settings: settings, capabilities: .laptop).blocksLidSleep)
        #expect(!EffectiveSettings(settings: settings, capabilities: .laptopVariantB).blocksLidSleep)
        #expect(!EffectiveSettings(settings: settings, capabilities: .desktop).blocksLidSleep)
        #expect(settings.blocksLidSleep)
    }

    @Test("SPEC-BLK-012 手動スリープはヘルパーの状態によらず保存値を使う")
    func manualSleepUsesSavedValue() {
        let settings = Settings.premise { $0.blocksManualSleep = true }
        #expect(EffectiveSettings(settings: settings, capabilities: .laptopVariantB).blocksManualSleep)
    }

    @Test("SPEC-BLK-012 内蔵バッテリーのない Mac ではバッテリー残量の条件を持たない")
    func batteryConditionNeedsInternalBattery() {
        let settings = Settings()
        #expect(EffectiveSettings(settings: settings, capabilities: .laptop).batteryCondition != nil)
        #expect(EffectiveSettings(settings: settings, capabilities: .desktop).batteryCondition == nil)
        #expect(EffectiveSettings(settings: .premise(), capabilities: .laptop).batteryCondition == nil)
    }

    @Test("SPEC-BLK-002 蓋を閉じたら画面を消すのは、蓋閉じスリープが実際に止まるときだけ")
    func turnsOffDisplayOnlyWhenLidSleepBlocked() {
        let idleOnly = Settings.premise()
        let lid = Settings.premise { $0.blocksLidSleep = true }
        let manual = Settings.premise { $0.blocksManualSleep = true }
        #expect(!EffectiveSettings(settings: idleOnly, capabilities: .laptop).turnsOffDisplayOnLidClose)
        #expect(EffectiveSettings(settings: lid, capabilities: .laptop).turnsOffDisplayOnLidClose)
        #expect(!EffectiveSettings(settings: lid, capabilities: .laptopVariantB).turnsOffDisplayOnLidClose)
        #expect(EffectiveSettings(settings: manual, capabilities: .laptopVariantB).turnsOffDisplayOnLidClose)
        #expect(!EffectiveSettings(settings: manual, capabilities: .desktop).turnsOffDisplayOnLidClose)
    }
}
