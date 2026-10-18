# First family trial: Prepare for tomorrow

A generic visual guide plus private fillable feedback worksheet. No actual family identities, usernames, addresses, household IDs or planner records are embedded.

The owner selected this starter routine and authorized setup. Administrator-assisted setup created individual packing Tasks and a parent-eligible Household-once plan review in the private pilot, using checked planner RPCs and audit metadata identifying administrator setup on the owner's request. This was not a browser/JWT acceptance test. Existing records are retained and no completions were manufactured. A versioned routine marker plus transaction/advisory lock prevents duplicate setup on retries.

These are one-time Tasks. Automatic recurrence, daily reset, scheduling and reopening remain unimplemented; do not imply the first-week guide automates them. Completed history remains intact. Further recurrence design needs an explicit frequency/date/timezone decision.

`build.py` regenerates the editable SVGs, web guide and two-page fillable PDF under ignored `work/family-trial/`. It uses Python reportlab, standard DejaVu fonts and three blank AcroForm text fields. Filled feedback belongs in a privately saved local PDF; the guide has no submission endpoint, analytics or feedback storage.

The guide links to the existing v137 pilot, not a replacement login site. The original dashboard and Finance backend remain separate. Next product decisions are recurrence needs and the Finance creator's source/calculation/storage/permission/backup handoff. Public development notes should summarize generic findings without private family data.
