# Parent routine controls — v138

Adults can edit their household's existing routine schedule (selected ISO weekdays, exact local minute, enabled/paused), edit/pause existing repeating Tasks, and add repeating Tasks. Individual/household/shared assignments use the same checked membership rules as one-time items. Up to 30 templates per routine; paused templates remain available for history and later reuse.

Changes affect future generation; existing dated items, assignments and completions never change. Changing a dated Task's Assignment/Rename still affects that occurrence only. To change the repeating pattern, use Repeating routines. A newly enabled/added template may generate on the current selected day if its chosen time has passed and it has no occurrence yet. Already-generated template/date pairs never generate twice, including after pause/resume or time changes. No missed-day backlog is created after downtime.

The Cron job checks each minute so arbitrary HH:MM choices work. America/New_York remains the configured timezone, including DST; no timezone selector is shipped. A skipped spring-forward local minute runs on the next available minute after the threshold. Fall-back repeats remain idempotent. Supabase paused databases cannot execute jobs. Cron run history requires periodic operational review as it accumulates.

Security: public RPCs are invokers. Private definers are owned by a new NOLOGIN/NOBYPASSRLS editor role with only SELECT plus specific UPDATE/INSERT rights on routine configuration and SELECT on memberships; no item/completion/Auth writes. Each call checks verified actor membership and adult role. Routine row locks serialize scheduler/config edits. A version number rejects stale saves, including edits by another parent. Direct API table writes and anonymous RPCs remain denied. Private occurrence mapping remains administrator-only and untouched by editor APIs.

Verification: hosted rollback-only SQL role tests cover adult list/schedule/template edits, invalid schedule, duplicate days, foreign assignees, stale version, child/outsider denial, minute boundary, selected-day generation and paused templates. Test rows/settings roll back. This is SQL-role simulation, not a claim of new real device/password authentication. API tests and 21 mocked browser checks also pass; real parent acceptance is next.

Recovery: the new preview links to the already verified v137 recovery page. It does not change Auth redirect settings or weaken callback origin validation. Return to the v138 preview after recovery.

Product handoff requirement: the original Steven OS layout is the foundation of the eventual combined dashboard. The planner preview is an incremental working module, not a replacement layout. Preserve original dashboard features and local records; integrate after routine feedback and the Finance creator's latest source/backend handoff. Finance remains separate.
