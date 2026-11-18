extension BlockingController {
    var currentTargets: Set<Mechanism> {
        isBlocking ? effectiveSettings.mechanisms : []
    }

    /// 止めるスリープに必要な仕組みは全部か無しかにする。
    func start(_ newSession: BlockingSession, from origin: RequestOrigin) -> StartResult {
        let effective = effectiveSettings
        if let rejection = BlockingRules.rejectionBeforeApplying(
            effective: effective, power: ports.power.powerState, isHelperInstalled: ports.helper.isHelperInstalled,
        ) {
            return reject(origin, rejection)
        }

        let targets = effective.mechanisms
        // 止めるスリープに必要な仕組みを並びの順（ヘルパーが先）に適用し、最初の失敗でやめて停止中に戻す。
        let required = Mechanism.allCases.filter { $0 != .led && targets.contains($0) }
        for mechanism in required {
            guard align([mechanism], to: targets).isEmpty else {
                return reject(origin, .mechanismsFailed([mechanism]))
            }
        }
        // 必要な仕組みがそろってから、LED を点け、前から残っていたものを合わせる。どちらの失敗も開始を妨げない。
        align(Mechanism.allCases.filter { !required.contains($0) }, to: targets)

        reevaluateMisalignments(targets: targets)
        session = newSession
        onEvent?(.started(origin))
        return .started
    }

    func reject(_ origin: RequestOrigin, _ rejection: StartRejection) -> StartResult {
        restoreStopped()
        onEvent?(.startRejected(origin, rejection))
        return .rejected(rejection)
    }

    func release(_ reason: ReleaseReason) {
        restoreStopped()
        onEvent?(.released(reason))
    }

    /// 抑止のセッションを先に消してから、前のプロセスから残ったものを含むすべての仕組みを停止中のあるべき状態に合わせる。
    /// 合わせられなくても途中で止めない。
    func restoreStopped() {
        session = nil
        endBrightnessControl()
        alignStopped()
        ports.helper.closeConnection()
    }

    func alignStopped() {
        align(Mechanism.allCases, to: [])
        reevaluateMisalignments(targets: [])
    }

    @discardableResult
    func releaseIfConditionMet() -> Bool {
        guard let session,
              let reason = BlockingRules.automaticReleaseReason(
                  session: session,
                  batteryCondition: effectiveSettings.batteryCondition,
                  power: ports.power.powerState,
                  now: ports.time.now,
              )
        else { return false }
        release(reason)
        return true
    }

    func applySettings(_ newSettings: Settings) -> SettingsChangeResult {
        guard isBlocking else {
            // 停止中は仕組みに触れないので、常に受け入れる。
            settings = newSettings
            return .applied
        }
        let oldSettings = settings
        let oldTargets = EffectiveSettings(settings: oldSettings, capabilities: capabilities).mechanisms
        let newTargets = EffectiveSettings(settings: newSettings, capabilities: capabilities).mechanisms
        // あるべき状態が変わらない仕組みは、前から合っていないものも含めて操作せずに引き継ぐ。
        let changed = Mechanism.allCases.filter { oldTargets.contains($0) != newTargets.contains($0) }

        settings = newSettings
        let failures = align(changed, to: newTargets)
        let result: SettingsChangeResult
        if failures.isEmpty {
            result = .applied
        } else {
            settings = oldSettings
            align(changed, to: oldTargets)
            result = .reverted(failed: failures)
        }
        reevaluateMisalignments(targets: currentTargets)
        // バッテリー残量の条件の変更は、いまの抑止にその場で効く。
        if result == .applied {
            releaseIfConditionMet()
        }
        return result
    }

    /// 一覧にある仕組みだけを操作する。
    func reconcileListed() {
        let targets = currentTargets
        align(Mechanism.allCases.filter { misalignments[$0] != nil }, to: targets)
        reevaluateMisalignments(targets: targets)
    }

    func reevaluateMisalignments(targets: Set<Mechanism>) {
        misalignments = MechanismAlignment.misalignments(
            targets: targets,
            observed: observed,
            ownsSleepDisabled: ownsSleepDisabled,
            controllable: controllableMechanisms,
        )
        if helperCleanupLost, targets.contains(.systemSleepDisabled) {
            misalignments[.systemSleepDisabled] = .notApplied
        }
    }

    @discardableResult
    func notifyingWarnings<Result>(_ body: () -> Result) -> Result {
        let before = (misalignments, brightnessWarnings)
        let result = body()
        if before != (misalignments, brightnessWarnings) {
            onEvent?(.warningsChanged)
        }
        return result
    }
}
