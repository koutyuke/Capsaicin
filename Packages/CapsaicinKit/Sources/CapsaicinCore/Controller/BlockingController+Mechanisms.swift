/// 仕組みを操作できなかった理由。
enum AlignmentFailure: Hashable {
    case operationFailed
    /// disablesleep の所有を保存できなかったので `on` を実行しなかった。
    case recordNotSaved
}

/// 仕組みをあるべき状態に向けて操作する手順。
extension BlockingController {
    /// この環境で扱う仕組み。LED を制御できない環境と、蓋閉じスリープの制御を使わない環境では、それを除く。
    var controllableMechanisms: Set<Mechanism> {
        var result = Set(Mechanism.allCases)
        if !ports.led.isAvailable {
            result.remove(.led)
        }
        if !capabilities.usesLidSleepControl {
            result.remove(.lidSleepControl)
        }
        return result
    }

    /// 仕組みを並びの順に操作し、操作できなかった仕組みを返す。扱わない仕組みと、見込みがあるべき状態と同じ仕組みは操作しない。
    @discardableResult
    func align(_ mechanisms: [Mechanism], to targets: Set<Mechanism>) -> [Mechanism: AlignmentFailure] {
        var failures: [Mechanism: AlignmentFailure] = [:]
        let controllable = controllableMechanisms
        for mechanism in mechanisms where controllable.contains(mechanism) {
            failures[mechanism] = align(mechanism, applied: targets.contains(mechanism))
        }
        // 今回扱わない制御の合わせ直しを先延ばしにしない。
        if misalignments.keys.allSatisfy({ mechanisms.contains($0) }) {
            lastAlignment = ports.time.now
        }
        return failures
    }

    private func align(_ mechanism: Mechanism, applied: Bool) -> AlignmentFailure? {
        switch mechanism {
        case .systemSleepDisabled:
            alignSleepDisabled(applied: applied)
        case .lidSleepControl:
            set(mechanism, applied) { try ports.lidSleep.setLidSleepDisabled(applied) }
        case .idleSleepAssertion:
            set(mechanism, applied) { try setAssertion(.preventUserIdleSystemSleep, held: applied) }
        case .displaySleepAssertion:
            set(mechanism, applied) { try setAssertion(.preventUserIdleDisplaySleep, held: applied) }
        case .led:
            set(mechanism, applied) { try ports.led.setLit(applied) }
        }
    }

    private func set(_ mechanism: Mechanism, _ applied: Bool, operation: () throws -> Void) -> AlignmentFailure? {
        guard observed[mechanism] != applied else { return nil }
        do {
            try operation()
        } catch {
            // 失敗した操作が途中まで効いたかは分からないので、状態を分からないものにする。
            observed[mechanism] = nil
            return .operationFailed
        }
        observed[mechanism] = applied
        return nil
    }

    private func setAssertion(_ kind: AssertionKind, held: Bool) throws {
        if held {
            try ports.assertions.createAssertion(kind)
        } else {
            try ports.assertions.releaseAssertion(kind)
        }
    }

    private func alignSleepDisabled(applied: Bool) -> AlignmentFailure? {
        if applied {
            return raiseSleepDisabled()
        }
        return lowerSleepDisabled()
    }

    /// disablesleep を立てるときの規則。
    private func raiseSleepDisabled() -> AlignmentFailure? {
        let reading = try? ports.helper.readSleepDisabled()
        observed[.systemSleepDisabled] = reading
        switch SleepDisabledOwnership.raiseAction(sleepDisabled: reading, owned: record.ownsSleepDisabled) {
        case .failUnreadable:
            return .operationFailed
        case .adoptOwn:
            return nil
        case .leaveExternal:
            record.ownsSleepDisabled = false
            return nil
        case .claimThenTurnOn:
            record.ownsSleepDisabled = true
            guard saveRecord() else {
                record.ownsSleepDisabled = false
                return .recordNotSaved
            }
            do {
                try ports.helper.turnOn()
            } catch {
                return .operationFailed
            }
            observed[.systemSleepDisabled] = true
            return nil
        }
    }

    /// disablesleep を下ろすときの規則。自分が立てたものだけを下ろす。
    private func lowerSleepDisabled() -> AlignmentFailure? {
        guard record.ownsSleepDisabled else { return nil }
        let reading = try? ports.helper.readSleepDisabled()
        observed[.systemSleepDisabled] = reading
        switch SleepDisabledOwnership.lowerAction(sleepDisabled: reading) {
        case .failUnreadable:
            return .operationFailed
        case .releaseOwnership:
            record.ownsSleepDisabled = false
            return nil
        case .turnOff:
            do {
                try ports.helper.turnOff()
            } catch {
                return .operationFailed
            }
            record.ownsSleepDisabled = false
            observed[.systemSleepDisabled] = false
            return nil
        }
    }
}
