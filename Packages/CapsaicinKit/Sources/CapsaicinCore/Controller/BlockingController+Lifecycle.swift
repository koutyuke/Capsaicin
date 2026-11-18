public extension BlockingController {
    @discardableResult
    func launch() -> LaunchReason {
        notifyingWarnings {
            let now = ports.time.now
            let stored = ports.records.load()
            let bootTime = ports.bootTime.bootTime
            // 起動の理由は、記録を書き換える前に判定する。
            let reason = LaunchRules.launchReason(record: stored, bootTime: bootTime)
            record = stored ?? ResumeRecord(lastUpdated: now)
            if bootTime == .distantPast {
                // 起動時刻を読めないときは、前回の所有で外部のものを下ろさないよう、セッションと所有を捨てる。
                record.session = nil
                record.ownsSleepDisabled = false
            } else if let stored, LaunchRules.hasMacBooted(since: stored, bootTime: bootTime) {
                // 前の起動で立てたものは起動時の LaunchDaemon が下ろしている。いま立っているものは外部のもの。
                record.ownsSleepDisabled = false
            }
            record.crashLaunches = LaunchRules.updatingCrashLaunches(
                record.crashLaunches, at: now, afterCrash: reason == .afterCrash,
            )
            record.isRunning = true
            record.exitReason = nil
            saveRecord()
            // 再開でも後片付けでも、仕組みを操作する前に戻す。
            restoreBrightness()

            let resumes = LaunchRules.shouldResume(
                reason: reason,
                policy: settings.resumePolicy,
                session: record.session,
                isCrashLimitReached: LaunchRules.isCrashLimitReached(record.crashLaunches),
                now: now,
            )
            if resumes, let resumed = record.session {
                _ = start(resumed, trigger: .resume)
            } else {
                restoreStopped(clearingCrashLaunches: false)
            }
            return reason
        }
    }

    /// 利用者の終了。解除と同じに戻す。合わせられていない制御が残ったら true を返すので、アプリはエラーのダイアログを出してから終了する。
    func quitByUser() -> Bool {
        notifyingWarnings {
            if isBlocking {
                release(.quit)
            } else {
                restoreStopped(clearingCrashLaunches: true)
            }
            record.exitReason = .userQuit
            record.isRunning = false
            saveRecord()
            return !misalignments.isEmpty
        }
    }

    /// セッションの終了による終了（ログアウト、再起動、システム終了）。仕組みは戻し、抑止のセッションは次の起動のために記録に残す。
    func endSession() {
        notifyingWarnings {
            restoreBrightness()
            session = nil
            align(Mechanism.allCases, to: [])
            reevaluateMisalignments(targets: [])
            record.exitReason = .sessionEnd
            record.isRunning = false
            saveRecord()
        }
    }

    /// 理由不明の終了。セッションを消して後片付けし、自動再開や終了を妨げるダイアログは要求しない。
    func terminateForUnknownReason() {
        notifyingWarnings {
            restoreStopped(clearingCrashLaunches: true)
            record.exitReason = nil
            record.isRunning = false
            saveRecord()
        }
    }

    func prepareHelperRemoval() -> Bool {
        notifyingWarnings {
            let failure = lowerSleepDisabled()
            reevaluateMisalignments(targets: currentTargets)
            let saved = saveRecord()
            return failure == nil && saved
        }
    }

    /// アプリは、この後の `settings` を保存する。
    func helperRemovalSucceeded() {
        notifyingWarnings {
            record.ownsSleepDisabled = false
            reevaluateMisalignments(targets: currentTargets)
            saveRecord()
            var newSettings = settings
            newSettings.blocksManualSleep = false
            // 所有がないので disablesleep には触れず、反映は失敗しない。抑止中なら、反映の中で評価し直して保存する。
            _ = applySettings(newSettings)
        }
    }

    /// ヘルパーの削除に失敗した。途中で disablesleep が変わっていることがあるので、読み直して所有を更新する。
    func helperRemovalFailed() {
        notifyingWarnings {
            if record.ownsSleepDisabled {
                let reading = try? ports.helper.readSleepDisabled()
                observed[.systemSleepDisabled] = reading
                if reading == false {
                    record.ownsSleepDisabled = false
                }
            }
            reevaluateMisalignments(targets: currentTargets)
            saveRecord()
        }
    }
}
