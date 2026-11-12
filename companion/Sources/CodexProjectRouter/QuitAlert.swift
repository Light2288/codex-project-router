import AppKit
import CompanionCore

@MainActor enum QuitAlert {
    static func make(reason: RouterController.QuitBlockReason, ownsRouter: Bool) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Cannot quit yet"
        switch reason {
        case .directConfirmationPending:
            alert.informativeText = ownsRouter
                ? "Codex may still need the router. Check the direct connection before quitting."
                : "Quit needs a fresh check of the saved recovery information. Review the status, then try Quit again."
        case .operationInProgress:
            alert.informativeText = "A router operation is running or needs checking. Review its status before quitting."
        case .directRecoveryRequired:
            alert.informativeText = "The app still needs to restore the direct connection before it can quit."
        case .contextUnavailable:
            alert.informativeText = "The app cannot check that quitting is safe. Review its status and recovery instructions."
        }
        alert.addButton(withTitle: "Show steps to quit").keyEquivalent = "\r"
        alert.addButton(withTitle: "Keep Running").keyEquivalent = "\u{1b}"
        return alert
    }
}
