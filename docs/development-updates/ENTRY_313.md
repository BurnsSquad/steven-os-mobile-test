# Entry 313 — Priority Board and scoped data downloads

Completed the four requested follow-ons: Goals/milestones were added to the family download, Businesses received a separate parents-only download, both download scopes were tested, and the original Priority Board area was connected to new shared family records without importing private legacy data.

The connected Priority Board is visible to the household. Each person manages their own priorities, parents manage all and can create Family priorities, and the server records completion identity and history. Readiness choices such as available time and focus energy remain private to the signed-in account. Fixed appointments remain in Calendar.

The hosted additive schema uses row-level security, direct-write denial and checked functions deriving actor and household from the authenticated request. Rollback-only role tests cover child-own writes, sibling denial, both-parent management, Family priorities, private preferences, completion/reopen attribution, stale-write denial, archive locking, cross-household/no-identity denial and ACL isolation. The transaction was rolled back and zero priority/audit fixtures remain. A follow-up index resolves the only new performance-advisor finding.

Deterministic request/export tests pass. A dedicated three-context browser flow passes personal/everyone views, recommendations, parent/child controls, literal text rendering, mobile fit and sign-out clearing. Shared-shell, original eleven-tab/five-calendar-view and recovery browser regressions pass. Browser provider calls are mocked; this is not a fresh family-password or physical-device acceptance claim.

The family JSON download now includes exact-field Goals, milestones, steps and shared priorities while excluding personal readiness preferences, Finance, parent Businesses and private original data. Parents have a separate exact-field Business download. Child export attempts refuse before reading Business records. Both downloads are read-across-request snapshots with no automatic restore/import.

Preview v157 is READY at https://steven-os-mobile-test-gd6w2pcxg-burns6.vercel.app/ . The draft branch remains unmerged and no production promotion, banking, billing or cleanup was performed. Existing Supabase Free leaked-password warning and intentional private scheduler-table information item remain.
