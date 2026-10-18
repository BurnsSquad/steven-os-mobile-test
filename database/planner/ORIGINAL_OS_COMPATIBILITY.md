# Original Steven OS compatibility map — v148

The uploaded original HTML supplies the actual eleven-tab layout and legacy behavior. Its supplied JSON backup supplies working private records. Shared modules are added beside legacy content, not copied into it. This map replaces outdated assumptions that the layout or calendar backup still needs rebuilding/importing.

| Original tab | Current behavior | Sharing boundary / remaining work |
| --- | --- | --- |
| Overview | Original cards and charts, connected Tasks/Activities and current Finance summary | Original records owner-only. Shared panels use canonical household data. Finance summary parent-only, saved-input source check, not live banking. |
| Priority Board | Original flexible priorities, conditions, visual views and scheduling | Private owner workspace; not canonical household task assignments. No automatic cross-member sharing. |
| Calendar | Original five views and private events, plus connected events and confirmed parent Finance due dates | Family/Parents/Private audiences for connected events. Legacy private events are not shared automatically. Finance dates route to the source rather than duplicate events. |
| Finance | Current parent fact review/paycheck plans above original ledger/spending charts | Current and historical values clearly separated. Actual balances/provider confirmations must come from parents. Transaction ingest and complete forecasting remain pending. |
| Burns Base | Original records and sections | Private owner records; not implicitly shared with family. |
| Household | Original care expectations, routine rules and historic completions | Private legacy history. Connected recurring tasks remain canonical elsewhere; no silent conversion or duplicate completion history. |
| Groceries | Original lists/stores/spending entry and charts | Private records; shared list synchronization is not yet implemented. |
| Kids Planner | Original child views/progress and connected Tasks/Activities panel | Original child-labelled records remain private to owner; child accounts use shared planner/calendar. Legacy history is not attributed to database identities by guessing. |
| Goals | Original roadmaps, milestones and progress visuals | Private owner workspace. Shared goal permissions and migration require explicit design. |
| Businesses | Original ventures and related visuals | Private owner workspace; business cash is excluded from household planning unless explicitly released/reviewed. |
| Settings | Original theme/preferences and private owner state, plus hosted recovery toolbar | Hosted saves preserve prior versions; stale saves stop. Private HTML/JSON downloads do not include shared online datasets. |

## Save compatibility fix

A legacy Kids Planner navigation preference used `steven-kids-nav-v73`, outside the hosted snapshot allowlist. Changing that preference introduced a rejected key into the complete snapshot, so the save message could be ignored and later private changes not saved. The hosted adapter now maps this specific legacy key to `steven-os-kids-nav-v73`. Offline recovery generation applies the identical alias so the exported original reads the saved preference. The immutable source is untouched and the database's narrow key validation remains intact.

An invalid private snapshot now produces a visible could-not-save message rather than disappearing silently. This is not a general relaxation of allowed storage keys or permissions.

## Evidence and limits

Mocked original-source browser checks exercise all eleven tab renders and five calendar views, hosted Kids navigation-style save, valid key namespace, subsequent calendar/preference saves, current Finance/Overview routing, connected planner/calendar overlays, mobile fit and private recovery downloads. The exported HTML opens independently with the saved Kids navigation style. Recovery unit checks cover state/provenance, optional collections and alias rewriting.

These checks do not certify every legacy button or prove new ordinary-account/device acceptance. Missing optional records in the uploaded backup are not invented. Connected data stays out of private legacy arrays and recovery files. No household permissions, schema, family records or production deployment are changed by this compatibility fix.
