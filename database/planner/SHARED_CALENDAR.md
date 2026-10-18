## Shared calendar — v141

The connected calendar includes an agenda and event editor inside the original Calendar tab. Connected events also overlay its week, month, year, timeline and table views, labeled Connected. Multi-day events appear on each occupied Eastern date. Selecting a connected entry opens the connected editor; legacy drag/copy/delete actions do not apply to these entries. Accounts without the private original workspace use the Calendar navigation button. The original private calendar and its five views are preserved; connected rows are overlaid in memory without modifying original private event records. The original private exports do not include shared calendar records.

Adults create Private (creator only), Parents-only or Family events. Children create Family events and edit/cancel their own. Other children can view family events. Adults may edit/cancel visible shared events; only the creator changes audience. Backend membership and row policies enforce these rules. Cancelling retains the event and private change history. Direct browser table writes and history reads are denied.

Times use Eastern Time and 12-hour AM/PM controls, with all-day date ranges inclusive in the UI. DST gaps are rejected; repeated fall hours use the first occurrence. Saves use optimistic versions and stable creation IDs. Fifteen-second refresh while visible; explicit Refresh available. Existing original calendar records are never automatically published.

Installed migrations: household_calendar_visibility_and_child_events and calendar_creator_visibility_guard. SQL-role tests in shared-calendar-test.sql roll back their fixture rows. These are administrator-driven role simulations, not ordinary sign-in acceptance. calendar-ui-smoke.cjs uses mocked transport; original-os-smoke.cjs verifies the private original integration and regressions. Real account/device acceptance of this new calendar remains next.

