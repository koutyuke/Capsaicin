import CapsaicinCore
import Foundation
import Sparkle
import Testing

@MainActor
struct UpdateInstallationTests {
    @Test("SPEC-LCY-008 準備済みのインストールは確認の結果を返す", arguments: [false, true])
    func confirmsInstallation(confirmed: Bool) {
        var confirmations = 0
        let reply = UpdateInstallationReply.resolve(.install, stage: .installing, isBlocking: true) {
            confirmations += 1
            return confirmed
        }
        #expect(reply == (confirmed ? .install : .dismiss))
        #expect(confirmations == 1)
    }

    @Test("SPEC-LCY-008 抑止を止めていれば確認せずインストールする",
          arguments: [SPUUserUpdateStage.notDownloaded, .downloaded, .installing])
    func doesNotConfirmWhileIdle(stage: SPUUserUpdateStage) {
        let reply = UpdateInstallationReply.resolve(.install, stage: stage, isBlocking: false) {
            Issue.record("停止中には確認しない")
            return false
        }
        #expect(reply == .install)
    }

    @Test("SPEC-LCY-008 確認とダウンロードだけでは抑止の解除を確認しない",
          arguments: [SPUUserUpdateStage.notDownloaded, .downloaded])
    func doesNotInterceptDownload(stage: SPUUserUpdateStage) {
        let reply = UpdateInstallationReply.resolve(.install, stage: stage, isBlocking: true) {
            Issue.record("インストールの準備前には確認しない")
            return false
        }
        #expect(reply == .install)
    }

    @Test("SPEC-LCY-008 Install 以外の返答は変えない",
          arguments: [SPUUserUpdateChoice.skip, .dismiss],
          [SPUUserUpdateStage.notDownloaded, .downloaded, .installing])
    func passesOtherChoices(choice: SPUUserUpdateChoice, stage: SPUUserUpdateStage) {
        let reply = UpdateInstallationReply.resolve(choice, stage: stage, isBlocking: true) {
            Issue.record("Install 以外は確認しない")
            return true
        }
        #expect(reply == choice)
    }

    @Test("SPEC-LCY-008 準備完了画面の返答を Sparkle に渡す前に確認する")
    func interceptsReadyReply() {
        let standard = ReadyReplyDriver(hostBundle: .main, delegate: nil)
        var isBlocking = false
        var confirmations = 0
        let driver = InstallationUserDriver(standard: standard) { choice, stage, _ in
            #expect(stage == .installing)
            return UpdateInstallationReply.resolve(choice, stage: stage, isBlocking: isBlocking) {
                confirmations += 1
                return false
            }
        }
        var replies: [SPUUserUpdateChoice] = []
        driver.showReady { replies.append($0) }
        #expect(replies.isEmpty)
        #expect(confirmations == 0)
        // 表示した時点ではなく、利用者が返答する時点の抑止状態で決める。
        isBlocking = true
        standard.readyReply?(.install)
        standard.readyReply = nil
        #expect(replies == [.dismiss])
        #expect(confirmations == 1)
    }

    @Test("SPEC-SET-007 SPEC-MENU-009 取り消した版はセッション終了後も新しい版として示す")
    func keepsDismissedVersion() throws {
        let model = UpdateModel()
        model.updateInstallationConditions(isBlocking: true, settingsWindowIsOpen: true)
        #expect(model.installationReply(.install, stage: .installing, version: "1.2.0", confirm: { false }) == .dismiss)
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                 userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil), delegate: nil)
        model.standardUserDriverWillFinishUpdateSession()
        model.updater(updater, didFinishUpdateCycleFor: .updates, error: nil)
        model.updateInstallationConditions(isBlocking: false, settingsWindowIsOpen: false)
        #expect(model.pendingUpdateVersion == "1.2.0")
        #expect(model.pendingInstallationVersion == nil)
        #expect(SettingsUpdateState(isEnabled: true, lastChecked: nil,
                                    availableVersion: model.pendingUpdateVersion,
                                    installationVersion: model.pendingInstallationVersion) == .available("1.2.0"))
        let status = BlockingStatus(session: nil, batteryCondition: nil, misalignments: [:], isRecordUnsaved: false)
        let rows = try MenuContent.make(status: status, settings: Settings(), isOnACPower: false,
                                        hasInternalBattery: false, sleepRows: [],
                                        pendingUpdateVersion: model.pendingUpdateVersion,
                                        bundle: localizedAppBundle("ja"))
        let reminder = try #require(rows.first { $0.id == "menu.update.available" })
        #expect(reminder.subtitle == "バージョン1.2.0")
        #expect(reminder.command == .checkForUpdates)
        // 後の更新処理が失敗した場合は、古い知らせを残さない。
        model.updater(updater, didFinishUpdateCycleFor: .updates, error: NSError(domain: "test", code: 1))
        #expect(model.pendingUpdateVersion == nil)
    }

    @Test("SPEC-LCY-008 手動インストールでは再起動の延期を使わない")
    func manualInstallationDoesNotPostponeRelaunch() {
        let selector = NSSelectorFromString("updater:shouldPostponeRelaunchForUpdate:untilInvokingBlock:")
        #expect(!UpdateModel().responds(to: selector))
    }
}

@MainActor
private final class ReadyReplyDriver: SPUStandardUserDriver {
    var readyReply: ((SPUUserUpdateChoice) -> Void)?

    override func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        readyReply = reply
    }
}
