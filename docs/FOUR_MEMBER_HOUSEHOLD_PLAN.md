# Four-member household access plan

Status: planning only. User requested four separate household accounts after the fictional shared-task preview passed its core Mac/phone acceptance. No real accounts, invitations, memberships, production schema or permissions have been created or changed.

## Confirmed scope

- Four individually authenticated household members; no shared password.
- First shared feature: household task creation, editing and completion across accounts/devices.
- Existing personal Steven OS records stay in their current file/browser. No import, migration, synchronization or erasure.
- Stable v122 index stays unchanged; all development remains on the separate review branch with an unmerged draft PR.
- Completed sandbox API security tests and cleanup remain evidence; do not repeat their setup unnecessarily or repurpose fictional users as real users.

## Information still needed

Adult/child composition and intended capabilities are unconfirmed. Ask for counts only, not names, birthdates, emails or passwords. Do not infer that all four should have identical access, or promise child-specific restrictions before designing and testing them. Decide ownership, household administration and invitations after roles are understood.

## Normal account experience to build

1. Household owner completes a supported sign-in/setup flow in a verified release environment.
2. Other members get distinct accounts through a reviewed onboarding route. An invitation design does not authorize sending messages; sending any invitation needs explicit user instruction.
3. Members see only authorized household content and can use permitted task actions on Mac/phone.
4. Ordinary users enter no API keys, choose no fictional account labels and see no security-test controls. Public client configuration is supplied by deployment; privileged keys remain server-only and outside Git/chat.
5. Session refresh/sign-out/reload behavior is implemented and tested. Shared-task changes propagate with a clearly stated refresh model; current preview uses 15-second visible-tab polling, not Realtime.

## Security design requirements

Authentication identifies the user. Membership stored in the database authorizes access to a household. UI role labels or user-editable metadata cannot grant authority. Administrative membership/invitation operations need server-verified authority; ordinary members must not be able to assign themselves household access or change ownership/household identity fields.

Preserve private-task isolation, existing production policies and memberships. Real-user permission/schema changes require a concrete reviewed proposal and required approval. Do not silently use the sandbox as production or weaken database controls to match UI behavior. Child/adult controls remain undecided until requirements are supplied; no financial/private-record visibility is inferred from household membership.

## Development and release sequence

1. Confirm role composition/capabilities for four seats.
2. Prepare normal sign-in/onboarding/session implementation and a fictional-data test plan on separate preview files.
3. Verify intended release environment and existing configuration without personal data or secrets. Produce exact schema/policy/account proposals for approval where needed.
4. Test allowed and denied actions, session lifecycle, four-account household behavior and unrelated-household isolation using fictional identities. Reuse existing security evidence where unchanged; add coverage for actual new authorization rules.
5. Run actual Mac/phone user acceptance; document observations separately from simulation or database evidence.
6. Review PR/base conflicts, hosting scope, rollback and deployment. No automatic merge, stable index replacement or production release.
7. Begin real-user onboarding only under explicit reviewed authorization. No personal-record migration is part of this plan.

No defensible launch date yet: role requirements, onboarding/session work and release-environment review determine the remaining duration. Core fictional task sharing already works; repeating that completed stage is not the next objective.

## Retained test row and rollback

One fictional browser-acceptance task remains in the sandbox, separately from the three security fixtures already removed. Any deletion needs its own exact reviewed cleanup and approval. Revert only newly added preview/onboarding code when needed; never clear the original browser storage or delete memberships/accounts as a reset. Database permission changes need captured before-state and reviewed reversal; committed deletions cannot be undone by a later ROLLBACK.


## Shared-planner capability requirements

Household administrators can manage settings and assign tasks. Planning members can create tasks for their own days as well as see/complete tasks assigned to them. Self-added tasks in this shared planner are visible to everyone in the household. Do not infer edit/delete/assignment authority from visibility. Editing/completion of other members' tasks is undecided. This generic capability model does not describe any particular household's membership composition.

Existing private tasks and personal records remain private; shared-planner visibility does not widen their policies. The current fictional preview has not implemented a new administrative/ordinary-member authorization matrix. Prepare separate reviewed new-record schema/policy/test proposals before role-specific permissions change. No accounts, invitations or database mutations are performed by this requirement update.
