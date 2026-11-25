import Foundation
import Sparkle

enum UpdateInstallationReply {
    static func resolve(_ choice: SPUUserUpdateChoice, stage: SPUUserUpdateStage, isBlocking: Bool,
                        confirm: () -> Bool) -> SPUUserUpdateChoice
    {
        guard choice == .install, stage == .installing, isBlocking else { return choice }
        return confirm() ? .install : .dismiss
    }
}

@MainActor
final class InstallationUserDriver: NSObject, SPUUserDriver {
    private let standard: SPUStandardUserDriver
    private let installationReply: (SPUUserUpdateChoice, SPUUserUpdateStage, String) -> SPUUserUpdateChoice
    private var updateVersion = ""

    init(standard: SPUStandardUserDriver,
         installationReply: @escaping (SPUUserUpdateChoice, SPUUserUpdateStage, String) -> SPUUserUpdateChoice)
    {
        self.standard = standard
        self.installationReply = installationReply
        super.init()
    }

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        standard.show(request, reply: reply)
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        standard.showUserInitiatedUpdateCheck(cancellation: cancellation)
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                         reply: @escaping (SPUUserUpdateChoice) -> Void)
    {
        updateVersion = appcastItem.displayVersionString
        standard.showUpdateFound(with: appcastItem, state: state) { [self] choice in
            reply(installationReply(choice, state.stage, appcastItem.displayVersionString))
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        standard.showUpdateReleaseNotes(with: downloadData)
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        standard.showUpdateReleaseNotesFailedToDownloadWithError(error)
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        standard.showUpdateNotFoundWithError(error, acknowledgement: acknowledgement)
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        standard.showUpdaterError(error, acknowledgement: acknowledgement)
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        standard.showDownloadInitiated(cancellation: cancellation)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        standard.showDownloadDidReceiveExpectedContentLength(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        standard.showDownloadDidReceiveData(ofLength: length)
    }

    func showDownloadDidStartExtractingUpdate() {
        standard.showDownloadDidStartExtractingUpdate()
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        standard.showExtractionReceivedProgress(progress)
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        standard.showReady { [self] choice in
            reply(installationReply(choice, .installing, updateVersion))
        }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool,
                              retryTerminatingApplication: @escaping () -> Void)
    {
        standard.showInstallingUpdate(withApplicationTerminated: applicationTerminated,
                                      retryTerminatingApplication: retryTerminatingApplication)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        standard.showUpdateInstalledAndRelaunched(relaunched, acknowledgement: acknowledgement)
    }

    func dismissUpdateInstallation() {
        standard.dismissUpdateInstallation()
    }

    func showUpdateInFocus() {
        standard.showUpdateInFocus()
    }
}
