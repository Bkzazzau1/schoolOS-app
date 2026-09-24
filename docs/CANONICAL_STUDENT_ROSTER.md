# Native App — Canonical Student Roster Contract

The Flutter application remains offline-first. It does not own the authoritative student roster or billing count.

## Write path

Administrator changes are stored immediately in encrypted local SQLite and queued in the durable sync outbox:

```text
Admissions / Registration / Lifecycle UI
    -> encrypted local record
    -> durable outbox
    -> SchoolOS sync API
    -> server validation
    -> canonical student domain
```

The live server owns canonical activation and billing. A local record marked Active or Completed is still queued until the server accepts it.

## Live-mode directory

When a real backend is configured, the Administrator Students directory is derived from server-synced `student_registration` records plus synced lifecycle history. Website/demo student-directory seed rows are ignored in live mode, including seed rows left on a device from an earlier demo session.

Standalone demo mode keeps the original website/demo data.

## New registration drafts

Backend-connected direct registration no longer starts from the website sample student. It receives a fresh local registration id, admission number and student id suitable for offline work. The server still validates uniqueness before canonical activation.

Applicant-based registration continues to derive stable provisional identifiers from the admissions reference.

## Server acceptance boundary

The native confirmation text deliberately distinguishes local completion from canonical activation:

- draft saved locally / queued;
- registration completion saved locally / queued;
- server acceptance creates the canonical Student and active Enrollment;
- only that canonical active Enrollment becomes billable.

This preserves the global SchoolOS rule that **queued does not mean synced, approved, released or server-accepted**.

## Lifecycle

Class changes, promotions and transfers continue to work offline through the lifecycle outbox. The server appends canonical enrollment history rather than rewriting old class placement. Transfer pending remains billable until the server accepts transfer completion.

Graduation through Alumni Management is handled server-side and also closes the canonical enrollment when a matching canonical student is found.
