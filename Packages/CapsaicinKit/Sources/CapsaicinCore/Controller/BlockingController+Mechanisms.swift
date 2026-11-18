extension BlockingController {
    var controllableMechanisms: Set<Mechanism> {
        var result = Set(Mechanism.allCases)
        if !ports.led.isAvailable {
            result.remove(.led)
        }
        return result
    }

    /// 扱わない仕組みと、見込みがあるべき状態と同じ仕組みは操作しない。
    @discardableResult
    func align(_ mechanisms: [Mechanism], to targets: Set<Mechanism>) -> Set<Mechanism> {
        var failures: Set<Mechanism> = []
        let controllable = controllableMechanisms
        for mechanism in mechanisms where controllable.contains(mechanism) {
            if !align(mechanism, applied: targets.contains(mechanism)) {
                failures.insert(mechanism)
            }
        }
        // 今回扱わない制御の合わせ直しを先延ばしにしない。
        if misalignments.keys.allSatisfy({ mechanisms.contains($0) }) {
            lastAlignment = ports.time.now
        }
        return failures
    }

    private func align(_ mechanism: Mechanism, applied: Bool) -> Bool {
        switch mechanism {
        case .systemSleepDisabled:
            if applied {
                raiseSleepDisabled()
            } else {
                lowerSleepDisabled()
            }
        case .idleSleepAssertion:
            set(mechanism, applied) { try setAssertion(.preventUserIdleSystemSleep, held: applied) }
        case .displaySleepAssertion:
            set(mechanism, applied) { try setAssertion(.preventUserIdleDisplaySleep, held: applied) }
        case .led:
            set(mechanism, applied) { try ports.led.setLit(applied) }
        }
    }

    private func set(_ mechanism: Mechanism, _ applied: Bool, operation: () throws -> Void) -> Bool {
        guard observed[mechanism] != applied else { return true }
        do {
            try operation()
        } catch {
            // 失敗した操作が途中まで効いたかは分からないので、状態を分からないものにする。
            observed[mechanism] = nil
            return false
        }
        observed[mechanism] = applied
        return true
    }

    private func setAssertion(_ kind: AssertionKind, held: Bool) throws {
        if held {
            try ports.assertions.createAssertion(kind)
        } else {
            try ports.assertions.releaseAssertion(kind)
        }
    }

    private func raiseSleepDisabled() -> Bool {
        let reading = try? ports.helper.readSleepDisabled()
        observed[.systemSleepDisabled] = reading
        switch SleepDisabledOwnership.raiseAction(sleepDisabled: reading, owned: ownsSleepDisabled) {
        case .failUnreadable:
            return false
        case .adoptOwn, .leaveExternal:
            return true
        case .claimThenTurnOn:
            ownsSleepDisabled = true
            do {
                try ports.helper.turnOn()
            } catch {
                return false
            }
            observed[.systemSleepDisabled] = true
            return true
        }
    }

    func lowerSleepDisabled() -> Bool {
        guard ownsSleepDisabled else { return true }
        let reading = try? ports.helper.readSleepDisabled()
        observed[.systemSleepDisabled] = reading
        switch SleepDisabledOwnership.lowerAction(sleepDisabled: reading) {
        case .failUnreadable:
            return false
        case .releaseOwnership:
            ownsSleepDisabled = false
            return true
        case .turnOff:
            do {
                try ports.helper.turnOff()
            } catch {
                return false
            }
            ownsSleepDisabled = false
            observed[.systemSleepDisabled] = false
            return true
        }
    }
}
