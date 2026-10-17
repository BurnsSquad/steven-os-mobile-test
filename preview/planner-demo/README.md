# Tasks / Activities design demo (v133)

This separate interface implements the approved generic specification using fictional in-memory records. It is **not authentication, server authorization, persistent storage or cross-device sync**. The role selector simulates views only. No database, API, credentials, imported personal records or old app storage is used. Reload resets changes. Existing v132 live sharing preview and stable index are unchanged.

Adults create/manage Tasks. Children create/edit their own Activities and complete eligible assigned Tasks. All fictional items remain visible; sibling edit/completion controls are absent for individual assignments. Household work completes once, while Shared work displays each assigned contribution. Adults can rename/reassign uncompleted items and record completion for an assignee with actor attribution. Reassignment after any contribution is deliberately blocked until a separate retention/override design exists. There is no delete, real membership/settings editor or offline sync.

The demo defaults child Activities to individual/self assignment. Adults may change assignment/completion mode before contributions start. This prevents the role simulation from implying children can assign siblings. Scheduling fields and child cancellation/deletion were not specified and have not been invented.

`model.mjs` applies demo transitions; `app.mjs` renders through textContent and exposes distinct tabs/forms. CSP denies all connections. None of these client checks substitutes for server permissions. Only fictional characters appear; they are not actual users or household members.

## Reproduce checks

From repository root:

```
node scripts/planner-model.test.mjs
node --check preview/planner-demo/app.mjs
node scripts/planner-demo-smoke.cjs
```

Model tests use Node's built-in test runner. Browser smoke needs the environment-provided Playwright1.62.1 and `/usr/bin/chromium`; adjust that test prerequisite for another machine. It intercepts all assets at a virtual origin, aborts other origins and makes zero external/database calls. Checks child creation restrictions, sibling view without edit, contribution aggregation, household-first completion, adult edit, literal title rendering, no browser storage and desktop/mobile overflow. Model first-completion tests are sequential; real concurrent transactions remain untested and must be tested on the eventual server implementation.

Serve/deploy only index.html/style.css/app.mjs/model.mjs to a separate preview deployment. Never deploy original personal HTML, the repository root or evidence. No production promotion. Rollback consists of retiring only this exact demo deployment or reverting these additions; do not clear personal browser storage or change database records.
