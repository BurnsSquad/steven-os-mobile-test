# Shared household preview (v132)

This is a separate fictional-data preview, not a replacement for Steven OS v122 or the user's personal HTML. It starts the requested cross-account/cross-device workflow with shared tasks. It has no import, personal-data synchronization, signup, invitation, production configuration or DELETE control.

## What is already finished

The uploaded v131 exactly matches the repository v131 (Git blob d0db22f59d0ea1e6c20e8bd59b3302db9c9df0bd). Do not repeat the completed live 27/38-case security runs. Their disposable rows were intentionally cleaned up. The preserved shared baseline is displayed read-only in this preview.

## Use and limits

Serve only this directory on a separately reviewed HTTP(S) preview origin. ES modules are not reliably usable through file://. Do not host the original personal HTML, the repository root, evidence directories, or password files. No deployment has been performed by adding these files.

The page is pinned to the isolated sandbox and the three existing fictional accounts. Enter only its public publishable key and the privately saved original test password in the browser form. Never use an administrator key or production credentials. The key, password and session token are not persisted by application code; a page reload requires sign-in again. Browser/password-manager behavior remains under the user's control. Expired sessions require sign-in; automatic refresh and permanent login are not implemented.

Membership and tasks are read from the server after sign-in. A/B can add, rename or complete new fictional preview tasks; C has no membership and receives no creation form. Database RLS/grants remain the authorization layer. New preview tasks use bba80000-prefixed UUIDs and TEST ONLY titles. The original bba30000 baseline and old bba60000 security fixtures have no editing controls here. UI restrictions are additional safeguards, not database policies.

Changes are fetched with Refresh and every 15 seconds while the page is visible, not a Realtime subscription. Concurrent edits use the last observed title/completed values as conditional filters; zero matched rows prompts a refresh rather than overwriting a competing change. This does not prove transactional multi-field conflict handling under every interleaving. Request failure is never labeled success. Offline edits, saved login, real family account onboarding and other app modules remain outside this preview.

## Verification already performed

- Node syntax check on app.mjs; stable index hash unchanged; whitespace check.
- scripts/household-preview-smoke.cjs uses Playwright with three isolated contexts and all HTTP(S) responses intercepted. A creation reaches B, B completion reaches A, C is isolated, baseline checkbox disabled, task text cannot inject HTML, 390px viewport has no horizontal overflow, no local/session storage writes, sign-out clears the list, no DELETE requests. All pass. **Zero live Supabase calls**; this is UI simulation, not new RLS evidence.
- This environment provides Playwright 1.62.1 and system /usr/bin/chromium. Test browser executable is a local environment prerequisite, not an application dependency. Run from repository root: node scripts/household-preview-smoke.cjs. Adjust the local test browser path for other environments. Application itself has no package/CDN dependency.

## Next real two-device acceptance check (not run)

1. Review and publish only this directory to a separate preview URL; hosting/deployment is a separate step. Preserve the stable site and local files. Never add secrets to GitHub.
2. Open the same preview URL on Mac and phone. Sign in as fictional A and B respectively. Use C separately for the unrelated-account view.
3. With reviewed fictional write scope, add one clearly named fictional preview task on A. B sees it after Refresh (or the next 15-second check). B completes/renames it; A sees it after Refresh. Verify sign-out, re-login, page reload and error messages on each browser. Do not edit the baseline or enter personal records.
4. Independently inspect exact new fixture IDs/values, memberships and permissions. Preview testing creates new bba80000 rows; previous cleanup authorization does not apply to them. Prepare an exact new cleanup manifest and obtain approval before removing them. Do not rerun the old cleanup SQL or recreate the old security fixtures.

After acceptance, plan production account onboarding, a reviewed production schema/release and continued protection of private records. Do not claim all Steven OS modules now synchronize. No personal-data migration is part of this preview.

## Rollback

Before deployment, revert only this added preview directory/test commit. If a preview is deployed, remove only that preview deployment with the appropriate approval; stable index remains untouched. The browser UI issues no DELETE. Any sandbox records created during later manual acceptance need separately approved precise cleanup. Never clear the original app's storage or delete a test user/membership to reset the preview.
