# Shared Priority Board

The connected Priority Board stores new family priorities in `bb_priorities`. Everyone in the household can see them. Each member manages priorities assigned to them; parents manage every priority and the parent-managed Family owner. Existing private `steven-os-opportunity-v96` records are never imported automatically.

Readiness choices are personal. `bb_priority_preferences` stores only the signed-in member’s household-ready, homework-ready, focus-energy and available-time selections. Another family member cannot read or change them. Recommendations are calculated in the browser from the shared priorities and that personal setting.

All writes use checked RPCs with server identity, expected versions, row locks and private audit history. Direct authenticated inserts, updates and deletes are denied. “Archive” preserves history. Completion and reopening use server attribution.

The parent household export includes explicit Priority fields. It excludes personal readiness preferences. Goals are included in the same family export. Parent-only Businesses use a separate export file. Neither file has an automatic restore/import path.
