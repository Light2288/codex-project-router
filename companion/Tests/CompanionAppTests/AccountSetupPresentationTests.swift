import XCTest
import CompanionCore
@testable import CodexProjectRouter

@MainActor final class AccountSetupPresentationTests: XCTestCase {
    private let accountID = "11111111-1111-4111-8111-111111111111"
    private let secondID = "22222222-2222-4222-8222-222222222222"
    private let outgoing = CredentialReference(keychainPath: "/synthetic/outgoing.keychain-db", service: "outgoing", account: "account")
    private let incoming = CredentialReference(keychainPath: "/synthetic/incoming.keychain-db", service: "desktop", account: "caller")
    private func preview(source: String = "missing") -> SetupPreview {
        let direct = SetupPreview.Account(id: accountID, displayName: "Default", upstreamBaseUrl: "https://direct.example/v1", credential: source == "missing" ? nil : outgoing, sourceAlias: nil)
        return SetupPreview(context: .init(configPath: "/synthetic/config.json", codexHome: "/synthetic/codex", providerId: "provider", listenPort: 43123), configurationRevision: "synthetic", setupState: source == "accounts" ? "ready" : "migration_required", sourceKind: source, accounts: [direct], routeAccounts: ["legacy": nil], incomingCredential: source == "accounts" ? incoming : nil, defaultAccountId: source == "accounts" ? accountID : nil, incomingHint: nil, originalDirect: direct)
    }
    func testFirstAccountNeedsExplicitDefault() throws {
        // Selecting an outgoing item must never silently designate it as incoming or default.
        var form = AccountSetupForm(preview: preview(), intent: .add)
        form.accounts[0].credential = outgoing
        XCTAssertThrowsError(try form.change())
        form.incomingSelection = incoming; form.incomingConfirmed = true
        XCTAssertThrowsError(try form.change())
        form.defaultSelection = accountID
        guard case let .createConfiguration(account, selectedIncoming, selectedDefault) = try form.change() else { return XCTFail("Expected creation") }
        XCTAssertEqual(account.id, accountID)
        XCTAssertEqual(selectedIncoming, incoming)
        XCTAssertEqual(selectedDefault, accountID)
        var unconfirmed = form; unconfirmed.incomingConfirmed = false
        XCTAssertThrowsError(try unconfirmed.change())
        form.defaultSelection = AccountSetupForm.noDefault
        guard case let .createConfiguration(_, _, selectedDefault) = try form.change() else { return XCTFail("Expected creation") }
        XCTAssertNil(selectedDefault, "Explicit incomplete setup is allowed, but must stay incomplete")
    }
    func testAddingAccountPreservesDefaultAndAssignments() throws {
        let source = preview(source: "accounts")
        var form = AccountSetupForm(preview: source, intent: .add)
        form.accounts[0].displayName = "Work"
        form.accounts[0].upstreamBaseUrl = "HTTPS://WORK.EXAMPLE:443/api/"
        form.accounts[0].credential = outgoing
        guard case let .addAccount(account, incomingChange) = try form.change() else { return XCTFail("Add must not designate a default") }
        XCTAssertNotEqual(account.id, accountID)
        XCTAssertEqual(account.upstreamBaseUrl, "https://work.example/api")
        XCTAssertNil(incomingChange)
        XCTAssertEqual(source.defaultAccountId, accountID)
        XCTAssertTrue(form.defaultIsPreserved)
        var defaultForm = AccountSetupForm(preview: source, intent: .setDefault)
        XCTAssertThrowsError(try defaultForm.change(), "Opening a picker is not a selection")
        defaultForm.defaultSelection = AccountSetupForm.noDefault
        XCTAssertEqual(try defaultForm.change(), .setDefault(defaultAccountId: nil))
    }
    func testImportShowsPreservedAndUnresolvedBindings() throws {
        var source = preview(source: "enabled")
        source.accounts.append(.init(id: secondID, displayName: "Work", upstreamBaseUrl: "https://work.example/v1", credential: outgoing, sourceAlias: "work-route"))
        source.routeAccounts = ["legacy": nil, "work-route": secondID]
        let entries: [Inspection.Entry] = [
            .init(id: "known", name: "Known project", routeAlias: "work-route", routeState: "mapped"),
            .init(id: "gone", name: "", routeAlias: "legacy", routeState: "catalog_missing"),
            .init(id: "broken", name: "Broken project", routeAlias: "absent", routeState: "target_missing")
        ]
        let rows = AccountSetupForm.bindingPreview(source, entries: entries)
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows[0].contains("Known project")); XCTAssertTrue(rows[0].contains("Work"))
        XCTAssertTrue(rows[1].contains("gone")); XCTAssertTrue(rows[1].contains("Inherited label"))
        XCTAssertTrue(rows[2].contains("Missing target"))
        var form = AccountSetupForm(preview: source, intent: .importConfiguration)
        form.incomingSelection = incoming; form.incomingConfirmed = true; form.defaultSelection = secondID
        guard case let .migrate(accounts, _, id) = try form.change() else { return XCTFail("Expected migration") }
        XCTAssertEqual(accounts.map(\.id), [accountID, secondID]); XCTAssertEqual(id, secondID)
        XCTAssertEqual(accounts[1].credential, outgoing)
        form.accounts[1].upstreamBaseUrl = "https://changed.example"
        XCTAssertThrowsError(try form.change(), "Import cannot replace a saved target")
    }
    func testSetupRequiredKeepsCatalogAndRecovery() {
        let presentation = AccountSetupPresentation(state: .ready, routerCanSave: false, createdItem: false)
        XCTAssertFalse(presentation.canSave)
        XCTAssertTrue(presentation.guidance.contains("Stop")); XCTAssertTrue(presentation.guidance.contains("recovery"))
        XCTAssertEqual(AccountSetupForm.bindingPreview(preview(), entries: [.init(id: "a", name: "Visible", routeAlias: nil, routeState: "unmapped")]), [])
    }
    func testCreatedButUnlinkedStateDoesNotOfferBlindRetry() {
        for state in [AccountSetupController.State.uncertain, .recoveryRequired] {
            let presentation = AccountSetupPresentation(state: state, routerCanSave: true, createdItem: true)
            XCTAssertFalse(presentation.canSave)
            XCTAssertTrue(presentation.guidance.contains("Do not create"))
            XCTAssertTrue(presentation.guidance.contains("receipt"))
            XCTAssertEqual(presentation.canReconcile, state == .uncertain)
        }
    }
    func testConcealedEntryTransfersAndClearsOnEveryOutcome() throws {
        var entry = AccountSecretEntry(); entry.value = "SYNTHETIC_UI_SENTINEL"
        let secret = try entry.takeSecret()
        XCTAssertEqual(entry.value, ""); XCTAssertFalse(secret.isDiscarded)
        XCTAssertFalse(String(reflecting: secret).contains("SYNTHETIC_UI_SENTINEL")); secret.discard()
        entry.value = "SYNTHETIC_UI_SENTINEL bad"
        XCTAssertThrowsError(try entry.takeSecret()) { error in
            XCTAssertFalse(error.localizedDescription.contains("SYNTHETIC_UI_SENTINEL"))
        }
        XCTAssertEqual(entry.value, "")
        entry.value = "SYNTHETIC_UI_SENTINEL"; entry.clear(); XCTAssertEqual(entry.value, "")
    }
    func testExplicitCreationPathDoesNotDependOnDefaultKeychainDiscovery() throws {
        var form = AccountSetupForm(preview: preview(), intent: .add)
        try form.useNewCredential(for: accountID, keychainPath: "")
        XCTAssertEqual(form.nativeAccountID, accountID)
        XCTAssertEqual(form.accounts[0].credential?.keychainPath, "")
        // The destination field remains editable even if default-path discovery is unsupported.
        form.accounts[0].credential?.keychainPath = "/synthetic/owned-disposable.keychain-db"
        form.incomingSelection = incoming; form.incomingConfirmed = true; form.defaultSelection = accountID
        var entry = AccountSecretEntry(); entry.value = "SYNTHETIC_EXPLICIT"
        let submission = try form.prepareSave(entry: &entry)
        guard case let .createConfiguration(account, _, _) = submission.change else { return XCTFail("Expected creation") }
        XCTAssertEqual(account.credential.keychainPath, "/synthetic/owned-disposable.keychain-db")
        submission.secret?.discard()
        var migration = AccountSetupForm(preview: preview(source: "enabled"), intent: .importConfiguration)
        XCTAssertThrowsError(try migration.useNewCredential(for: accountID, keychainPath: "/synthetic/owned-disposable.keychain-db"), "Saved paired references cannot be replaced during import")
    }
    func testNativeSubmissionUsesExplicitKeychainAndClearsEntryBeforeAwait() throws {
        var form = AccountSetupForm(preview: preview(), intent: .add)
        form.accounts[0].credential = CredentialReference(keychainPath: "/synthetic/owned-disposable.keychain-db", service: "created", account: "new")
        form.nativeAccountID = accountID
        form.incomingSelection = incoming; form.incomingConfirmed = true; form.defaultSelection = accountID
        var entry = AccountSecretEntry(); entry.value = "SYNTHETIC_UI_SENTINEL"
        let submission = try form.prepareSave(entry: &entry)
        XCTAssertEqual(entry.value, ""); XCTAssertEqual(submission.accountID, accountID)
        guard case let .createConfiguration(account, selectedIncoming, _) = submission.change else { return XCTFail("Expected creation") }
        XCTAssertEqual(account.credential.keychainPath, "/synthetic/owned-disposable.keychain-db")
        XCTAssertEqual(selectedIncoming, incoming)
        XCTAssertNotNil(submission.secret); submission.secret?.discard()
        form.accounts[0].upstreamBaseUrl = "http://unsafe.example"; entry.value = "SYNTHETIC_UI_SENTINEL"
        XCTAssertThrowsError(try form.prepareSave(entry: &entry))
        XCTAssertEqual(entry.value, "")
    }
    func testInvalidCredentialReferenceIsExplainedBeforeNativeSubmission() throws {
        var form = AccountSetupForm(preview: preview(), intent: .add)
        form.accounts[0].credential = .init(keychainPath: "relative.keychain-db", service: "created", account: "new")
        form.incomingConfirmed = true; form.defaultSelection = accountID
        XCTAssertThrowsError(try form.change())
    }
    func testInvalidNameAndEndpointAreRejectedBeforeSecretTransfer() throws {
        var form = AccountSetupForm(preview: preview(), intent: .add)
        form.accounts[0].credential = outgoing; form.incomingConfirmed = true
        form.defaultSelection = accountID
        form.accounts[0].upstreamBaseUrl = "http://unsafe.example"
        XCTAssertThrowsError(try form.change())
        form.accounts[0].upstreamBaseUrl = "https://safe.example"
        form.accounts[0].displayName = "  "
        XCTAssertThrowsError(try form.change())
    }
}
