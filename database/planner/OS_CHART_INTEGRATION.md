# Original Steven OS chart preservation and mapping

The retained v122 `index.html` remains unchanged. It is the visual/feature baseline, not a discarded prototype. Its old browser data is not accessible from a new preview origin.

| Original component | Current mapping / migration requirement |
| --- | --- |
| Sidebar, cards, responsive sections, themes | Sidebar/cards and blue palette reused in v139. Full theme settings remain in original source. |
| `chartHtml` category bars | Reused visual pattern for living categories and next-check bill/living comparison; money calculated in cents. |
| `finDonut` bill allocation ring and legend | Ring/legend pattern adapted to documented current-check amounts; paid versus other mixed statuses explicitly labeled, no claimed bank reconciliation. |
| Bill status circles and ledger | Original source preserved. Current read-only ledger uses handoff statuses. Status editing/count circles await reconciled bill instances and revision APIs. |
| `v85SpendingChart` monthly/biweekly rings | Original source preserved; cannot manufacture actual spending from a planning PDF. Requires private expense/transaction backup. |
| Calendar week/month/year/timeline/table | Original source preserved; latest event backup required before dated bill/paid/inactive mappings can be reviewed. No events overwritten or silently imported. |
| Work-hours-by-job summaries | Original source preserved; actual shift records required, not derivable from finance handoff. |
| Household/Kids completion graphs | Shared planner is already connected separately. Legacy counts/history need explicit identity/date mapping from backup. |
| Goals, milestones and opportunity graphs | Original source preserved; latest saved goal/venture/opportunity data required. No invented milestones. |
| Savings/buffer progress | Targets from handoff are reference. Verified current balances are missing, so progress is not shown as zero or guessed. |

The source PDF is not the original dashboard backup. Next required input is the owner's latest Steven OS HTML (if newer than retained v122), plus exported JSON backup from the browser/file where the graphs contain the real records. Review conflicts and proposed source authority before import; the Finance handoff supersedes older assumptions, not unrelated calendar/goal data.
