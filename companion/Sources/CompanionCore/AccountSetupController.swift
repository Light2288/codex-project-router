import Foundation
import Observation

@MainActor public protocol AccountSetupBackend: AnyObject {
    var setupHelperIsRunning: Bool { get }
    var uncertainSetupOperationID: String? { get }
    func previewSetup(configPath: URL, browseHome: URL) async throws -> SetupPreview
    func commitSetup(_ change: SetupChange, context: ActivationContext, revision: String, operationID: String) async throws -> SetupCommitResult
    func probeSetupPort(_ context: ActivationContext) async -> StopOutcome.PortState
    /// Called only after exact saved account/default evidence; implementations must verify helper exit and operation identity.
    func finishSetupReconciliation(operationID: String) throws
}

@MainActor @Observable public final class AccountSetupController {
    public enum State: Equatable { case idle, loading, ready, saving, uncertain, saved, recoveryRequired }
    public private(set) var state: State = .idle
    public private(set) var preview: SetupPreview?
    public private(set) var pendingReceipt: SetupReceipt?
    public private(set) var pendingOperationID: String?
    public private(set) var observedCreatedItem: CredentialReference?
    public private(set) var error: String?
    public var canDismiss: Bool { state != .saving && state != .uncertain }
    @ObservationIgnored private let router: RouterController
    @ObservationIgnored private let backend: any AccountSetupBackend
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let browseHome: URL
    private var generation: UInt64 = 0
    private var transaction: SetupTransactionStore?
    private var pending: Pending?
    private struct Pending {
        var operationID: String; var before: SetupPreview; var change: SetupChange
        var created: AccountRecord?; var helperAttempted = false
    }
    public init(router: RouterController, backend: any AccountSetupBackend, keychain: KeychainStore, browseHome: URL) {
        self.router = router; self.backend = backend; self.keychain = keychain; self.browseHome = browseHome
    }
    public func listCredentials(service: String? = nil, account: String? = nil, keychainPath: String? = nil) async throws -> KeychainMetadataListing {
        try await keychain.browseMetadata(service: service, account: account, keychainPath: keychainPath)
    }
    public func defaultKeychainPath() async throws -> String { try await keychain.defaultKeychainPath() }
    public func suggestedIncomingCredential() async throws -> CredentialReference? {
        guard let hint = preview?.incomingHint else { return nil }
        return try await keychain.lookup(service: hint.service, account: hint.account, keychainPath: hint.keychainPath)
    }
    public func refresh() async {
        guard state != .saving, state != .uncertain, let config = router.selectedConfiguration else { return }
        generation &+= 1; let request = generation; state = .loading; error = nil
        do {
            let evidence = SetupTransactionStore(configPath: config)
            let receipt = try evidence.load()
            pendingReceipt = receipt; pendingOperationID = receipt?.phase == .complete ? nil : receipt?.operationId
            observedCreatedItem = nil
            let lease = try evidence.inspectLease()
            // Interrupted creation is evidence, never authority to create, replay or remove a stale lease.
            if let receipt, receipt.phase != .complete {
                let found = try await keychain.lookup(reference: receipt.reference)
                guard generation == request, router.selectedConfiguration == config else { return }
                pendingReceipt = receipt; pendingOperationID = receipt.operationId; observedCreatedItem = found; state = .recoveryRequired
                error = "Account setup is incomplete. Review the saved receipt and resolve the activation lock manually before continuing."
                return
            }
            if lease != .absent {
                guard generation == request, router.selectedConfiguration == config else { return }
                if case let .setup(operationID) = lease { pendingOperationID = operationID }
                pendingReceipt = receipt; state = .recoveryRequired
                error = "An activation lock exists. Review the saved evidence and resolve the lock manually before continuing."
                return
            }
            let value = try await backend.previewSetup(configPath: config, browseHome: browseHome)
            guard generation == request, router.selectedConfiguration == config else { return }
            preview = value; pendingReceipt = receipt; pendingOperationID = nil; observedCreatedItem = nil; state = .ready
        } catch {
            guard generation == request, router.selectedConfiguration == config else { return }
            state = .recoveryRequired; self.error = safe(error)
        }
    }
    /// Form snapshots are comparison inputs only. Every save obtains fresh router authority under the shared lease.
    public func save(_ change: SetupChange, creatingCredentialFor accountID: String? = nil, secret: KeychainSecret? = nil) async {
        guard state == .ready || state == .saved, pending == nil, let form = preview else { secret?.discard(); return }
        generation &+= 1; state = .saving; error = nil
        var began = false, leased = false, prepared = false, helperAttempted = false
        var operationID: String?
        defer { secret?.discard(); if began { router.finishAccountSetup() } }
        do {
            let initial = try await router.beginAccountSetup(); began = true
            guard initial.context == form.context, initial.configurationRevision == form.configurationRevision else { throw CompanionError.mutationBusy }
            let normalized = try Self.validated(change, against: initial)
            let created = accountID.flatMap { id in Self.accounts(normalized).first { $0.id == id } }
            guard (secret == nil && accountID == nil) || (secret != nil && created != nil) else { throw CompanionError.protocolFailure }
            let op = UUID().uuidString; operationID = op
            let store = SetupTransactionStore(configPath: URL(fileURLWithPath: initial.context.configPath)); transaction = store
            try store.begin(context: initial.context, operationID: op, receipt: nil); leased = true
            // Missing-file preview must precede prepared intent: an unrelated receipt rightly rejects first setup.
            try await router.revalidateAccountSetup(initial)
            var previousAccount: AccountRecord?
            if let previous = try store.load() {
                previousAccount = initial.accounts.compactMap(Self.record).first { $0 == previous.account }
                guard previous.phase == .complete, previous.context == initial.context, previousAccount != nil else { throw CompanionError.privateState }
            }
            if let created, let secret {
                let receipt = SetupReceipt(operationId: op, account: created, context: initial.context)
                try store.prepare(receipt, verifiedPreviousAccount: previousAccount); prepared = true; pendingReceipt = receipt
                pending = Pending(operationID: op, before: initial, change: normalized, created: created)
                try await keychain.createGenericPassword(reference: created.credential, secret: secret)
                try store.advance(.itemCreated); pendingReceipt = try store.load(); observedCreatedItem = created.credential
            }
            try await router.revalidateAccountSetup(initial, includePreview: !prepared)
            try store.advance(.committing)
            pending = Pending(operationID: op, before: initial, change: normalized, created: created, helperAttempted: true)
            helperAttempted = true
            let result = try await backend.commitSetup(normalized, context: initial.context, revision: initial.configurationRevision, operationID: op)
            guard result.context == initial.context, result.operationId == op, result.changed else { throw CompanionError.protocolFailure }
            try await verifySaved(result: result)
        } catch {
            self.error = safe(error)
            if prepared || helperAttempted {
                if let pending { router.markAccountSetupUncertain(pending.operationID) }
                state = .uncertain
            } else {
                if leased || transaction?.hasOwnedLease == true {
                    do { try transaction?.cancelBeforeMutation() }
                    catch {
                        if let operationID { router.markAccountSetupUncertain(operationID) }
                        self.error = safe(error); state = .recoveryRequired; return
                    }
                }
                transaction = nil; pending = nil; state = .ready
            }
        }
    }
    public func reconcile() async {
        guard state == .uncertain, let pending, !backend.setupHelperIsRunning else { return }
        do {
            if !pending.helperAttempted {
                if let created = pending.created { observedCreatedItem = try await keychain.lookup(reference: created.credential) }
                pendingReceipt = try transaction?.load()
                state = .recoveryRequired
                error = "Account setup is incomplete. Review the saved receipt and resolve the activation lock manually before continuing."
                return
            }
            try await verifySaved(result: nil)
        } catch { self.error = safe(error) }
    }
    private func verifySaved(result: SetupCommitResult?) async throws {
        guard let pending, let transaction, !backend.setupHelperIsRunning else { throw CompanionError.mutationUncertain }
        let actual = try await backend.previewSetup(configPath: URL(fileURLWithPath: pending.before.context.configPath), browseHome: browseHome)
        guard actual.context == pending.before.context, Self.matches(actual, pending.change, before: pending.before),
              result == nil || (result!.configurationRevision == actual.configurationRevision && result!.setupState == actual.setupState) else { throw CompanionError.mutationUncertain }
        if let created = pending.created {
            guard let receipt = try transaction.load(), receipt.operationId == pending.operationID, receipt.account == created,
                  receipt.phase == .committing, try await keychain.lookup(reference: created.credential) == created.credential else { throw CompanionError.mutationUncertain }
        }
        if backend.uncertainSetupOperationID != nil { try backend.finishSetupReconciliation(operationID: pending.operationID) }
        try transaction.advance(.complete); try transaction.finishVerified()
        pendingReceipt = try transaction.load(); preview = actual; self.pending = nil; self.transaction = nil
        pendingOperationID = nil; state = .saved; error = nil
        router.completeAccountSetup(operationID: pending.operationID)
        await router.refreshAndWait()
    }
    private func safe(_ error: Error) -> String {
        if let value = error as? CompanionError { return value.rawValue }
        if let value = error as? AccountValidationError { return value.localizedDescription }
        if let value = error as? KeychainError { return value.localizedDescription }
        return CompanionError.commandFailed.rawValue
    }
    private static func record(_ a: SetupPreview.Account) -> AccountRecord? {
        guard let credential = a.credential else { return nil }
        return AccountRecord(id: a.id, displayName: a.displayName, upstreamBaseUrl: a.upstreamBaseUrl, credential: credential)
    }
    private static func accounts(_ change: SetupChange) -> [AccountRecord] {
        switch change { case let .createConfiguration(a, _, _), let .addAccount(a, _): return [a]; case let .migrate(a, _, _): return a; case .setDefault: return [] }
    }
    private static func validated(_ change: SetupChange, against p: SetupPreview) throws -> SetupChange {
        func normalized(_ a: AccountRecord) throws -> AccountRecord {
            var a = a; a.upstreamBaseUrl = try AccountRecord.normalizedUpstreamBaseURL(a.upstreamBaseUrl)
            guard a.isValid else { throw CompanionError.protocolFailure }; return a
        }
        let result: SetupChange
        switch change {
        case let .createConfiguration(a, incoming, id):
            guard p.sourceKind == "missing" else { throw CompanionError.protocolFailure }
            result = .createConfiguration(account: try normalized(a), incomingCredential: incoming, defaultAccountId: id)
        case let .migrate(a, incoming, id):
            guard ["legacy", "enabled"].contains(p.sourceKind), Set(a.map(\.id)) == Set(p.accounts.map(\.id)) else { throw CompanionError.protocolFailure }
            let a = try a.map(normalized)
            for candidate in p.accounts {
                guard let chosen = a.first(where: { $0.id == candidate.id }), chosen.upstreamBaseUrl == candidate.upstreamBaseUrl,
                      candidate.credential == nil || chosen.credential == candidate.credential else { throw CompanionError.protocolFailure }
            }
            result = .migrate(accounts: a, incomingCredential: incoming, defaultAccountId: id)
        case let .addAccount(a, incoming):
            guard p.sourceKind == "accounts", !p.accounts.contains(where: { $0.id == a.id }) else { throw CompanionError.protocolFailure }
            result = .addAccount(account: try normalized(a), incomingCredential: incoming)
        case let .setDefault(id, incoming):
            guard p.sourceKind == "accounts" else { throw CompanionError.protocolFailure }
            result = .setDefault(defaultAccountId: id, incomingCredential: incoming)
        }
        let expected = projection(result, before: p)
        let records = expected.accounts.compactMap(record)
        guard records.count == expected.accounts.count, records.allSatisfy(\.isValid), Set(records.map(\.id)).count == records.count,
              Set(records.map { $0.displayName.lowercased() }).count == records.count,
              expected.defaultAccountId == nil || records.contains(where: { $0.id == expected.defaultAccountId }),
              expected.incomingCredential == nil || expected.incomingCredential!.isValid else { throw CompanionError.protocolFailure }
        switch result {
        case let .addAccount(_, incoming), let .setDefault(_, incoming):
            guard incoming == nil || p.incomingCredential == nil || incoming == p.incomingCredential else { throw CompanionError.protocolFailure }
        default: break
        }
        return result
    }
    private static func projection(_ change: SetupChange, before: SetupPreview) -> SetupPreview {
        var p = before
        func preview(_ a: AccountRecord) -> SetupPreview.Account { .init(id: a.id, displayName: a.displayName, upstreamBaseUrl: a.upstreamBaseUrl, credential: a.credential, sourceAlias: nil) }
        switch change {
        case let .createConfiguration(a, incoming, id): p.accounts = [preview(a)]; p.incomingCredential = incoming; p.defaultAccountId = id
        case let .migrate(a, incoming, id): p.accounts = a.map(preview); p.incomingCredential = incoming; p.defaultAccountId = id
        case let .addAccount(a, incoming): p.accounts.append(preview(a)); if let incoming { p.incomingCredential = incoming }
        case let .setDefault(id, incoming): p.defaultAccountId = id; if let incoming { p.incomingCredential = incoming }
        }
        return p
    }
    private static func matches(_ actual: SetupPreview, _ change: SetupChange, before: SetupPreview) -> Bool {
        let p = projection(change, before: before)
        return actual.setupState == (p.incomingCredential != nil && p.defaultAccountId != nil && !p.accounts.isEmpty ? "ready" : "required") && actual.sourceKind == "accounts" && Set(actual.accounts.map(\.id)).count == actual.accounts.count &&
            actual.accounts.compactMap(record).sorted { $0.id < $1.id } == p.accounts.compactMap(record).sorted { $0.id < $1.id } &&
            actual.accounts.count == p.accounts.count && actual.defaultAccountId == p.defaultAccountId &&
            actual.incomingCredential == p.incomingCredential && actual.routeAccounts == p.routeAccounts
    }
}
