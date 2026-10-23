# Entry 308 — Separate parent shared-data download

v154 adds an explicit parent-requested JSON download for shared Tasks/Activities/completions, Family-visible calendar events, groceries including archived state, routine settings/templates and household usernames. The shared screen has a Save shared household data card; the original toolbar offers a shortcut. No automatic download, repository data artifact or server file is created.

Finance, private/Parents-only events, original private source/workspaces/revisions, internal scheduler occurrence rows, full audit history and account credential/email fields are excluded. Record text entered by family members stays in its record. This is a portable data export read across several authorized requests, not a point-in-time database snapshot or automatic restore/import. The original private HTML/JSON recovery downloads remain separate.

The generator checks current parent membership before collection and again before producing the file, verifies household scope, selects fields explicitly and refuses partial output after collection failure, session clear or membership change. Children have no export controls and are refused before collection. No database migration, permissions expansion or financial fact change.

Four deterministic tests pass scope/relationship/version preservation, archived state, Eastern date, provider-field exclusion, child denial, foreign/failed collection refusal and session/membership cancellation. Shared browser mock downloads/parses the file and verifies actual mocked items, grocery pickup attribution, usernames and routine settings, plus child control exclusion. Original-source browser mock uses the toolbar shortcut and downloads the separate shared file while both private recovery downloads and existing eleven tabs/five calendar views, routines/Finance/mobile/sign-out regressions pass. This does not claim the user has downloaded the file on a physical device.

Preview READY: https://steven-os-mobile-test-78a4syx9h-burns6.vercel.app/

Documentation: database/planner/SHARED_DATA_EXPORT.md. Current handoff updated; generic update series continues without rewriting historical log. Prior user-confirmed grocery sharing remains accepted; Amanda onboarding stays paused until together. Draft branch only, no merge or production promotion.
