# Companion account and default setup validation

Created: 2026-11-13
Updated: 2026-11-13

Status: automated implementation/package verification complete. Native app consent,
interactive setup and controlled live desktop acceptance remain pending until
observed. Historical results do not establish this increment's acceptance.

Scope: the approved account/default setup increment, governed by its
[specification](../superpowers/specs/2026-11-13-companion-account-default-setup.md)
and [implementation plan](../superpowers/plans/2026-11-13-companion-account-default-setup.md).
Account editing/deletion, assignment editing, running reload, fallback and
automatic restart remain deferred. Original direct recovery remains distinct
from the configured outgoing default.

## Automated acceptance

The fresh ordered acceptance ran from the repository: native tests **231/231**
(173 Core, 58 App), current release build/ad-hoc signing, Node tests **811/811**,
and exactly **3/3 package tests with zero skips**. Each command exited 0. The
syntax check and final whitespace check passed.
The signed artifact is an ignored local Apple-silicon app, not a distribution
notarization claim. All package results below use that current artifact.

Test-first `npm test` failed before the production resource change: 808 tests,
805 passed, three package failures and zero skips. Assembly decisively required
the missing setup module. This RED/stale artifact result is not acceptance.
A separately reproduced missing-selected-destination integration bug was fixed:
explicit normal-home browsing now survives a genuinely absent selection without
inventing context/mappings; valid selected files keep their own home and unsafe
existing evidence cannot trigger that fallback.
The three existing package cases cover explicit resource allowlists, relocated
schema-1 import with byte-exact checkpoint and standalone compatibility, and
source-denied schema-2 first setup/default completion. Their managed starts must
begin Off; activation/rollback retain the original provider connection. Synthetic
references in ordinary cases deliberately do not exist, and no model traffic or
credential lookup is needed for these controls.

The native subcase compiles a test-only Swift executable with production
KeychainStore/types. It may create only its positively owned disposable Keychain
and item. Public fixture values remain in process memory, with paths/references
only in arguments and fixed comparison markers in output. It checks metadata,
add-only duplicate rejection and the bundled fixed reader, then validates owned
cleanup. Search-list cleanup filters only its owned entry from the current list;
it never restores a historical whole list or changes the default Keychain.
This harness trusts its own executable plus the fixed reader. Its identity is
different from the packaged app's identity, so success cannot establish native
app consent or its actual ACL identity.

The actual native subcase passed production metadata/add, duplicate rejection,
bundled reading and owned cleanup together. The fixed comparison marker was the
only result leaving the reader child. The returned database and known native
sidecars were absent afterward; owned fixture directories were empty/removed,
the owned entry was absent from the current search list and the opaque default
Keychain handle remained unchanged. Ordinary controls observed zero destination
connections, unchanged synthetic configuration/provider bytes through mode
changes, byte-exact direct rollback, exact tracked-child exit and reusable ports.
Source-denial negative reads/imports passed, as did visible native-window and
synthetic-instance-lock attribution. These are fixture observations, not GUI
setup interactions.

Native harness development exposed macOS path-spelling disagreement and actual
atomic database inode replacement during the native add. An early filename-based
cleanup inference was corrected. The final harness captures the completed known
add's identity and requires it unchanged through subsequent checks/deletion,
bound to the same owned directory and native handle/path. Failed roots were
preserved and individually remediated with exact owned metadata/identity checks;
all observed failed fixtures are removed. No user item was read/updated/deleted,
no prior whole search list was restored and no default Keychain was changed.
Raw diagnostic and remediation evidence stays outside Git.

File-backed Security/ACL SDK deprecation diagnostics are an intentional reader
compatibility tradeoff. The fresh release build emitted seven such declarations;
each package harness compile emitted thirteen (production plus test-only native
lifecycle APIs). No other compiler warnings/errors occurred. Diagnostics remain
visible without global suppression.

## Native and live observations

| Capability | Current evidence |
| --- | --- |
| First configuration, metadata selection and distinct incoming/default choices | Pending native observation |
| Concealed native entry, creation consent and actual packaged-app ACL identity | Pending native observation |
| Explicit first/default selection and add preserving current default/assignments | Pending native observation |
| Safe stop/save/next Start Off boundary and created-but-unlinked reconciliation | Pending native observation |
| Named default at a different destination, project override, inheritance and follow-up | Pending controlled live observation |
| Missing/inaccessible selected item and upstream failure remain failures | Pending controlled live observation |
| Exact direct restoration, manual restart/response confirmation and owned cleanup | Pending native/live observation |
| Final sequential specification and quality review | Pending |

Actual endpoints, references, mappings, checkpoints and raw runtime evidence stay
outside Git. This report records only sanitized outcomes. Prior live
`499/CANCELLED` qualifications and the two accepted viewport/focus observations
remain in the historical validation record; this increment neither erases them
nor claims to have repeated those observations.
