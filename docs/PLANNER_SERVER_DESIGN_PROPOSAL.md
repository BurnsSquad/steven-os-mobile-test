# Shared planner server model — review proposal, not executed

The new Tasks/Activities interface is a disconnected fictional demo. The existing sandbox API enforces its earlier generic member model, not this new role-specific model. No schema, grant, membership, real account or production change is authorized by this proposal.

## Data boundaries

Use a new namespaced planner model, without reusing or widening existing private-task policies, personal records or current household memberships. Logical entities:

- Planner membership: household, authenticated user, verified adult/child role, trusted onboarding provenance. Clients cannot create memberships, change roles or self-promote. Bootstrap requires separately reviewed administrative setup using fictional users first.
- Item: household, Task/Activity type, title, creator, Individual/Household-once/Shared mode, timestamps and revision. Creator, household and type are immutable through ordinary edits.
- Assignment: item plus assignee. Individual mode has exactly one assignee. Shared mode has a required assignment set. Household mode has an explicit eligible set; visibility does not itself confer completion rights.
- Completion: item, contribution/assignment, effective member, actual actor and timestamp. Unique constraints/idempotent transactions prevent duplicate contributions and preserve first-actor attribution.
- Audit event: append-only attribution for administrative assignment/completion changes. Ordinary clients cannot rewrite the audit trail.

No personal identity or family-count details are required to define these generic tables. Actual SQL names, constraints, policy definitions and bootstrap manifest must be reviewed concretely before any new migration.

## Authorization requirements

All actors require ordinary verified authentication and matching database-backed household membership. Do not use a UI role selector or user-editable metadata as authority. Adults manage planner items and assignments; children create Activities only for themselves, edit their own Activities, complete personal assignments, and can complete eligible household-once work. Children cannot create Tasks, assign siblings, alter roles/household/creator, or submit another person's Shared contribution. Every household member can read the shared planner; existing owner-private items are outside that visibility rule.

Creation must atomically produce consistent item/assignment state. A child cannot insert an item and then broaden assignments through a second endpoint. Item type and completion mode must be checked independently. Permission checks must apply to direct API requests, not only form visibility.

## Transactional completion

- Individual: authenticated assignee completes their assignment; adult action explicitly records both actor and assignee.
- Household-once: server validates eligibility, locks/conditionally transitions the current item, writes exactly one completion and preserves first accepted actor/time. A competing request returns an idempotent already-complete/conflict result without rewriting attribution.
- Shared: server permits only own contribution unless verified adult administration; unique item/assignment prevents duplicates. Overall complete derives from all required contributions in the current assignment set.
- Reassignment after recorded contributions, undo/reopen, cancellation and deletion need explicit product/audit semantics. Leave unavailable until reviewed; do not silently discard contributions.

Choose the controlled transactional mutation surface and its exact grants/policies only after reviewing recursion, role checks, server-side execution privileges and error behavior. Do not add SECURITY DEFINER or privileged API access as a shortcut for an unexplained permission failure. No secret keys belong in browser code/Git/chat.

## Fictional verification and approval sequence

1. Confirm intended isolated project and capture current schema/policy/record baseline read-only. Preserve the retained prior preview task unless separately approved for cleanup.
2. Publish exact additive schema/policy/bootstrap and rollback proposal for required approval. Include new table/function names, constraints, grants and fictional identity mappings; no production changes or personal data.
3. Implement only the reviewed additive sandbox changes. Review administrative mutations before execution; keep old memberships/private policies untouched.
4. Test direct ordinary-user API requests for every allow/deny pair, membership escalation, sibling assignment, cross-household access, duplicate/concurrent completion and immutable identity fields. Client401 is inconclusive, not permission protection.
5. Capture independent before/after evidence, then connect the new UI and test Mac/phone sessions and failure handling. Offline model/browser tests do not replace this step.
6. Prepare exact fixture cleanup for separate destructive approval, preserving baselines; document transaction rollback versus post-commit recovery. Production environment, onboarding, hosting and release remain a later review.

## Rollback and current status

Nothing in this proposal has executed. Reverting design-demo files has no database effect. For a future additive migration, capture dependencies and exact reversal SQL before approval; no CASCADE, user deletion or policy reset should be an assumed rollback. A failed transaction rolls back before commit; committed removal needs separately approved recovery. No reliable production release date can be inferred from completion of the interface demo.
