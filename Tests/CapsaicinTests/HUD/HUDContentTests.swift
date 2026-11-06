import CapsaicinCore
import Foundation
import Testing

private final class HUDCatalogLocator: NSObject {}

struct HUDContentTests {
    private var status: BlockingStatus {
        BlockingStatus(session: nil, batteryCondition: nil, misalignments: [:], isRecordUnsaved: false)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func content(
        _ event: BlockingEvent, status: BlockingStatus? = nil, previousSession: BlockingSession? = nil,
    ) throws -> HUDContent {
        let products = Bundle(for: HUDCatalogLocator.self).bundleURL.deletingLastPathComponent()
        let bundle = try #require(Bundle(url: products.appending(path: "Capsaicin.app")))
        return try #require(HUDContent.make(
            for: event, status: status ?? self.status, previousSession: previousSession,
            now: Date(timeIntervalSince1970: 0), calendar: calendar, bundle: bundle,
        ))
    }

    @Test("SPEC-HUD-002 開始は塗りつぶしのアイコンと状態だけを出し、バッテリー条件は添えない")
    func startWithoutTime() throws {
        var status = status
        status.session = BlockingSession(timeLimit: nil)
        status.batteryCondition = try BatteryCondition(
            threshold: #require(BatteryThreshold(percent: 20)),
            ignoresOnACPower: true,
        )
        let value = try content(.started(.user(.menu)), status: status)
        #expect(value.symbol == "capslock.fill")
        #expect(value.state == "スリープ防止 オン")
        #expect(value.detail == nil)
        #expect(value.announcement == value.state)
    }

    @Test("SPEC-HUD-002 開始時は Core が選んだ先の時間条件だけを出す", arguments: [TimeLimitSource.timer, .specifiedTime])
    func startWithTime(source: TimeLimitSource) throws {
        var status = status
        status.session = BlockingSession(timeLimit: TimeLimit(date: Date(timeIntervalSince1970: 5400), source: source))
        let value = try content(.started(.user(.hotkey)), status: status)
        #expect(value.detail == (source == .timer ? "1時間30分" : "1:30まで"))
        #expect(!value.announcement.contains("·"))
        #expect(try value.announcement == "スリープ防止 オン、\(#require(value.detail))")
    }

    @Test("SPEC-HUD-002 手動解除は輪郭のアイコンと状態だけを出す")
    func manualRelease() throws {
        let value = try content(.released(.user(.menu)))
        #expect(value.symbol == "capslock")
        #expect(value.state == "スリープ防止 オフ")
        #expect(value.detail == nil)
        #expect(value.announcement == value.state)
    }

    @Test("SPEC-HUD-002 タイマーの解除理由は由来から決める")
    func timerRelease() throws {
        let value = try content(.released(.timeLimit(.timer)))
        #expect(value.detail == "タイマー終了")
        #expect(value.state == "スリープ防止 オフ")
        #expect(value.symbol == "capslock")
    }

    @Test("SPEC-HUD-002 指定時刻の解除は解除前のセッションの時刻を出す")
    func specifiedTimeRelease() throws {
        let previous = BlockingSession(timeLimit: TimeLimit(
            date: Date(timeIntervalSince1970: 14400),
            source: .specifiedTime,
        ))
        #expect(try content(.released(.timeLimit(.specifiedTime)), previousSession: previous).detail == "指定時刻（4:00）")
        #expect(try content(.released(.timeLimit(.specifiedTime))).detail == "指定時刻になりました")
    }

    @Test("SPEC-HUD-002 バッテリーによる解除はしきい値を示す")
    func batteryRelease() throws {
        var status = status
        status.batteryCondition = try BatteryCondition(
            threshold: #require(BatteryThreshold(percent: 20)),
            ignoresOnACPower: false,
        )
        #expect(try content(.released(.batteryBelowThreshold), status: status).detail == "バッテリー 20%")
    }

    @Test("SPEC-HUD-002 開始拒否は理由を区別する")
    func rejectionReasons() throws {
        let cases: [(StartRejection, String)] = [
            (.batteryBelowThreshold, "バッテリー残量不足"),
            (.helperNotInstalled, "ヘルパー未構成"),
            (.mechanismsFailed([.idleSleepAssertion]), "設定の適用に失敗"),
            (.recordNotSaved, "状態を保存できません"),
        ]
        for (reason, expected) in cases {
            let value = try content(.startRejected(.user(.menu), reason))
            #expect(value.symbol == "capslock")
            #expect(value.state == "開始できません")
            #expect(value.detail == expected)
        }
    }

    @Test("SPEC-HUD-002 解除後の不整合は通常の解除理由を置き換える")
    func unalignedRelease() throws {
        var status = status
        status.misalignments = [.led: .leftApplied]
        for reason: ReleaseReason in [
            .user(.hotkey),
            .timeLimit(.timer),
            .timeLimit(.specifiedTime),
            .batteryBelowThreshold,
        ] {
            let value = try content(.released(reason), status: status)
            #expect(value.detail == "一部を戻せませんでした")
            #expect(value.symbol == "capslock")
            #expect(value.state == "スリープ防止 オフ")
        }
    }

    @Test("SPEC-HUD-002 警告だけの更新では内容を作らず、表示する場面の判断は呼び出し元に任せる")
    func warningAndOrigin() throws {
        #expect(HUDContent.make(for: .warningsChanged, status: status) == nil)
        #expect(try content(.started(.user(.cli))).symbol == "capslock.fill")
        #expect(try content(.started(.resume)).symbol == "capslock.fill")
    }

    @Test("SPEC-HUD-005 SPEC-HUD-006 入る・留まる間の置き換えは待たず、出る途中なら0.15秒で戻す")
    func replacementPhases() {
        #expect(HUDPhase.hidden.replacementDuration == 0.20)
        #expect(HUDPhase.entering.replacementDuration == 0)
        #expect(HUDPhase.holding.replacementDuration == 0)
        #expect(HUDPhase.exiting.replacementDuration == 0.15)
    }
}
