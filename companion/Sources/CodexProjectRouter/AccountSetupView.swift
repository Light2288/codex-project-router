import SwiftUI
import CompanionCore

struct AccountSecretEntry {
    var value = ""
    mutating func takeSecret() throws -> KeychainSecret {
        defer { clear() }
        return try KeychainSecret(value)
    }
    mutating func clear() { value = "" }
}

enum AccountSetupIntent: String, Identifiable {
    case add, importConfiguration, setDefault
    var id: String { rawValue }
}

enum AccountFormError: Error, LocalizedError {
    case name, credential, incoming, defaultChoice, changedImport
    var errorDescription: String? {
        switch self {
        case .name: return "Use a unique account name of 1–80 characters, without leading/trailing whitespace or control characters."
        case .credential: return "Select an exact existing item, or enter a new key and choose its Keychain."
        case .incoming: return "Confirm the incoming credential choice separately in Advanced."
        case .defaultChoice: return "Choose a default explicitly, or choose to leave setup incomplete."
        case .changedImport: return "Import must preserve any saved incoming verifier and every saved account endpoint and credential reference. Refresh the preview."
        }
    }
}

/// Non-secret form data only; the controller revalidates this against fresh source evidence.
struct AccountSetupForm {
    static let noDefault = "no-default"
    let preview: SetupPreview
    let intent: AccountSetupIntent
    var accounts: [SetupPreview.Account]
    var defaultSelection = ""
    var incomingSelection: CredentialReference?
    var incomingConfirmed = false
    var nativeAccountID: String?
    var defaultIsPreserved: Bool { preview.sourceKind == "accounts" && intent == .add }
    var isImport: Bool { ["legacy", "enabled"].contains(preview.sourceKind) }
    var needsIncomingChoice: Bool { preview.incomingCredential == nil }
    var offersDefaultChoice: Bool { !defaultIsPreserved }
    var selectableCredentialAccounts: [SetupPreview.Account] {
        accounts.filter { $0.id != nativeAccountID && (preview.sourceKind == "missing" || !isImport && intent == .add || $0.credential == nil) }
    }
    var title: String {
        if preview.sourceKind == "missing" { return "Create account configuration" }
        if isImport { return "Import account configuration" }
        return intent == .setDefault ? "Choose default account" : "Add account"
    }
    init(preview: SetupPreview, intent: AccountSetupIntent) {
        self.preview = preview; self.intent = intent
        incomingSelection = preview.incomingCredential
        if preview.sourceKind == "missing" { accounts = [preview.originalDirect] }
        else if ["legacy", "enabled"].contains(preview.sourceKind) { accounts = preview.accounts }
        else if intent == .setDefault { accounts = preview.accounts }
        else {
            accounts = [.init(id: UUID().uuidString, displayName: "", upstreamBaseUrl: "", credential: nil, sourceAlias: nil)]
        }
    }
    func change() throws -> SetupChange {
        if preview.sourceKind == "enabled" {
            guard let preserved = preview.incomingCredential, incomingSelection == preserved else { throw AccountFormError.changedImport }
        }
        if needsIncomingChoice && !incomingConfirmed { throw AccountFormError.incoming }
        let incoming = needsIncomingChoice ? incomingSelection : nil
        if let incoming, !Self.validReference(incoming) { throw AccountFormError.credential }
        let defaultID: String?
        if offersDefaultChoice {
            guard defaultSelection == Self.noDefault || accounts.contains(where: { $0.id == defaultSelection }) else { throw AccountFormError.defaultChoice }
            defaultID = defaultSelection == Self.noDefault ? nil : defaultSelection
        } else { defaultID = preview.defaultAccountId }
        if preview.sourceKind == "accounts", intent == .setDefault {
            return .setDefault(defaultAccountId: defaultID, incomingCredential: incoming)
        }
        var names = Set(preview.sourceKind == "accounts" ? preview.accounts.map { $0.displayName.lowercased() } : [])
        let records = try accounts.map { draft -> AccountRecord in
            let name = draft.displayName
            guard !name.isEmpty, name.unicodeScalars.count <= 80,
                  name == name.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  names.insert(name.lowercased()).inserted else { throw AccountFormError.name }
            guard let credential = draft.credential, Self.validReference(credential) else { throw AccountFormError.credential }
            let url = try AccountRecord.normalizedUpstreamBaseURL(draft.upstreamBaseUrl)
            if isImport {
                guard let original = preview.accounts.first(where: { $0.id == draft.id }), original.upstreamBaseUrl == url,
                      original.credential == nil || original.credential == credential else { throw AccountFormError.changedImport }
            }
            return AccountRecord(id: draft.id, displayName: name, upstreamBaseUrl: url, credential: credential)
        }
        if preview.sourceKind == "missing", let account = records.first {
            return .createConfiguration(account: account, incomingCredential: incomingSelection, defaultAccountId: defaultID)
        }
        if isImport {
            guard Set(records.map(\.id)) == Set(preview.accounts.map(\.id)) else { throw AccountFormError.changedImport }
            return .migrate(accounts: records, incomingCredential: incomingSelection, defaultAccountId: defaultID)
        }
        guard let account = records.first else { throw AccountFormError.credential }
        return .addAccount(account: account, incomingCredential: incoming)
    }
    mutating func useNewCredential(for accountID: String, keychainPath: String) throws {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }),
              nativeAccountID == nil || nativeAccountID == accountID,
              !isImport || preview.accounts.first(where: { $0.id == accountID })?.credential == nil else { throw AccountFormError.credential }
        accounts[index].credential = .init(keychainPath: keychainPath, service: "codex-project-router", account: "account-\(accountID)")
        nativeAccountID = accountID
    }
    private static func validReference(_ reference: CredentialReference) -> Bool {
        reference.keychainPath.hasPrefix("/") && [reference.keychainPath, reference.service, reference.account].allSatisfy {
            !$0.isEmpty && $0.utf16.count <= 1024 && !$0.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        }
    }
    func prepareSave(entry: inout AccountSecretEntry) throws -> (change: SetupChange, accountID: String?, secret: KeychainSecret?) {
        defer { entry.clear() }
        let change = try change()
        return (change, nativeAccountID, nativeAccountID == nil ? nil : try entry.takeSecret())
    }
    static func bindingPreview(_ preview: SetupPreview, entries: [Inspection.Entry]) -> [String] {
        entries.compactMap { entry in
            guard let alias = entry.routeAlias else { return nil }
            let name = entry.name.isEmpty ? "Unresolved project \(entry.id)" : entry.name
            guard let target = preview.routeAccounts[alias] else { return "\(name) — Missing target; alias: \(alias)" }
            guard let target else { return "\(name) — Inherited label: \(alias)" }
            guard let account = preview.accounts.first(where: { $0.id == target }) else { return "\(name) — Missing target; alias: \(alias)" }
            return "\(name) — \(account.displayName); alias: \(alias)"
        }
    }
}

struct AccountSetupPresentation {
    let state: AccountSetupController.State
    let routerCanSave: Bool
    let createdItem: Bool
    var canSave: Bool { state == .ready && routerCanSave }
    var canReconcile: Bool { state == .uncertain }
    var guidance: String {
        if state == .uncertain || state == .recoveryRequired {
            if createdItem { return "A Keychain item may exist without a linked configuration. Do not create it again. Keep the receipt and activation lock; check the outcome, then follow manual recovery guidance." }
            return "Setup needs recovery or an operation outcome check. Do not create another item or retry Save. Preserve the receipt and activation lock; verify the helper has finished before any manual lock resolution."
        }
        if state == .saving { return "Keep this app open while Keychain consent and configuration saving finish. Creation cannot be undone by closing this form." }
        if state == .saved { return "Configuration saved; credential access and upstream responses remain unverified. The next explicit Start loads these settings with project routing Off. Start and provider activation are separate actions." }
        if !routerCanSave { return "Browsing is read-only. Complete direct recovery and Stop the owned router before saving. Resolve any external listener, pending operation or lock first. Routing Off alone does not permit saving." }
        return "Saving changes the private router configuration only. Credential access and upstream responses remain unverified. The next explicit Start uses these settings with project routing Off."
    }
}

struct AccountMetadataLookupPresentation {
    enum State { case notStarted, inProgress, completed(matches: Int, omittedItems: Int), failed }
    var state: State = .notStarted
    var exactKeychain = false
    var serviceFiltered = false
    var accountFiltered = false
    var message: String {
        var outcome: String
        switch state {
        case .notStarted: return "No metadata lookup yet."
        case .inProgress: outcome = "Metadata lookup started; waiting for the result."
        case .completed(let count, let omitted):
            outcome = "Metadata lookup completed: \(count) \(count == 1 ? "match" : "matches")."
            if omitted > 0 {
                outcome += "\n\(omitted) unsupported \(omitted == 1 ? "item" : "items") omitted because service/account metadata cannot form a usable reference."
            }
        case .failed: outcome = "Metadata lookup failed. Review the error below."
        }
        let keychain = exactKeychain ? "exact Keychain" : "user search list"
        let service = serviceFiltered ? "service filter supplied" : "any service"
        let account = accountFiltered ? "account filter supplied" : "any account"
        return "\(outcome)\nScope: \(keychain); \(service); \(account)."
    }
}

@MainActor struct AccountSetupView: View {
    let router: RouterController
    let setup: AccountSetupController
    let intent: AccountSetupIntent
    @Environment(\.dismiss) private var dismiss
    @State private var form: AccountSetupForm?
    @State private var secret = AccountSecretEntry()
    @State private var advancedExpanded = false
    @State private var localError: String?
    @State private var metadata: [CredentialReference] = []
    @State private var selectedMetadata: CredentialReference?
    @State private var serviceFilter = ""
    @State private var accountFilter = ""
    @State private var keychainFilter = ""
    @State private var metadataBusy = false
    @State private var metadataLookup = AccountMetadataLookupPresentation()
    @State private var metadataTarget = "incoming"
    private var display: AccountSetupPresentation {
        .init(state: setup.state, routerCanSave: router.canBeginAccountSetup, createdItem: setup.observedCreatedItem != nil || setup.pendingReceipt?.phase == .itemCreated || setup.pendingReceipt?.phase == .committing)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(form?.title ?? "Account setup").font(.title2.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(display.guidance).foregroundStyle(display.canSave || setup.state == .saved ? Color.secondary : Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    if setup.state == .loading { ProgressView("Reading configuration preview…") }
                    if let form, setup.state == .ready {
                        formContents(form)
                    }
                    if let error = localError ?? setup.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                    if display.canReconcile { Button("Check operation outcome") { Task { await setup.reconcile() } } }
                    if setup.state == .recoveryRequired || setup.state == .uncertain {
                        recoveryEvidence
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button(setup.state == .saved ? "Done" : "Close") { secret.clear(); dismiss() }
                    .keyboardShortcut(.cancelAction).disabled(!setup.canDismiss)
                Spacer()
                if setup.state == .saving { ProgressView().controlSize(.small) }
                if setup.state == .ready {
                    Button(form?.isImport == true ? "Import configuration" : "Save configuration") { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!display.canSave || metadataBusy || form == nil)
                }
            }
        }
        .padding(20).frame(width: 650, height: 690)
        .interactiveDismissDisabled(!setup.canDismiss)
        .task { await reload() }
        .onChange(of: setup.state) { _, state in
            if state != .ready { secret.clear() }
        }
        .onDisappear { secret.clear() }
    }
    @ViewBuilder private func formContents(_ current: AccountSetupForm) -> some View {
        if current.isImport {
            Text("Import preserves project bindings, saved endpoints and paired references. Legacy aliases remain inherited labels. No project assignments are edited here.").font(.callout)
            GroupBox("Preserved and unresolved bindings") {
                VStack(alignment: .leading, spacing: 5) {
                    let rows = AccountSetupForm.bindingPreview(current.preview, entries: router.inspection?.catalog.entries ?? [])
                    if rows.isEmpty { Text("No saved project bindings in the available catalog.") }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in Text(row).font(.caption) }
                    if router.inspection?.catalog.state != "ready" { Text("Catalog unavailable; the writer preserves saved bindings from the source.").foregroundStyle(.orange) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        if current.intent != .setDefault || current.preview.sourceKind != "accounts" {
            ForEach(Array(current.accounts.enumerated()), id: \.element.id) { index, account in
                accountFields(index: index, account: account, current: current)
            }
        }
        if current.offersDefaultChoice {
            Picker("Default account", selection: formBinding(\.defaultSelection, fallback: "")) {
                Text("Choose explicitly…").tag("")
                Text("No default — leave setup incomplete").tag(AccountSetupForm.noDefault)
                ForEach(current.accounts, id: \.id) { account in
                    Text(account.displayName.isEmpty ? "Unnamed account" : account.displayName).tag(account.id)
                }
            }
            Text("Default selection is independent of the incoming credential. No default means routing remains unavailable.").font(.caption).foregroundStyle(.secondary)
        } else {
            let name = current.preview.accounts.first(where: { $0.id == current.preview.defaultAccountId })?.displayName
            Text("Default preserved: \(name ?? "None designated")").font(.headline)
            Text("Adding an account never changes the default. Use Choose default after saving, including for the first account.").font(.caption).foregroundStyle(.secondary)
        }
        DisclosureGroup("Advanced — credential selection and full details", isExpanded: $advancedExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                if current.needsIncomingChoice {
                    Text("Incoming desktop credential").font(.headline)
                    Text("Select the exact existing item used by this provider's desktop authentication. Outgoing account selection does not choose it. Metadata does not prove accessibility.").font(.caption)
                    if let incoming = current.incomingSelection { referenceDetails(incoming) }
                    else { Text("No incoming item selected — setup will remain incomplete.").foregroundStyle(.orange) }
                    HStack {
                        Button("Choose incoming item…") { metadataTarget = "incoming"; localError = nil }
                        Button("Find provider suggestion") { suggestIncoming() }.disabled(metadataBusy)
                        Button("Leave incoming unset") { form?.incomingSelection = nil; form?.incomingConfirmed = false }
                    }
                    Toggle("I confirm this incoming choice separately", isOn: formBinding(\.incomingConfirmed, fallback: false))
                } else if let incoming = current.preview.incomingCredential {
                    Text("Incoming desktop credential (preserved)").font(.headline)
                    Text("The saved incoming verifier is retained. Desktop authentication is unchanged; credential access remains unverified.").font(.caption)
                    referenceDetails(incoming)
                }
                if current.needsIncomingChoice || !current.selectableCredentialAccounts.isEmpty {
                    metadataSelector(current)
                }
                if let nativeID = current.nativeAccountID, let index = current.accounts.firstIndex(where: { $0.id == nativeID }) {
                    Text("New item's destination Keychain").font(.headline)
                    TextField("Destination file-backed Keychain path", text: Binding(
                        get: { form?.accounts[index].credential?.keychainPath ?? "" },
                        set: { form?.accounts[index].credential?.keychainPath = $0 }))
                        .textFieldStyle(.roundedBorder)
                    Text("The default Keychain path is a suggestion. Enter an exact supported file-backed path to use a different Keychain; this form does not change the search list or default Keychain.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(current.accounts, id: \.id) { account in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.displayName.isEmpty ? "Unnamed account" : account.displayName).font(.headline)
                        Text(account.upstreamBaseUrl).font(.caption.monospaced()).textSelection(.enabled)
                        if let credential = account.credential { referenceDetails(credential) }
                        if let alias = account.sourceAlias { Text("Saved alias: \(alias)").font(.caption) }
                    }
                }
                Text("Configuration: \(current.preview.context.configPath)").font(.caption.monospaced()).textSelection(.enabled)
                Text("Original direct connection: \(current.preview.originalDirect.upstreamBaseUrl)").font(.caption.monospaced()).textSelection(.enabled)
                Text("Restore direct uses that preserved connection, which may differ from the default.").font(.caption)
            }.padding(.top, 8)
        }
        if current.needsIncomingChoice && !current.incomingConfirmed {
            Text("Confirm the incoming credential separately in Advanced before saving.").font(.caption).foregroundStyle(.orange)
        }
    }
    private func accountFields(index: Int, account: SetupPreview.Account, current: AccountSetupForm) -> some View {
        GroupBox(current.isImport ? "Imported account" : "Account") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Account display name", text: accountBinding(index, \.displayName)).textFieldStyle(.roundedBorder)
                if current.isImport {
                    Text("Saved endpoint preserved. Full prefix and item reference are in Advanced.").font(.caption)
                } else {
                    TextField("HTTPS endpoint, including API prefix", text: accountBinding(index, \.upstreamBaseUrl)).textFieldStyle(.roundedBorder)
                }
                if current.nativeAccountID == account.id {
                    SecureField("New account API key", text: $secret.value).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("New account API key, concealed")
                    Text("The key is passed directly to native Keychain creation. No reveal control is provided.").font(.caption).foregroundStyle(.secondary)
                    Button("Use existing item instead") {
                        secret.clear(); form?.nativeAccountID = nil; form?.accounts[index].credential = nil
                        metadataTarget = account.id; advancedExpanded = true
                    }
                } else {
                    Text(account.credential == nil ? "No outgoing credential selected" : "Existing outgoing reference selected; access unverified.").font(.caption)
                    if !current.isImport || account.credential == nil {
                        HStack {
                            Button("Choose existing item…") { metadataTarget = account.id; advancedExpanded = true }
                            Button("Enter new key…") { prepareNative(index) }.disabled(current.nativeAccountID != nil || metadataBusy)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func metadataSelector(_ current: AccountSetupForm) -> some View {
        GroupBox("Existing Keychain item — metadata only") {
            VStack(alignment: .leading, spacing: 7) {
                Picker("Use selected item for", selection: $metadataTarget) {
                    if current.needsIncomingChoice { Text("Incoming desktop credential").tag("incoming") }
                    Text("Choose a destination…").tag("")
                    ForEach(current.selectableCredentialAccounts, id: \.id) { account in Text(account.displayName.isEmpty ? "Outgoing account" : account.displayName).tag(account.id) }
                }
                TextField("Service filter (optional)", text: $serviceFilter)
                    .accessibilityIdentifier("keychain-service-filter")
                TextField("Account filter (optional)", text: $accountFilter)
                    .accessibilityIdentifier("keychain-account-filter")
                TextField("Exact file-backed Keychain path (optional)", text: $keychainFilter)
                    .accessibilityIdentifier("keychain-path-filter")
                Button("List matching item metadata") { listMetadata() }.disabled(metadataBusy)
                    .accessibilityIdentifier("keychain-lookup")
                Text(metadataLookup.message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("keychain-lookup-status")
                Text("Entries supplied to Matching item: \(metadata.count)").font(.caption).foregroundStyle(.secondary)
                if metadataBusy { ProgressView().controlSize(.small) }
                Picker("Matching item", selection: $selectedMetadata) {
                    Text("Select an exact item…").tag(Optional<CredentialReference>.none)
                    ForEach(metadata, id: \.self) { item in
                        Text("\(item.service) / \(item.account) — \(item.keychainPath)").tag(Optional(item))
                    }
                }
                .accessibilityIdentifier("keychain-matching-item")
                Button("Use this reference") { useMetadata(current) }.disabled(selectedMetadata == nil || metadataBusy)
                    .accessibilityIdentifier("keychain-use-reference")
                Text("Only generic-password metadata is listed. Selection does not test password access, provider acceptance or billing.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var recoveryEvidence: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let receipt = setup.pendingReceipt {
                Text("Saved operation: \(receipt.operationId)").textSelection(.enabled)
                Text("Account: \(receipt.account.displayName); receipt phase: \(receipt.phase.rawValue)")
                DisclosureGroup("Advanced — saved reference and recovery paths") {
                    referenceDetails(receipt.reference)
                    Text(receipt.account.upstreamBaseUrl).textSelection(.enabled)
                    Text(URL(fileURLWithPath: receipt.context.configPath).deletingLastPathComponent().appendingPathComponent("account-setup.json").path).textSelection(.enabled)
                    Text(URL(fileURLWithPath: receipt.context.configPath).deletingLastPathComponent().appendingPathComponent(".activation.lock").path).textSelection(.enabled)
                }
            }
            Text("Preserve the checkpoint and original direct recovery files. Verify the recorded helper has exited before resolving a lock manually. This form cannot delete an unlinked item, replay a save, or infer that native creation was rolled back.").font(.caption)
        }.font(.caption)
    }
    private func referenceDetails(_ reference: CredentialReference) -> some View {
        Text("Keychain: \(reference.keychainPath)\nService: \(reference.service)\nAccount: \(reference.account)")
            .font(.caption.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
    }
    private func formBinding<T>(_ key: WritableKeyPath<AccountSetupForm, T>, fallback: T) -> Binding<T> {
        Binding(get: { form?[keyPath: key] ?? fallback }, set: { form?[keyPath: key] = $0 })
    }
    private func accountBinding(_ index: Int, _ key: WritableKeyPath<SetupPreview.Account, String>) -> Binding<String> {
        Binding(get: { form?.accounts[index][keyPath: key] ?? "" }, set: { form?.accounts[index][keyPath: key] = $0 })
    }
    private func reload() async {
        secret.clear(); localError = nil
        await setup.refresh()
        if let preview = setup.preview, setup.state == .ready {
            form = AccountSetupForm(preview: preview, intent: intent)
            metadataTarget = form?.needsIncomingChoice == true ? "incoming" : form?.accounts.first?.id ?? "incoming"
        }
    }
    private func listMetadata() {
        metadataBusy = true; localError = nil; selectedMetadata = nil; metadata = []
        let service = serviceFilter.isEmpty ? nil : serviceFilter, account = accountFilter.isEmpty ? nil : accountFilter, path = keychainFilter.isEmpty ? nil : keychainFilter
        metadataLookup = .init(state: .inProgress, exactKeychain: path != nil, serviceFiltered: service != nil, accountFiltered: account != nil)
        Task {
            defer { metadataBusy = false }
            do {
                let found = try await setup.listCredentials(service: service, account: account, keychainPath: path)
                metadata = found.references
                metadataLookup.state = .completed(matches: found.references.count, omittedItems: found.omittedItemCount)
            } catch {
                metadataLookup.state = .failed
                localError = safe(error)
            }
        }
    }
    private func useMetadata(_ current: AccountSetupForm) {
        guard let selectedMetadata else { return }
        if metadataTarget == "incoming", current.needsIncomingChoice {
            form?.incomingSelection = selectedMetadata; form?.incomingConfirmed = false
        } else if let index = current.accounts.firstIndex(where: { $0.id == metadataTarget }),
                  current.nativeAccountID != metadataTarget,
                  !current.isImport || current.preview.accounts[index].credential == nil {
            form?.accounts[index].credential = selectedMetadata
        }
    }
    private func suggestIncoming() {
        metadataBusy = true; localError = nil
        Task {
            defer { metadataBusy = false }
            do {
                guard let suggestion = try await setup.suggestedIncomingCredential() else {
                    localError = "No unambiguous provider suggestion is available. Select the exact matching item manually."; return
                }
                form?.incomingSelection = suggestion; form?.incomingConfirmed = false
            } catch { localError = safe(error) }
        }
    }
    private func prepareNative(_ index: Int) {
        secret.clear(); localError = nil
        guard let id = form?.accounts[index].id else { return }
        do { try form?.useNewCredential(for: id, keychainPath: keychainFilter) }
        catch { localError = safe(error); return }
        advancedExpanded = true
        metadataTarget = form?.needsIncomingChoice == true ? "incoming" : ""
        guard keychainFilter.isEmpty else { return }
        metadataBusy = true
        Task {
            defer { metadataBusy = false }
            do {
                let path = try await setup.defaultKeychainPath()
                // An optional suggestion must not replace an explicit path entered during the lookup.
                if form?.nativeAccountID == id, form?.accounts[index].credential?.keychainPath.isEmpty == true {
                    form?.accounts[index].credential?.keychainPath = path
                }
            } catch { localError = "\(safe(error)) Enter an exact supported destination Keychain path in Advanced." }
        }
    }
    private func save() {
        guard display.canSave, let form else { secret.clear(); return }
        localError = nil
        do {
            let submission = try form.prepareSave(entry: &secret)
            Task { await setup.save(submission.change, creatingCredentialFor: submission.accountID, secret: submission.secret) }
        } catch { secret.clear(); localError = safe(error) }
    }
    private func safe(_ error: Error) -> String {
        if let error = error as? AccountFormError { return error.localizedDescription }
        if let error = error as? AccountValidationError { return error.localizedDescription }
        if let error = error as? KeychainError { return error.localizedDescription }
        return "Account setup could not complete. Review the configuration and recovery evidence."
    }
}
