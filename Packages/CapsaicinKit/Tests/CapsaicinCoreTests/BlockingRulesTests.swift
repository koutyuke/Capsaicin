@testable import CapsaicinCore
import Foundation
import Testing

struct BlockingRulesTests {
    private let condition = BatteryCondition(threshold: BatteryThreshold(percent: 20)!, ignoresOnACPower: true)

    @Test(
        "SPEC-BLK-006 しきい値を下回り、電源アダプターで無視されないときだけ成り立つ",
        arguments: [
            // (残量, 電源アダプター, 無視する, 成り立つ)
            (19, false, true, true),
            (20, false, true, false),
            (19, true, true, false),
            (19, true, false, true),
            (0, false, false, true),
        ],
    )
    func batteryCondition(level: Int, onAC: Bool, ignores: Bool, met: Bool) throws {
        let condition = try BatteryCondition(
            threshold: #require(BatteryThreshold(percent: 20)),
            ignoresOnACPower: ignores,
        )
        #expect(condition.isMet(by: PowerState(batteryLevel: level, isOnACPower: onAC)) == met)
    }

    @Test("SPEC-BLK-006 残量が分からなければ成り立たない")
    func unknownLevel() {
        #expect(!condition.isMet(by: PowerState(batteryLevel: nil, isOnACPower: false)))
    }

    @Test("SPEC-BLK-008 開始しようとした時点でバッテリー残量の条件が成り立っていれば拒否する")
    func rejectsWhenBatteryLow() {
        let effective = EffectiveSettings(settings: Settings(), capabilities: .laptop)
        let low = PowerState(batteryLevel: 10, isOnACPower: false)
        let rejection = BlockingRules.rejectionBeforeApplying(effective: effective, power: low, isHelperInstalled: true)
        #expect(rejection == .batteryBelowThreshold)
        let charging = PowerState(batteryLevel: 10, isOnACPower: true)
        #expect(BlockingRules
            .rejectionBeforeApplying(effective: effective, power: charging, isHelperInstalled: true) == nil)
    }

    @Test("SPEC-BLK-012 内蔵バッテリーのない Mac ではバッテリー残量を開始の拒否に使わない")
    func desktopIgnoresBattery() {
        let effective = EffectiveSettings(settings: Settings(), capabilities: .desktop)
        let low = PowerState(batteryLevel: 10, isOnACPower: false)
        #expect(BlockingRules.rejectionBeforeApplying(effective: effective, power: low, isHelperInstalled: true) == nil)
    }

    @Test("SPEC-BLK-012 手動スリープを止める設定でヘルパーが使えなければ開始を拒否する")
    func rejectsWithoutHelper() {
        let effective = EffectiveSettings(settings: .premise { $0.blocksManualSleep = true }, capabilities: .laptop)
        let power = PowerState(batteryLevel: 80, isOnACPower: false)
        #expect(BlockingRules
            .rejectionBeforeApplying(effective: effective, power: power, isHelperInstalled: false) ==
            .helperNotInstalled)
    }

    @Test("SPEC-BLK-004 SPEC-BLK-005 時間の条件で解除するときは、その由来を理由にする")
    func timeLimitReason() {
        let limit = TimeLimit(date: Date(timeIntervalSince1970: 1000), source: .specifiedTime)
        let power = PowerState(batteryLevel: 80, isOnACPower: false)
        let reason = BlockingRules.automaticReleaseReason(
            session: BlockingSession(timeLimit: limit), batteryCondition: nil, power: power, now: limit.date,
        )
        #expect(reason == .timeLimit(.specifiedTime))
    }

    @Test("SPEC-BLK-006 SPEC-BLK-007 抑止中にバッテリー残量の条件が成り立てば解除の理由になる")
    func batteryReason() {
        let low = PowerState(batteryLevel: 10, isOnACPower: false)
        let reason = BlockingRules.automaticReleaseReason(
            session: BlockingSession(timeLimit: nil), batteryCondition: condition, power: low, now: Date(),
        )
        #expect(reason == .batteryBelowThreshold)
        let fine = PowerState(batteryLevel: 50, isOnACPower: false)
        #expect(BlockingRules.automaticReleaseReason(
            session: BlockingSession(timeLimit: nil), batteryCondition: condition, power: fine, now: Date(),
        ) == nil)
    }
}
