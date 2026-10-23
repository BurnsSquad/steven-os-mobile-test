# Evening routines

Installed additive backend recurrence for the selected routine. The current planner website needs no new deployment: generated occurrences use its existing Tasks API and completion rules.

- Every evening at 17:00 America/New_York; local timezone conversion handles daylight saving. The administrator-managed job checks hourly and retries during the evening.
- Tonight's reviewed starter items are adopted as the first occurrence without changing titles, assignments or completions. Future titles include the evening date in brackets.
- Each template/date has one unique occurrence. Row locking serializes concurrent scheduler calls; inserts are atomic. New occurrences start pending. Earlier pending/completed Tasks remain visible and retain history.
- The job does not invent missed-day backlogs after database downtime: it creates the current evening's set when available. Paused/offline databases cannot run jobs.
- Templates are private, administrator-managed and not available to browser roles. The scheduler is invoker/admin-only, not a public RPC or an impersonated browser session. Creation events identify scheduled owner-authorized setup.
- Editing a dated Task changes that occurrence only. Changing the repeating template, time or disabling recurrence currently requires an administrator. No routine-settings UI is shipped.
- Cron operational history is available in the Supabase Cron dashboard. To stop generation without deleting Tasks: deactivate job `bb-planner-evening-routines-v1` or set the private routine's `enabled` to false. Do not drop pg_cron or delete completion history.

Verification: `evening-routines-test.sql` ran successfully in a hosted rollback transaction. It covers restricted ACLs, before/at the evening boundary, duplicate retries, a daylight-saving transition, assignment preservation, new pending state, earlier completion retention and disabled routines. All temporary future occurrences and test completions rolled back. This is administrator SQL verification, not another real-device login test. The installed Cron job also has an independently observed successful scheduled run.

Security advisor: three informational RLS-without-policy notices are intentional default-deny for the administrator-only private tables, with API privileges revoked. Existing optional leaked-password protection remains unchanged on Free. No household identities or template contents belong in public source/logs.

The earlier first-week PDF describes the starter set before recurrence was installed; this document and development-log Entry287 supersede that one-time-only status.
