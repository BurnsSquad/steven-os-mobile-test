# Shared planner inside the original OS

v143 adds a live Shared Tasks & Activities panel to Overview and Kids Planner in the authenticated original workspace. Existing private sections, charts and entries remain in place. The panel lists the same canonical household records as the existing Shared Tasks & Activities screen; it does not copy them into private OS arrays or recovery files.

Controls include Tasks/Activities and household-member filters, completion counts and attribution, individual/household-once/shared contributions, creation, rename and adult assignment changes. Assignments lock after the first contribution. Child UI permits only self-assigned Activity creation and own Activity rename; completion eligibility matches existing rules. Server membership and RPC checks remain authoritative. Assignment changes and renames are separate saves; stale edits retain typed text and request refresh/reopen. Refresh runs every fifteen seconds while visible and has a manual control.

The original source remains owner-only. This integration does not expose a parent's private dashboard, historical Finance or other original data to another adult or child. Other family accounts retain their existing shared planner and calendar. No database changes or broader permissions are required. Original HTML/JSON recovery downloads still cover only the private original workspace, not household database records.

Architecture: generic planner-panel.mjs is serialized into the existing opaque frame. Source/origin/nonce-bound postMessage requests use a command allowlist and the authenticated parent's existing client. No tokens, passwords, privileged keys, private source HTML or family IDs are bundled. The frame cannot access network or parent storage. Sign-out removes the frame. Shared rows stay in memory and are not passed to legacy private save/export controls.

Validation: scripts/planner-panel-smoke.cjs simulates parent/child/sibling contexts for creation, own Activity ownership, sibling read-only controls, partial/shared completion, locked assignments, assignment updates, rename, stale edit text, literal content, filtering and mobile fit. scripts/original-os-smoke.cjs uses local private input paths and mocked transport to verify dashboard completion reflected in Kids Planner, exclusion from private snapshots, original eleven tabs/five calendar views, connected calendar routing, private saves, recovery files/offline HTML and sign-out. Existing planner/Finance mock checks also pass. Automated simulations do not claim a new real-password/device acceptance test.


## Household tab connection — v149

The same live panel is now present in the original Household tab, initially filtered to Tasks. Parents can create, rename, assign and complete shared Tasks using the existing canonical planner transport and rules. The filter can still show Activities. Overview and Kids Planner retain their all-items default. No rows are copied or migrated. Original care rules and historical checkoffs remain underneath with an explicit explanation that they do not complete connected Tasks. This does not grant other family members access to the owner-only original workspace.

Mock original-source browser checks complete a Task from Household and observe the same completion in Overview/Kids, verify the Task filter and preserve original rule counts/private snapshots. Existing parent/child/sibling panel mock checks pass. No new real-device acceptance is claimed.
