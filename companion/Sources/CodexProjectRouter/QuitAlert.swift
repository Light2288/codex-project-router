import AppKit
import CompanionCore

@MainActor enum QuitAlert {
    static func make(reason: RouterController.QuitBlockReason) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Cannot quit yet"
        switch reason {
        case .directConfirmationPending:
            alert.informativeText = "Direct-response confirmation is pending. Open Controls to complete the check."
        case .operationInProgress:
            alert.informativeText = "A router operation is still running or needs reconciliation. Open Controls to review its status."
        case .directRecoveryRequired:
            alert.informativeText = "Direct recovery is incomplete. Open Controls to restore the direct connection, then complete the manual restart and response check."
        case .contextUnavailable:
            alert.informativeText = "Quit could not be completed safely. Open Controls to review the current status and recovery guidance."
        }
        alert.addButton(withTitle: "Open Controls").keyEquivalent = "\r"
        alert.addButton(withTitle: "Keep Running").keyEquivalent = "\u{1b}"
        return alert
    }
}
