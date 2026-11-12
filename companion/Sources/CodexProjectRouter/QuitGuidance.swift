import CompanionCore

@MainActor struct QuitGuidance: Equatable {
    enum Destination: Hashable { case status, restoreDirect, directResponse, manualRecovery, stopRouter, setup }
    let destination: Destination
    let text: String

    static func current(for controller: RouterController) -> QuitGuidance {
        let reason = controller.quitBlockReason
        // Live uncertainty can be newer than cached permission; safe Stop can outgrow the generic fallback reason.
        if reason == .operationInProgress {
            return .init(destination: .status, text: "Click Refresh to check the operation. Wait while it is running; use the recovery instructions if it cannot finish.")
        }
        if controller.canQuit {
            return .init(destination: .status, text: "The previous blocker has cleared. Choose Quit again.")
        }
        if controller.canStop {
            return .init(destination: .stopRouter, text: "Choose Quit again to recheck and close the app, or use Stop owned router first.")
        }
        if reason != .contextUnavailable {
            if reason == .directRecoveryRequired, controller.canRestoreDirect {
                return .init(destination: .restoreDirect, text: controller.ownedRouter != nil
                    ? "Click Restore direct. Keep the router running while you restart Codex and verify a reply; then confirm the direct response below and choose Quit again."
                    : "Click Restore direct, then choose Quit again. Quit will check the saved settings and recovery information.")
            }
            if controller.canConfirmDirectResponse {
                if controller.ownedRouter != nil {
                    return .init(destination: .directResponse, text: "Quit and reopen Codex, then send a message. After a working reply, click the direct-response confirmation below and choose Quit again. Keep the router running until then.")
                }
                return .init(destination: .status, text: "Choose Quit again to check the saved recovery information. A pending response check can stay saved while this idle app is closed.")
            }
        }
        let destination: Destination
        if controller.recoveryContext ?? controller.inspection?.context != nil { destination = .manualRecovery }
        else if controller.inspection?.configuration.state != "valid" { destination = .setup }
        else { destination = .status }
        return .init(destination: destination, text: "Click Refresh and review any recovery instructions shown. Choose Quit again after the problem is resolved.")
    }
}
