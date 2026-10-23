# Entry 306 — Session concurrency reliability and current handoff

v152 fixes a reproduced shared-client session race. Concurrent near-expiry panel requests now share one refresh. Late old-token 401 replies retry once with the refreshed session. Old-session refresh/sign-in/request failures cannot clear a newer login or retry old work under its identity. Clear/sign-out suppresses late token restoration; unauthorized retries remain bounded and end access.

Five of the first six deterministic race tests failed before the fix, including three refreshes instead of one. All eight final cases pass after the change. Existing provider identity/membership, grocery API, recovery and private export tests pass. Full original-source and shared multi-context browser regressions pass for eleven tabs/five calendar views, Finance, routines, groceries, private exports, mobile and sign-out. No physical-device or real session-lifetime acceptance is claimed.

No database/Auth setting, password, recovery callback, financial source or role permission was changed. No persistent browser session storage was added. Generic current handoff docs/handoff/CURRENT_STATUS.md identifies the active implementation branch, collaboration workflow, current preview and remaining family-dependent checks; older handoff stages should not be mistaken for current requirements.

Preview READY: https://steven-os-mobile-test-m9zn2omxd-burns6.vercel.app/

Next assistance needed: actual two-device family sign-in and grocery add/pick/attribution check. Parents still need to confirm current financial facts and cash through the workbench. Collaborator onboarding stays paused until the owners sit together. No production promotion, merge or historical-log rewrite.
