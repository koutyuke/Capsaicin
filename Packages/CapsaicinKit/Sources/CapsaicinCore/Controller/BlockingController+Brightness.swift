import OSLog

private let brightnessLogger = Logger(subsystem: "io.github.koutyuke.capsaicin", category: "Brightness")

public extension BlockingController {
    /// 閉じた通知でだけ暗くする。開始時にすでに閉じていても、この入口は呼ばない。
    func lidClosed() {
        guard isBlocking, effectiveSettings.shouldZeroBrightnessOnLidClose else { return }
        notifyingWarnings {
            do {
                if savedBrightness == nil {
                    guard let value = try ports.brightness.readBrightness() else { return }
                    guard ports.brightnessRecords.save(value) else {
                        brightnessSaveFailed = true
                        return
                    }
                    savedBrightness = value
                    brightnessSaveFailed = false
                    // 原子的な保存で、削除を待っていた古い記録も置き換わった。
                    nextBrightnessDeletionAttempt = nil
                }
                try ports.brightness.setBrightness(0)
                keepsBrightnessZero = true
            } catch {
                brightnessLogger.error("内蔵ディスプレイを暗くできません: \(error, privacy: .public)")
            }
        }
    }

    func lidOpened() {
        notifyingWarnings { endBrightnessControl() }
    }
}

extension BlockingController {
    func keepBrightnessZeroWhileClosed() {
        guard isBlocking, effectiveSettings.shouldZeroBrightnessOnLidClose,
              keepsBrightnessZero else { return }
        do {
            guard let current = try ports.brightness.readBrightness() else {
                brightnessLogger.error("輝度を0に保つ内蔵ディスプレイが見つかりません。")
                return
            }
            if current > 0 {
                try ports.brightness.setBrightness(0)
            }
        } catch {
            brightnessLogger.error("内蔵ディスプレイの輝度を0に保てません: \(error, privacy: .public)")
        }
    }

    func endBrightnessControl() {
        keepsBrightnessZero = false
        brightnessSaveFailed = false
        restoreBrightness()
    }

    /// 起動時だけ、アプリを開く前に利用者が戻した輝度を上書きしない。
    func restoreBrightness(onlyIfZero: Bool = false) {
        guard let saved = savedBrightness else { return }
        do {
            if onlyIfZero {
                guard let current = try ports.brightness.readBrightness() else {
                    brightnessLogger.error("輝度を読める内蔵ディスプレイが見つかりません。記録を残します。")
                    return
                }
                if current == 0 {
                    try ports.brightness.setBrightness(saved)
                }
            } else {
                try ports.brightness.setBrightness(saved)
            }
            savedBrightness = nil
            removeBrightnessRecord()
        } catch {
            brightnessLogger.error("内蔵ディスプレイの輝度を戻せません。記録を残します: \(error, privacy: .public)")
        }
    }

    /// 復元した値はメモリーに残さず、失敗したら削除だけを試み直す。
    func removeBrightnessRecord() {
        nextBrightnessDeletionAttempt = ports.brightnessRecords.remove()
            ? nil : ports.time.now.addingTimeInterval(Self.reconcileInterval)
    }
}
