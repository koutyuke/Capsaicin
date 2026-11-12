/// 開始、解除、設定の変更、合わせ直しの手順。記録の更新の順序は再開用の記録の仕様に従う。
extension BlockingController {
    /// あるべき状態で適用している仕組み。停止中は空。
    var currentTargets: Set<Mechanism> {
        isBlocking ? effectiveSettings.mechanisms : []
    }

    /// 開始する（再開を含む）。止めるスリープに必要な仕組みは全部か無しかにする。
    func start(_ newSession: BlockingSession, trigger: StartTrigger) -> StartResult {
        let effective = effectiveSettings
        if let rejection = BlockingRules.rejectionBeforeApplying(
            effective: effective, power: ports.power.powerState, isHelperInstalled: ports.helper.isHelperInstalled,
        ) {
            return reject(trigger, rejection)
        }

        let targets = effective.mechanisms
        // 止めるスリープに必要な仕組みを並びの順（ヘルパーが先）に適用し、最初の失敗でやめて停止中に戻す。
        let required = Mechanism.allCases.filter { $0 != .led && targets.contains($0) }
        for mechanism in required {
            if let failure = align([mechanism], to: targets)[mechanism] {
                return reject(trigger, failure == .recordNotSaved ? .recordNotSaved : .mechanismsFailed([mechanism]))
            }
        }
        // 必要な仕組みがそろってから、LED を点け、前から残っていたものを合わせる。どちらの失敗も開始を妨げない。
        align(Mechanism.allCases.filter { !required.contains($0) }, to: targets)

        // 抑止のセッションは、仕組みを適用した後に書く。
        record.session = newSession
        let crashLaunches = record.crashLaunches
        if case .user = trigger {
            record.crashLaunches = []
        }
        reevaluateMisalignments(targets: targets)
        guard saveRecord() else {
            // 一覧を空にするのは開始が成り立ったときだけ。
            record.crashLaunches = crashLaunches
            return reject(trigger, .recordNotSaved)
        }
        session = newSession
        onEvent?(.started(trigger))
        return .started
    }

    func reject(_ trigger: StartTrigger, _ rejection: StartRejection) -> StartResult {
        restoreStopped(clearingCrashLaunches: false)
        onEvent?(.startRejected(trigger, rejection))
        return .rejected(rejection)
    }

    func release(_ reason: ReleaseReason) {
        restoreStopped(clearingCrashLaunches: true)
        onEvent?(.released(reason))
    }

    /// 抑止のセッションを先に消してから、前のプロセスから残ったものを含むすべての仕組みを停止中のあるべき状態に合わせる。
    /// 合わせられなくても途中で止めない。
    func restoreStopped(clearingCrashLaunches: Bool) {
        restoreBrightness()
        session = nil
        if record.session != nil {
            record.session = nil
            saveRecord()
        }
        align(Mechanism.allCases, to: [])
        reevaluateMisalignments(targets: [])
        if clearingCrashLaunches {
            record.crashLaunches = []
        }
        saveRecord()
    }

    /// 自動の解除の条件が成り立っていれば解除する。
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
            result = .reverted(failed: Set(failures.keys))
        }
        reevaluateMisalignments(targets: currentTargets)
        saveRecord()
        // バッテリー残量の条件の変更は、いまの抑止にその場で効く。
        if result == .applied {
            releaseIfConditionMet()
        }
        return result
    }

    /// 一覧にある仕組みだけを操作し、記録の保存も試み直す。
    func reconcileListed() {
        let targets = currentTargets
        align(Mechanism.allCases.filter { misalignments[$0] != nil }, to: targets)
        reevaluateMisalignments(targets: targets)
        saveRecord()
    }

    func reevaluateMisalignments(targets: Set<Mechanism>) {
        record.misalignments = MechanismAlignment.misalignments(
            targets: targets,
            observed: observed,
            ownsSleepDisabled: record.ownsSleepDisabled,
            controllable: controllableMechanisms,
        )
    }

    /// 最終更新の時刻を更新して保存する。保存できなかったら、保存できるまで警告を出す。
    @discardableResult
    func saveRecord() -> Bool {
        record.lastUpdated = ports.time.now
        isRecordUnsaved = !ports.records.save(record)
        return !isRecordUnsaved
    }

    /// 警告（合わせられていない制御、保存できていない記録）が変わったら通知する。
    @discardableResult
    func notifyingWarnings<Result>(_ body: () -> Result) -> Result {
        let before = (misalignments, isRecordUnsaved)
        let result = body()
        if before != (misalignments, isRecordUnsaved) {
            onEvent?(.warningsChanged)
        }
        return result
    }
}
