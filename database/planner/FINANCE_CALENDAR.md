# Parent Finance calendar connection — v145

The calendar projects current, active, parent-confirmed dated bill records from Finance. This is a read-only view: no calendar event is created and no payment is sent. Unconfirmed, historical, inactive, uncertain or incomplete records are omitted. Existing imported reference records must be reviewed before they appear.

Parents see the due date as an all-day Eastern-time entry, including the exact recorded amount and payment status. Paid/reconciled entries are marked paid and participate in the original calendar's completion filters. Midnight boundaries follow daylight-saving changes.

Review in Finance opens the source record, following its current revision. Changes belong in Finance; the calendar has no edit/cancel controls for these projections. Refresh picks up revisions without duplicate events.

Children do not request Finance records. The parent calendar also defensively filters Finance projections for non-adult contexts; existing database Finance RLS remains authoritative. Parent-only entries are excluded by the original Family-only calendar filter.

The original calendar receives these entries in memory. They are never persisted into private original event arrays or included in original private HTML/JSON recovery exports. No database migration or financial fact confirmation was performed for this connection.

Validation: synthetic unit checks cover eligibility, cents, duplicate IDs, non-mutation and DST boundaries; mocked original-OS browser checks cover all five calendar views, source-review routing, private-backup exclusion and the existing eleven-tab/mobile/recovery flow. Mocked shared-planner browser checks confirm a child calendar does not fetch Finance. These checks do not claim fresh ordinary-password or physical-device acceptance.
