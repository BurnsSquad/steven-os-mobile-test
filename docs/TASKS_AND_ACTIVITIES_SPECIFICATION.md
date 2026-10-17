# Tasks and Activities specification

Status: approved generic requirements; not yet implemented. Explicit public-publication approval applies to these rules only. No family counts, member identities or personal records are included.

## Creation, visibility and management

- Adults create, assign and manage **Tasks** and household settings.
- Kids create **Activities** for their own days, using comparable planning/completion functionality. They can edit their own Activities and still complete Tasks assigned to them.
- Everyone in the household can see shared-planner Tasks and Activities.
- Children cannot edit another child's individually assigned item or gain assignment, membership or role-management authority merely by viewing it.
- Adults can manage everyone's shared-planner items. Record actor identity on completion and administrative changes.
- Child-created Activities default to self-assignment. Broader assignment requires explicit server authorization; matching functionality is not permission to assign siblings.
- Deletion/cancellation behavior and exact scheduling fields are not yet specified. No destructive action is implicitly authorized.

These visibility rules apply only to the new shared planner. Existing private Tasks and personal records remain private; their policies must not widen.

## Completion modes

Item type, visibility, assignment and completion mode are separate concepts.

| Mode | Behavior |
| --- | --- |
| Individually assigned | Assigned child or adult administrator may complete it. |
| Household, complete once | Either eligible child may complete it once for everyone; adults can manage it. |
| Shared, individual contributions | Each assigned person completes their own part; the overall item completes when all required contributions are complete. |

Shared describes contribution tracking here, not merely visibility. Household-first completion must handle concurrent attempts atomically and preserve who completed it and when. A child may not overwrite a sibling's contribution. Any administrator override needs attribution.

## Development boundary

The existing sandbox preview demonstrates generic member sharing with one completion boolean. It does not implement or verify the new role/type/assignment model.

Next prepare separate Task/Activity interface controls and a concrete server proposal distinguishing item type, completion mode, assignments and individual completion records. Server-side membership and role checks enforce creation, editing, assignment and completion separately. User-editable metadata or a client role dropdown cannot grant authority.

New fictional tests should cover adult Task creation, child Task-creation denial, own Activity creation, sibling edit/assignment denial, assigned Task completion, atomic household-once completion, separate shared contributions, administrator actions, unrelated-household isolation and preserved private baselines. Reuse unchanged evidence instead of repeating completed setup.

No schema, policy, accounts, invitations, memberships, data migration, deployment or stable-v122 change is performed by this specification. Required environment verification and approval gates remain in force before database permission changes or destructive cleanup.
