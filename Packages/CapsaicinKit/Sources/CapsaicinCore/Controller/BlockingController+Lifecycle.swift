public extension BlockingController {
    func restoreBrightnessAtLaunch() {
        notifyingWarnings {
            guard let record = ports.brightnessRecords.load() else { return }
            savedBrightness = record.savedBrightness
            if savedBrightness == nil {
                removeBrightnessRecord()
            } else {
                restoreBrightness(onlyIfZero: true)
            }
        }
    }

    /// 輝度の復元と、ヘルパーの登録し直しの後に呼ぶ。
    func finishLaunching() {
        notifyingWarnings { alignStopped() }
    }

    /// 終了の種類によらず後片付けする。HUD は出さない。
    func terminate() {
        notifyingWarnings { restoreStopped() }
    }

    func helperConnectionLost(_ loss: HelperConnectionLoss) {
        guard ownsSleepDisabled else { return }
        helperCleanupLost = true
        let targets = currentTargets
        guard targets.contains(.systemSleepDisabled) else { return }
        notifyingWarnings {
            if ports.helper.isHelperAwaitingApproval {
                release(.helperApprovalRevoked)
                return
            }
            if loss == .interrupted {
                // 値が 1 のままでも、後片付けを任せるには新しい接続に on を送る。
                let restored = sendSleepDisabledOn()
                if misalignments.keys.allSatisfy({ $0 == .systemSleepDisabled }) {
                    lastAlignment = ports.time.now
                }
                // 再送を待つ間に利用者が許可を外すこともある。
                if !restored, ports.helper.isHelperAwaitingApproval {
                    release(.helperApprovalRevoked)
                    return
                }
            }
            reevaluateMisalignments(targets: targets)
        }
    }

    func prepareHelperRemoval() -> Bool {
        notifyingWarnings {
            let lowered = lowerSleepDisabled()
            reevaluateMisalignments(targets: currentTargets)
            return lowered
        }
    }

    /// アプリは、この後の `settings` を保存する。
    func helperRemovalSucceeded() {
        notifyingWarnings {
            var newSettings = settings
            newSettings.blocksManualSleep = false
            // 所有は削除前に外しているため、disablesleep には触れずに反映できる。
            _ = applySettings(newSettings)
        }
    }

    /// 削除に失敗した。途中で disablesleep が変わっていることがあるので、読み直して所有を更新する。
    func helperRemovalFailed() {
        notifyingWarnings {
            if ownsSleepDisabled {
                let reading = try? ports.helper.readSleepDisabled()
                observed[.systemSleepDisabled] = reading
                if reading == false {
                    releaseSleepDisabledOwnership()
                }
            }
            reevaluateMisalignments(targets: currentTargets)
        }
    }
}
