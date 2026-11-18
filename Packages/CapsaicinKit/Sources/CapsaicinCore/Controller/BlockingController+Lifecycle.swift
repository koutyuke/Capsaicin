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
                    ownsSleepDisabled = false
                }
            }
            reevaluateMisalignments(targets: currentTargets)
        }
    }
}
