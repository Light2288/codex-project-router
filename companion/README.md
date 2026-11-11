# Companion operational controls

The companion uses bundled router modules through an installed Node 24 executable.
Private router configuration remains in its original location, outside all Git
checkouts and application bundles. Controls never retrieve credentials, execute
the provider authentication helper, or preflight destinations.

## Local bridge

`src/companion.js` exports `inspectCompanion({configPath, browseHome})` and
`runCompanionControl({action, configPath, expectedContext})`.

`configPath` is an absolute canonical path. For browsing without a configuration,
pass `configPath: null` and an explicit absolute normal Codex `browseHome`.
Selected configurations use their own `codexHome` and activation directory.
Inspection reads current state without changing configuration or mappings.

Run `node src/companion-cli.js` with one JSON object on stdin. The request has
`schemaVersion: 1` and `action: "inspect"`, `"activate"`, or `"rollback"`.
Inspection accepts only `configPath`, plus `browseHome` when the path is null.
Mutations require `configPath` and the exact fresh inspection `expectedContext`:
`{configPath,codexHome,providerId,listenPort}`. No shell is required.

The CLI accepts at most 16 KiB and emits exactly one JSON envelope, at most 1 MiB:
`{schemaVersion:1,ok:true,result}` or
`{schemaVersion:1,ok:false,error:{code,message}}`. Failures exit nonzero with
fixed safe errors. Overflow fails without a partial catalog. The existing
`src/cli.js` commands and status output are unchanged.

Inspection separates configuration, provider and catalog outcomes. Configuration
is `missing`, `valid`, `invalid`, or `unavailable`; a valid selection includes its
canonical path and `legacy` or `credential` mode. Provider state is `direct`,
`router`, `conflict`, or `unavailable`, with independent `proxyReady`,
`recoveryRequired`, and `recordPhase`. A provider/recovery failure retains the
selected context and any independently readable catalog.

Catalog entries contain only `{id,name,routeAlias,routeState}`. They use current
`local-projects`, validate UUID key/record agreement and string names, and sort
by name then ID. Routing keeps exact existing mapping keys. Unmapped projects
have null aliases; missing credential targets are `target_missing` in credential
mode. Configured projects absent from the catalog remain `catalog_missing`, with
an empty name: display these as explicitly unresolved projects with their IDs.
Malformed/unreadable catalogs return `unavailable` with no fresh entries.

`revision` is private comparison metadata for configuration identity, effective
provider state and validated activation-record identity/phase. Never render or
log it. It excludes raw provider bytes and authentication values. Provider URL
changes within an already conflicting state cannot create usable confirmation.
`inspectActivation(configPath)` exports `{context,revision,recordPhase,status}`;
the historical `status(configPath)` returns only its unchanged status object.

Activation and rollback freshly validate the exact expected context before
delegating to existing controls. Activation still requires matching listener
fingerprint readiness. Rollback works offline and tolerates unrelated mapping
changes while preserving the selected recovery context. Existing helper locks,
backup validation, URL-only editing and compare-before-replace remain
authoritative; there is no cross-file transaction against external editors.

Readiness proves neither desktop-loaded settings nor gateway/key acceptance.
Restart Codex manually after provider changes and explicitly confirm a working
response. Native lifecycle and recovery controls are documented with the app.
