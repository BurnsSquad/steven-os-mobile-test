# Original Steven OS integration review — v140

The owner's uploaded HTML is the actual interface, including its original scripts/styles. It is not recreated in a simplified layout. Original source and uploaded JSON are stored immutably in owner-only RLS sources; working state is a separate versioned private workspace. Neither source, embedded personal defaults, backup nor generated private document is in public repository/deployment assets.

## Record reconciliation

The uploaded HTML has more starter calendar records than the newer backup. Working state uses the supplied backup as authoritative, including explicit empty collections; it does not silently restore historical starter events that may have been deleted. Original HTML starter records remain preserved in the immutable source. Later optional backup fields are absent, not assumed to contain saved data. The supplied export filename/version is older than some features in the HTML; use a fresh export from the original browser later if additional school/opportunity/reflection/spending-budget records exist there.

The original Finance data remains historical in this private workspace. Newer Finance handoffs/rules are separate protected references, not silently mixed into legacy recurring amounts or chart totals. No shared planner tasks, routines or completion history are replaced. Current Finance and Shared Tasks links connect the private original interface to the existing working modules. Full canonical cross-module transaction/calendar/Finance synchronization and financial editing/scenario generation are still separate pending work.

## Privacy and isolation

- Imported personal calendar, business, goals and financial records default to the uploader's private owner account. Other adults, children, outsiders and anonymous callers cannot read them. Sharing selected calendar categories/records requires a later explicit rule; this import does not make all personal records household-shared.
- The original HTML runs in an opaque-origin sandbox without parent-session access or direct network access. A separate generic loader has an isolated CSP; the authenticated parent retains strict script policy. Original inline application scripts execute only inside that sandbox.
- Browser storage calls are adapted to per-frame memory. This avoids leaving private imported data readable by the next account through same-origin localStorage. Bound source-window/origin/nonce messages request versioned saves through the ordinary authenticated parent client. No token is sent into the original application.
- Saves serialize and check a version. Each accepted change preserves the prior snapshot. Stale saves stop rather than overwrite another device. On uncertainty/conflict, download an original OS backup before leaving/reloading. The immutable uploads remain recovery sources. An external backup is still advisable; source preservation is not a claim of paid point-in-time database recovery.
- Parent sign-out destroys the private frame and clears loaded data/session memory. Reload requires sign-in.

## Verification

Local browser test uses the supplied private files with mock provider/API transport, never real passwords. All eleven original tabs and five calendar views render. Backup event/routine counts are preserved; calendar editing and theme preference changes save through the bridge; prior task/finance module checks pass; parent mobile width fits; no persistent browser storage or external child requests; sign-out clears the frame. This is not complete certification of every legacy feature or real ordinary-device sign-in acceptance.

Hosted rollback SQL-role tests verify owner read/save, prior revision retention, stale conflicts, invalid snapshot denial, immutable source, and denial for another parent, children, unrelated users and anon. No retained test edits. Existing optional password feature advisory remains unchanged; Free remains selected.

## Next acceptance

Owner signs in to the new preview and compares the actual original layout/tabs/calendar/charts. Confirm expected records before any starter-source reconciliation or cross-member calendar sharing. Resolve absent optional backup data via a fresh export if needed. Current Finance and Shared planner remain separate source-of-truth modules during this review; no production promotion, original-file replacement or merge.
