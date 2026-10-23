# Parent shared household data export — v154

Parents can choose Download shared household JSON from the shared screen's Save shared household data card. The original private OS toolbar has a Shared data download shortcut to that card. Nothing is downloaded automatically by sign-in or background polling.

The file includes current shared Tasks/Activities, assignment/completion attribution and versions, Family-visible calendar events (including cancellations), grocery items including archived/picked-up state, current routine settings/templates and household usernames/roles. Export timestamps and collection counts are included; the filename uses the Eastern date.

The file excludes Finance, private/Parents-only calendar events, original private source/workspaces/revisions, internal scheduler occurrence records, full audit history and account credential/email fields. Text a family member typed into an item or event remains part of that record. Keep the downloaded JSON private.

This is a portable reference export, not an automatic restore/import, an immutable database backup or a single transaction snapshot. Reads span several authorized requests, so concurrent edits may span versions. Original private HTML/JSON recovery files remain separate. The export does not broaden database access or write any household records.

The existing ordinary authenticated client verifies parent membership before collecting data and again before producing the file. Household mismatches, a failed collection or a cleared/changed session prevent file creation. Fields are explicitly selected rather than serializing raw provider responses. Children receive no export controls, and the generator refuses child contexts before reading collections. Export happens in browser memory; no server artifact or repository data file is created.

Validation: request-level tests check scope/field selection, relationships/versions, archived records, Eastern dates, child refusal, no partial file on failures/foreign data and cancellation after membership/session changes. Shared-screen browser mock downloads and parses the JSON, verifies cross-context grocery attribution and child control exclusion. Original-source browser mock opens the shortcut, downloads the separate shared file and verifies current Tasks/calendar/groceries/routines while private recovery downloads remain intact. This does not claim a file has been saved on the user's own device; the parent initiates that download.
