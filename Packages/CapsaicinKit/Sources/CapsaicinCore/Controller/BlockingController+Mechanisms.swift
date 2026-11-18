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
        case .leaveExternal:
            return true
        case .claimThenTurnOn:
            ownsSleepDisabled = true
            return sendSleepDisabledOn()
        }
    }

    func sendSleepDisabledOn() -> Bool {
        do {
            try ports.helper.turnOn()
        } catch {
            helperCleanupLost = true
            return false
        }
        helperCleanupLost = false
        observed[.systemSleepDisabled] = true
        return true
    }

    func lowerSleepDisabled() -> Bool {
        guard ownsSleepDisabled else { return true }
        let reading = try? ports.helper.readSleepDisabled()
        observed[.systemSleepDisabled] = reading
        switch SleepDisabledOwnership.lowerAction(sleepDisabled: reading) {
        case .failUnreadable:
            return false
        case .releaseOwnership:
            releaseSleepDisabledOwnership()
            return true
        case .turnOff:
            // 承認が戻るまでデーモンは起動できない。値が残っていれば合わせ直しに残す。
            guard !ports.helper.isHelperAwaitingApproval else { return false }
            do {
                try ports.helper.turnOff()
            } catch {
                // 設定変更や削除が失敗して抑止を続けるなら、閉じた接続の役目も戻す。
                if isBlocking {
                    helperCleanupLost = true
                }
                return false
            }
            releaseSleepDisabledOwnership()
            observed[.systemSleepDisabled] = false
            return true
        }
    }

    func releaseSleepDisabledOwnership() {
        ownsSleepDisabled = false
        helperCleanupLost = false
        ports.helper.closeConnection()
    }
}
