import OSLog

private let brightnessLogger = Logger(subsystem: "io.github.koutyuke.capsaicin", category: "Brightness")

public extension BlockingController {
    /// 閉じた通知でだけ暗くする。開始時にすでに閉じていても、この入口は呼ばない。
    func lidClosed() {
        guard isBlocking, effectiveSettings.shouldZeroBrightnessOnLidClose else { return }
        do {
            if record.savedBrightness == nil {
                guard let value = try ports.brightness.readBrightness(), saveBrightness(value) else { return }
            }
            try ports.brightness.setBrightness(0)
        } catch {
            brightnessLogger.error("内蔵ディスプレイを暗くできません: \(error, privacy: .public)")
        }
    }

    func lidOpened() {
        restoreBrightness()
    }
}

extension BlockingController {
    /// 設定や抑止の状態ではなく、暗くした記録があることに結びつけて戻す。
    func restoreBrightness() {
        guard let saved = record.savedBrightness else { return }
        do {
            guard let current = try ports.brightness.readBrightness() else {
                brightnessLogger.error("輝度を戻す内蔵ディスプレイが見つかりません。記録を残します。")
                return
            }
            if current == 0 {
                try ports.brightness.setBrightness(saved)
            }
            _ = saveBrightness(nil)
        } catch {
            brightnessLogger.error("内蔵ディスプレイの輝度を戻せません。記録を残します: \(error, privacy: .public)")
        }
    }

    /// 輝度だけの保存失敗は抑止の警告に含めない。保存できるまでは元の記録を保つ。
    private func saveBrightness(_ value: Float?) -> Bool {
        var updated = record
        updated.savedBrightness = value
        updated.lastUpdated = ports.time.now
        guard ports.records.save(updated) else {
            brightnessLogger.error("内蔵ディスプレイの輝度の記録を保存できません。")
            return false
        }
        record = updated
        return true
    }
}
