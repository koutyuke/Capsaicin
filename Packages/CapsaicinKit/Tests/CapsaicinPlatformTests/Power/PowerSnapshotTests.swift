import CapsaicinCore
@testable import CapsaicinPlatform
import Darwin
import Foundation
import Testing

@MainActor
struct PowerPlatformSnapshotTests {
    private func battery(_ changes: [String: Any] = [:]) -> [String: Any] {
        ["Type": "InternalBattery", "Current Capacity": 1, "Max Capacity": 3,
         "Power Source State": "Battery Power"].merging(changes) { _, new in new }
    }

    @Test("SPEC-BLK-006 残量は同じ単位の比を切り捨て、充電中と AC を混同しない")
    func percentageAndAC() {
        let onBattery = PowerSnapshot(sources: [battery(["Is Charging": true])], providingSource: "AC Power")
        #expect(onBattery.powerState == PowerState(batteryLevel: 33, isOnACPower: false))
        let onAC = PowerSnapshot(
            sources: [battery(["Power Source State": "AC Power", "Is Charging": false])],
            providingSource: "Battery Power",
        )
        #expect(onAC.powerState == PowerState(batteryLevel: 33, isOnACPower: true))
        #expect(PowerSnapshot(sources: [battery(["Current Capacity": 0])], providingSource: nil)
            .powerState.batteryLevel == 0)
        #expect(PowerSnapshot(sources: [battery(["Current Capacity": 999])], providingSource: nil)
            .powerState.batteryLevel == 100)
        #expect(PowerSnapshot(sources: [battery(["Current Capacity": 2, "Max Capacity": 3])], providingSource: nil)
            .powerState.batteryLevel == 66)
    }

    @Test("SPEC-BLK-006 大きい容量でも整数乗算でオーバーフローしない")
    func largeCapacities() {
        let snapshot = PowerSnapshot(sources: [battery([
            "Current Capacity": NSNumber(value: Int64.max / 2), "Max Capacity": NSNumber(value: Int64.max),
        ])], providingSource: nil)
        #expect(snapshot.powerState.batteryLevel == 49)
        #expect(PowerSnapshot(sources: [battery([
            "Current Capacity": NSNumber(value: Int64.max), "Max Capacity": 1,
        ])], providingSource: nil).powerState.batteryLevel == 100)
    }

    @Test("SPEC-BLK-006 整数パーセントを浮動小数誤差で切り下げない")
    func exactIntegerPercentages() {
        for current in 0 ... 100 {
            let snapshot = PowerSnapshot(sources: [battery([
                "Current Capacity": current, "Max Capacity": 100,
            ])], providingSource: nil)
            #expect(snapshot.powerState.batteryLevel == current)
        }
    }

    @Test("SPEC-BLK-006 不正・欠損・不在の残量は nil")
    func malformedCapacities() {
        let malformed: [[String: Any]] = [
            ["Current Capacity": -1], ["Max Capacity": 0], ["Max Capacity": -1],
            ["Current Capacity": "1"], ["Max Capacity": "3"],
            ["Current Capacity": true], ["Max Capacity": false],
            ["Current Capacity": 1.5], ["Max Capacity": 3.0],
            ["Current Capacity": NSNumber(value: UInt64.max)],
            ["Is Present": false], ["Is Present": "yes"], ["Is Present": 1],
        ]
        for changes in malformed {
            #expect(PowerSnapshot(sources: [battery(changes)], providingSource: nil).powerState.batteryLevel == nil)
        }
        for missing in ["Current Capacity", "Max Capacity"] {
            var source = battery()
            source.removeValue(forKey: missing)
            #expect(PowerSnapshot(sources: [source], providingSource: nil).powerState.batteryLevel == nil)
        }
        #expect(PowerSnapshot(sources: [battery(["Is Present": true])], providingSource: nil)
            .powerState.batteryLevel == 33)
    }

    @Test("SPEC-SET-006 / SPEC-BLK-012 UPS と Transport は内蔵バッテリーではない")
    func hardwareDetection() {
        let ups: [String: Any] = ["Type": "UPS", "Current Capacity": 80, "Max Capacity": 100]
        let transportOnly: [String: Any] = ["Transport Type": "Internal", "Is Charging": true]
        let desktop = PowerSnapshot(sources: [ups, transportOnly], providingSource: "UPS Power")
        #expect(desktop.powerState == PowerState(batteryLevel: nil, isOnACPower: false))
        #expect(!PowerMachineCapabilities.detect(clamshellProperty: nil, snapshot: desktop).hasInternalBattery)
        let laptop = PowerSnapshot(sources: [ups, battery(["Is Present": false])], providingSource: nil)
        let capabilities = PowerMachineCapabilities.detect(clamshellProperty: false, snapshot: laptop)
        #expect(capabilities.hasLid)
        #expect(capabilities.hasInternalBattery)
        #expect(clamshellIsClosed(false) == false)
        #expect(clamshellIsClosed(true) == true)
        #expect(clamshellIsClosed(nil) == nil)
        #expect(clamshellIsClosed(1) == nil)
        #expect(clamshellIsClosed("false") == nil)
    }

    @Test("SPEC-BLK-006 内蔵バッテリーがなければ供給源の AC だけを認め、不明は false")
    func providingSourceFallback() {
        for source in [nil, "UPS Power", "Battery Power", "unknown"] {
            #expect(PowerSnapshot(sources: [], providingSource: source)
                .powerState == PowerState(batteryLevel: nil, isOnACPower: false))
        }
        #expect(PowerSnapshot(sources: [], providingSource: "AC Power")
            .powerState == PowerState(batteryLevel: nil, isOnACPower: true))
    }
}
