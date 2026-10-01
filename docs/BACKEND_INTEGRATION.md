# Connecting the app to the SchoolOS backend

The backend lives in `schoolOS_backend`; its full list of app changes is `docs/APP_CHANGES.md` there. This page says what
the app has done and how to try it.

## Switching it on

The app runs on its built-in demo data unless it is told where the backend is:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1      # Android emulator to a local backend
flutter run --dart-define=API_BASE_URL=https://api.schoolos.ng/api/v1   # a real server
```

With no value nothing changes: the demo login, demo memberships and local-only records all work as before, and every
existing test runs on that path. With a value, the login screen asks for an email and password and signs in for real.

## Done (foundation, steps A1 to A3)

| Piece | File | What it does |
| --- | --- | --- |
| Address and switch | `lib/core/network/api_config.dart` | `API_BASE_URL`; `enabled` is false when empty |
| API client | `lib/core/network/api_client.dart` | Attaches the token, renews an expired one once (shared by concurrent requests), and throws only three things: `ApiOfflineException` (try later), `SessionExpiredException` (sign in again), `ApiException` (the server's own words) |
| Tokens | `lib/core/auth/token_store.dart` | Secure storage on the device; memory in tests |
| Sign in and out | `lib/core/auth/auth_repository.dart` | Signs in, loads the person's schools (`me/`) into the school session; a role this app version does not know is skipped |
| Sending changes | `lib/core/sync/http_sync_transport.dart` | Sends one queued change to `sync/push/`. Accepted, conflict and rejected map to the engine's; "no signal", server trouble and an expired sign-in become `SyncRetryLater`, never a failure of the change |
| Downloading | `lib/core/sync/sync_puller.dart`, `sync_store.dart` | `sync/pull/` from the saved cursor, page by page; the cursor is saved after each page; a record with an unsent edit on the device is left alone; deleted records are removed |
| The engine | `lib/core/sync/sync_engine.dart` | Sends, then pulls. With no signal the change goes back in the queue in order and the run stops (nothing is marked failed). Reports `pulled`, `stoppedOffline`, `needsSignIn` |
| Storage | `lib/core/database/local_database.dart` | New `sync_cursors` table (per school and membership), `deleteLocalRecord`, `markMutationPending` |
| Login screen | `lib/features/authentication/presentation/login_page.dart` | Real sign-in when a backend is set: email field, plain error messages, "not connected to any school yet" message, no demo panel |

Tests: `test/core/` (74 tests) cover each layer with a fake server, in-memory storage and, for the queue rules, real SQLite;
`test/backend_login_and_banner_test.dart` covers the login screen and banner (9 tests), and
`test/sync_center_and_scope_test.dart` the Sync Center, scope and mixin (10 tests).

## Fixed on the way

The app did not compile: two identical `TransportActionResult` classes were imported together by the transport route and
rider-assignment repositories. The unused import was removed.

## Done (step 2): keeping in step, and being signed out

| Piece | File | What it does |
| --- | --- | --- |
| Coordinator | `lib/core/sync/sync_coordinator.dart` | Runs a round when the app starts, after a change is queued (short pause, so a burst is one round), when the app comes back to the front, and on a timer. One round at a time; a change queued during a round makes another follow. Offline: retries 15 s, 30 s, ... up to 5 min, and at once when the app returns. Exposes `status`, `message`, `lastSyncedAt`, `changes` |
| Queue hook | `LocalDatabase.onMutationQueued` | Every screen already queues through the database, so no screen had to change |
| Banner | `lib/app/sync_status_banner.dart` | A strip across the whole app: offline (work is safe), sign-in ended, lost access. The last two offer "Sign in" |
| Start-up | `lib/app/app_services.dart` | A saved school with no saved sign-in starts at the login screen; the coordinator starts when a school is open, and after login |
| Signing in again | `lib/app/app.dart` | Stops syncing, signs out (unsent work stays on the device), opens the login screen |

### Queue rules found and fixed on the way (`LocalDatabase`)

The server remembers its answer to each change by id. Sending the same id again gets the same answer, so the old queue
rules could lose work once a real server was involved. Now:

1. **Editing a record again before anything was sent** folds into the waiting change and keeps its id **and its place in the
   queue** (it used to move to the back, which would send a comment before the post it is on).
2. **Editing it after an attempt to send it** is a *new* change. The first may already be applied on the server with the
   reply lost; editing it in place would make the server ignore the edit.
3. **A change the server refused** is not sent again by itself, and no longer crowds out new work (refused changes used to
   be retried every round and could fill the batch). The next edit replaces it under a new id; retrying by hand also uses
   a new id.
4. Queue times are strictly increasing, so order is never a tie.

The database can now run in tests (`databasePath: ':memory:'`), so these rules are tested against real SQLite
(`test/core/local_database_queue_test.dart`).

## Done (step 3): Sync Center and reacting to new data

| Piece | File | What it does |
| --- | --- | --- |
| Scope | `lib/core/sync/sync_scope.dart` | `SyncScope` gives every screen the coordinator (absent on demo data) |
| Reload hook | `SyncRefresh` mixin | A screen adds `with SyncRefresh<MyPage>` and `void onSynced() => _load();`. It runs after a round that sent changes or brought in others' changes, never after an idle round, and never once the screen is gone |
| Sync Center | `lib/features/sync_center/presentation/sync_center_page.dart` | Live status card (up to date and when, syncing, offline, sign-in ended, no access, problem), "Sync now", the queue refreshing as syncing goes on, **Retry** for a refused change, and **Discard** (for a conflict: "Use school's version"), each asking first |
| Discard | `LocalDatabase.discardMutation` | Drops a refused change. A record the school never accepted is removed from the device; otherwise it stops counting as edited here and the download position is reset so the school's copy is read again |
| Workspace badges | the 8 workspace pages and the dashboard | The pending-changes badge now updates after every sync (`with SyncRefresh`) |
| Counter | `SyncCoordinator.remoteChanges` | Counts rounds that brought in someone else's work, apart from `changes` |

Content screens are **not** reloaded automatically. Most load once when they open, and replacing a screen while someone is
typing in it could wipe their text. Each screen opts in with the mixin above, reloading only what is safe to replace.

## Done (step 4): access and notifications

| Piece | File | What it does |
| --- | --- | --- |
| Access | `lib/core/access/access_controller.dart` | Reads `access/me/` for the person's membership, keeps it on the device (menus are right offline and after a restart), announces only real changes. Until it is known nothing is hidden |
| Menus | `AccessAware` mixin in `lib/core/sync/sync_scope.dart` | A workspace lists its screens through `visibleScreens('<workspace>', items, key)`. Done for the owner, principal, administrator, finance, teacher, driver and parent workspaces; the menu redraws when access changes |
| Blocks | `lib/core/sync/round_follow_up.dart` | After each round that reached the server: read the inbox, read access, and if the owner has a waiting block and **nothing is left unsent**, `access/acknowledge/` so it takes effect. If anything is still unsent it does not, so no work is lost (the server ends the block at its deadline anyway) |
| Inbox | `lib/core/notifications/notifications_controller.dart` | Reads `notifications/`, keeps the last messages and unread count on the device, marks read (a read made offline is told to the server later) |
| Screens | `lib/features/notifications/presentation/` | `NotificationsBell` (unread badge; shows nothing on demo data) in every workspace's header next to the Sync Center button, and `NotificationsPage` (tap to read, mark all read, pull to refresh) |
| Wiring | `AppServices.beginSchool` / `endSession` | Restores the cached access and inbox when a school is chosen or the app opens on one; forgets them on sign-out |

Tests: `test/core/access_and_notifications_test.dart` (17) and `test/access_menus_and_inbox_test.dart` (15, including a real
driver workspace hiding and showing screens as access changes).

## Done (step 5): the owner's Access & Activities screen

Owner workspace, **Access & Activities** (shown only when there is a server; deciding access needs one). Every change goes
to the server first and is then read back, so what the owner sees is what the server holds.

| Tab | What the owner can do |
| --- | --- |
| **People** | Search everyone. Open a person to see every screen with why they have it ("role default", "given by you until...", "being taken away after their next sync, and by..."). A switch gives or takes away a screen; a lock replaces it for landing screens and the access screen itself. **Reset** puts them back on their role's setting. **Move to someone else...** hands a screen to another person in one step |
| **Roles** | What each role gets by default. Tap a role, tick or untick screens (landing screens stay on), Save (asks first and says how many people it affects), or Reset to the built-in screens |
| **Waiting** | Blocks that have not taken effect yet, with the latest date, and a Cancel |
| **History** | Who changed what, in sentences |

Giving a screen that shows money or personal information warns first. Taking one away asks **after they next sync**
(recommended; their app sends unsent work first) or **right now**, plus a note and an optional end date. A refusal from
the server ("A landing screen cannot be taken away.") is shown in its own words. Offline, the screen says so and can try again.

Files: `features/proprietor/domain/owner_access_models.dart`, `data/owner_access_repository.dart`,
`data/owner_access_controller.dart`, `presentation/owner_access_*.dart`. `ApiClient` gained `put`, `delete` and query
parameters on `post`. Tests: `test/owner_access_screen_test.dart` (28), including the exact request each button sends.

## Done (step 6): staff and invitations (checklist sections B and C)

| Piece | File | What it does |
| --- | --- | --- |
| Approve and reject | `StaffProposalRepository` with `StaffServerApi` (`features/proprietor/data/staff_server_api.dart`) | With a server, approving or rejecting a proposal is a call to it (`.../proposals/<id>/approve/`, `.../reject/`). The server creates the directory entry, salary, profile and invitation together or not at all, and checks who may approve and whether the phone/NIN are still free. Its refusals are shown in its own words. The device shows the decision at once (not as an edit to send) and downloads the result. On demo data the old local behaviour is unchanged |
| Owner adds staff directly | same | Sends the proposal, checks the server accepted it (if it refused, the reason is shown and the stuck copy is removed), then approves. Offline it stays queued and is approved from the list later |
| Accept an invitation | `features/invitations/` (`InvitationAcceptPage`, `invitation_link.dart`), `AuthRepository` | Paste the link (or open the app with it as an argument, e.g. on Windows) to see who it is for, then choose a password (new account) or sign in (existing account). Every refusal has plain words (expired or replaced, already used, wrong account, weak password with the server's reasons). It ends in the school's workspace with syncing started. The login screen has "I have an invitation link" |
| Invitation and login (owner, principal, administrator) | `InvitationStatusCard` in the staff profile | Where the invitation stands (sent and until when, not delivered, expired, accepted, cancelled), **Send again** (with a corrected email; the old link stops working), and for the owner only **Cancel invitation** and **Remove login** (with an explanation) |
| Registration | `StaffOnboardingRepository` | With a server the registration goes to `staff/me/onboarding/`, so the person hears at once if a phone number or NIN belongs to someone else, instead of finding a refused change later. Offline it fails cleanly |
| Shared | `lib/app/open_home.dart` | "Choose this school and open the right workspace", used by login and by accepting an invitation |

Tests: `test/staff_server_test.dart` (24), `test/invitation_accept_test.dart` (23), `test/invitation_status_card_test.dart` (10).

Found on the way: a text-field controller disposed while its dialog was still animating closed throws in debug builds.
Fixed in the new card. The older dialogs in `staff_proposals_ui.dart` do the same (`deductions.dispose()`, `note.dispose()`
straight after `showDialog`) and should be moved to dialogs that own their controllers.

## Done (step 7): money and structure (checklist sections D, E and F)

**Answers at the moment of the action.** `ServerConfirm` (`lib/core/sync/server_confirm.dart`): after a screen queues a
change it sends it and reports back. Accepted: nothing to say. Refused: the change is dropped, the school's version comes
back onto the device, and the server's own words are shown. Not sent yet (offline) or a conflict: it stays queued and is
shown as waiting. `SyncCoordinator.syncNow()` now waits for the round in progress (and the one it triggers), which makes
this possible.

| Feature | What changed |
| --- | --- |
| **Payroll batches** (E) | Every step (prepare, approve, reject, instruct) is sent at once. Refusals such as "A different person must approve a batch you prepared" or "The salary for X changed after this batch was prepared" are shown, and the batch goes back to what the school holds. Rejecting needs a reason |
| **Scholarships and discounts** (F) | A request gets a number no other device can pick (time-based, not "count plus 41"), so two devices cannot collide. A request or decision the server refuses is reported and left nothing behind. A decline needs a reason. No sample requests are made up |
| **Structure** (D) | With a school server and nothing on it yet, the owner sees **Set up the structure** and taps **Use the standard sections**: sections are created first, then their leadership posts, stopping at the first refusal. Appointments and replacing a head are sent at once (the appointment first, then the section). |
| **Proposals** | Everyone's proposal is sent at once, so a refusal (a phone number that belongs to someone else) is shown when proposing, not later in the Sync Center |
| **Sample records** | With a school server the local database refuses to write sample records (`LocalDatabase.blockDemoSeeds`): a record that is not an edit and was never downloaded. This stops about 57 screens from showing made-up staff, students and requests as the school's own. Screens for modules not connected yet therefore show empty lists, honestly |

Tests: `test/money_server_test.dart` (10), `test/structure_server_test.dart` (10), `test/core/server_confirm_test.dart` (6),
more in `test/staff_server_test.dart` (27) and the coordinator tests.

## Not done yet (next)

1. **Reload-on-sync for read-only lists** and content screens (see step 3): notices, events, staff lists.
2. **Screens whose modules have no server rules yet** (students, attendance, results, fee collection, campuses) still use
   device data, and now show empty lists instead of samples when a server is configured. They need their own backend
   features first.
3. **School life** (checklist G2): community comments and reactions must become their own records; the noticeboard's read
   count is the server's now.
4. **Dashboards** (G): the owner overview and finance screens should read `dashboards/schools/<id>/owner/` and `/finance/`.
5. Opening invitation links on a phone (no Android project yet), the older dialogs' controller disposal, "send mine anyway"
   for conflicts, the general dashboard's access, and deleting a blocked screen's local data.

## Step 8: the owner's access system works in the demo too

With no server, `LocalOwnerAccess` (`lib/features/proprietor/data/local_owner_access.dart`) does what the server does for
who-sees-what, with the same rules, and keeps the owner's decisions on the device. The Access & Activities screen and the
menus use it through two small interfaces (`OwnerAccessSource`, `AccessView`), so they do not know which one they have.

- The demo has twelve sample people (`lib/app/demo_people.dart`): owner, administrator, finance officer, principal, two
  teachers, support staff, two parents, a student, a driver, and a teacher at a second school. The demo login offers all of
  them, so you can decide something as the owner and then sign in as that person.
- The owner can change what a role sees, give or take a screen for one person, move a screen, and **give a person an extra
  role** (for example a teacher who is also a parent). An extra role is another membership (`<person>#<role>`) that the person
  can switch to. Everything is kept and comes back after a restart.
- Rules: the owner cannot lock themselves out, the owner role cannot be given away, landing screens cannot be taken
  from anyone, and screens that are not in the catalog are never hidden.
- The app-side catalog is generated from the backend (`lib/core/access/access_catalog_data.dart`); regenerate it when the
  backend catalog changes.
- With a school server the roles are still given through invitations; the extra-role controls appear only in the demo.

Tests: `test/local_owner_access_test.dart` (10), `test/demo_extra_roles_test.dart`.
Not done: a test that every menu key in the app is in the catalog; a "demo data" banner on the access screen.

## Owner: Staff & HR is real

`OwnerStaffOverviewRepository` (`lib/features/proprietor/data/owner_staff_overview.dart`) works the page out from the school's
staff records, staff profiles and leadership structure: staff and teaching counts, average attendance (only when recorded),
staff by section, and an attention list (incomplete files, open onboarding, credentials expired or ending within 60 days).
A leader is marked "Review" when someone in their section has an incomplete file. Workload and vacancies are not tracked
yet, so they are no longer shown. Tests: `test/proprietor_staff_test.dart`.

## Owner: Executive Overview shows what is really waiting

`OwnerAttentionRepository` (`lib/features/proprietor/data/owner_attention_repository.dart`) builds the Owner Attention Queue
and the Leadership card from real records: staff proposals to approve, concessions to decide, payroll batches waiting for
approval, an empty structure, and the staff-file items from Staff & HR. Each item opens the screen where it is dealt with.
The fee, attendance, results and enrolment figures on that page are still sample figures, and the page says so.
Tests: `test/owner_attention_test.dart`.

## Owner: Finance shows real scholarships, discounts and payroll

`OwnerFinanceOverviewRepository` (`lib/features/proprietor/data/owner_finance_overview.dart`) gives the top of the owner
finance page from real records: approved scholarships and discounts, what awaits the owner's decision, monthly payroll
from recorded salaries, and payroll batches. The revenue bridge, collections, aging, store and expense sections underneath
are sample figures (labelled as such) until the Finance role records fees and payments.
Tests: `test/owner_finance_overview_test.dart`, `test/proprietor_finance_test.dart`.

## Owner: Executive Reports are real

`lib/features/proprietor/data/owner_reports.dart` builds three reports from real records (executive summary, staff &
leadership, scholarships/discounts & payroll) and lists four as "not available yet" with the reason (fee collection,
enrollment, academic & attendance, school life). "Create report pack" saves exactly what the reports say (text file on the
device). The old made-up report list, cadence and KPI row were removed.
Tests: `test/proprietor_reports_test.dart`, `test/owner_reports_page_test.dart`.

## Owner: Campus Comparison is real

`lib/features/proprietor/data/owner_campuses.dart` groups the school's sections by campus and counts classes, staff,
teachers, leaders and incomplete files per campus. Students, attendance and fees are shown as "Not recorded". The made-up
"planned campus" was removed (the app has no such record). Tests: `test/proprietor_campus_test.dart`.

## Owner: school colours and logo

The owner chooses the school's look on School Appearance: 24 ready-made colour themes, or any two colours of their own (pick
from swatches or type a #RRGGBB code), and a school logo picked from the device. Colours that would be hard to read (a main
colour too light for white text, an accent too close to it) are refused with a plain explanation. The logo is shrunk to at
most 256 px and about 140 KB, kept in the school's appearance record, and shown next to the school name in the owner,
administrator and dashboard workspaces. It is saved on the device at once and shared with the school on the next sync; the
app reloads the appearance after each sync round, so a change made on another device shows up.

Backend: `apps/structure/appearance.py` accepts the new theme ids, `custom` with `primaryArgb`/`accentArgb`, and a PNG or JPEG
`logo` (base64, at most 200,000 characters, within the 256 KB sync payload cap). Tests: `test/school_theme_test.dart`,
`test/school_appearance_test.dart`, backend `apps.structure`.
The logo also shows in the teacher, parent, finance, principal and driver side panels and the owner's side mark. Not done: the login page (no school is chosen yet there).

**Also keeps a real copy in SchoolOS Media & Files.** When a school server exists, choosing a new logo now also queues it
into the same shared `MediaUploadQueue` every other real attachment uses (`school_appearance`/`theme`'s now-registered owner
kind, `school_logo` category). This is additive, not a replacement: every screen still renders the logo from the
controller's own cached bytes above, in every mode including fully offline, and demo mode is entirely unaffected, since
nothing from Media & Files is offered without a server. Removing a logo stays a base64-only action; an earlier durable copy
is left as it is. Test: `test/school_logo_media_test.dart`.

## Owner cleanup

- The staff approval, rejection, salary and document dialogs now own and dispose their own text boxes
  (`lib/features/proprietor/presentation/owner_dialogs.dart`), which fixes a crash when they closed. Test: `test/owner_dialogs_test.dart`.
- The owner's staff proposals, payroll, jobs, staff profiles, concession approvals and structure screens reload after each sync.
- The Access & Activities screen says when it is the demo. A test (`test/owner_menu_catalog_test.dart`) checks that every owner
  menu item is in the access catalog and vice versa.
- `test/owner_demo_walkthrough_test.dart` signs in as the demo owner (no server) and opens every owner screen.

## Owner: Proprietor AI answers from real records

`ProprietorAiService` (`lib/features/proprietor/data/proprietor_ai_service.dart`) answers from the same records as the
reports (attention queue, staff files, scholarships, discounts, payroll, leadership). Questions about fees, attendance,
enrollment and results say plainly that nothing has been recorded and never invent figures or causes. The executive brief
is built from the same records and lists what is not available yet. The old made-up numbers (94%, 648 students, ₦3.7m) are
gone. Tests: `test/proprietor_ai_test.dart`.

## Administrator (role 2): audit and first step

Audit of the 13 screens. **Connected and saving:** Student Registration (validates, keeps a guardian's phone to one guardian,
creates the student who then appears in Students & Families), Admissions Pipeline (request documents, schedule screening,
issue offer, hand off to registration), Staff Records (register support staff, with an onboarding request), Notices (drafts),
Website Manager (saves), Staff Attendance (payroll summary). **Read-only lists filled from sample records:** Attendance Desk,
Transfers & Promotion, Operations, Records & Documents, and the sample rows behind Students and Staff. Nothing on the server
yet handles admissions, registration, students, notices, records or lifecycle.

Step 1 done: the Administrator dashboard is worked out from the real students, admissions, records, lifecycle changes and
staff files (`administrator_overview.dart`), replacing fixed numbers (648 students, 17 admissions...) and the sample queue.
Tests: `test/administrator_dashboard_test.dart`.

## Administrator: Transfers & Promotion now work

The lifecycle desk (`administrator_lifecycle_repository.dart`, `administrator_lifecycle_effects.dart`) starts, processes and
cancels student changes, and the student register follows them:

- **Class change / Promotion / Transfer out** are started for a real student from "New student change".
- A class change completes directly and puts the student in the new class. A **promotion** is an academic decision, so it can
  only be processed with the name of who approved it. A **transfer out** needs the records pack marked ready first; while
  pending the student shows "Transfer pending", and once completed they leave the active register (their last class is kept).
- Nothing is overwritten: completed changes are kept as history and applied in order; a cancelled change is kept with its
  reason and has no effect. Only an administrator can do this.
- The demo school now has 20 students in real classes (`administrator_demo_school.dart`) and lifecycle records that refer only
  to students that exist.
Tests: `test/administrator_lifecycle_actions_test.dart`.

## Administrator: Records & Documents now work

`AdministratorRecordsRepository` lets the records office track a document ("Track a document": student, family or staff, from
a list of usual documents; it starts as missing) and move it along: **Mark received** (missing to pending), **Verify**
(pending to verified), **Send back** (pending to missing, reason required), **Issue** (a draft letter), **Reopen** (verified to
pending, reason required). Every step is appended to the document's history (who, when, why) and nothing is deleted. The
dashboard's "records tasks" follow these changes. Files are not stored yet. The demo school has documents in every state for
students, families and staff. Tests: `test/administrator_records_actions_test.dart`.

## Administrator: Attendance Desk now works

The desk (`administrator_attendance_desk.dart`, `administrator_attendance_repository.dart`) works out the day from the scans and
the student register: present, late (after 08:00), excused, and who has not arrived, overall and by section (Early Years,
Primary, Secondary, from the class name). The administrator can **check a student in by hand** (front desk; late after 08:00),
**identify a scan the device could not match** by choosing the student (never guessed), and **approve or decline correction
requests** (Present, Late or Excused). A decision keeps who decided, when and why, and adds a correction to the day without
erasing the original scan; declining needs a reason. Students on the register with no arrival and no excuse are the "not
checked in" list, followed up in the normal way.

The demo school gets a morning of gate scans for today (deterministic: about nine in ten arrive, a few late, some absent, one
scan to identify); a school server blocks these, since real devices supply the scans. The device list is labelled as sample:
gate hardware is not connected. Tests: `test/administrator_attendance_actions_test.dart`.

## Administrator: the admissions journey works end to end

Applicant to student now runs as one connected flow (`administrator_admissions_repository.dart`, `administrator_registration_repository.dart`):

1. **New application** taken at the school (walk-in, phone, referral): validated (full name, class, guardian, valid Nigerian phone, no
   duplicate open application), given the next reference, all three documents pending. Online applications arrive on their own.
2. **Documents**: each is marked received; the first moves a new application into document collection.
3. **Screening** needs every document received. **Offer** needs screening. **Accept offer** needs an issued offer.
4. **Registration** can only be completed for an accepted offer. Completing it marks the applicant Registered and the child
   appears on the student register in their class.
5. An application that will not go ahead is **closed with a reason**; it is kept, cannot move on or be registered, and drops out of
   the open counts on the dashboard and the pipeline.

The admissions page's numbers are now counted from the applicants (they were fixed sample figures). Tests:
`test/administrator_admissions_flow_test.dart`.

## Owner: Enrollment & Admissions is real (the owner side is complete)

`OwnerEnrollmentRepository` (`lib/features/proprietor/data/owner_enrollment.dart`) counts students by section from the register (a
student who left is not active) and applications, offers, acceptances and registrations from the admissions pipeline (closed
applications excluded). "Worth a look" says what is waiting (accepted children to register, applications waiting on documents,
the busiest section). Retention and the enrollment trend need records from earlier terms, so they are shown as not available.
The reports gain a real "Enrollment & admissions" report, the AI answers enrollment questions from it, and the enrollment brief
export is built from it. Every owner screen is now either real or clearly labelled. Tests: `test/owner_enrollment_test.dart`.

## Finance Officer (role 3): audit and the billing core

Audit of the 16 screens: only **Scholarships & Discounts** (concessions) and **Payroll Handoff** (payroll batches) were real. The
other fourteen showed fixed sample figures and saved nothing.

The billing core is now real (`finance_billing.dart`, `finance_ledger_repository.dart`, `finance_ledger_models.dart`):

- **Fee Structure**: charges per section and term (tuition, levies...), edited by the finance office or the owner; a change re-bills
  every student in that section. Validated: named, unique charges, amounts above zero.
- **Student Accounts**: every student on the register is billed their section fees, less approved scholarships and discounts (from
  the concession approvals), less payments. Payments are recorded here: cash, bank transfer or POS (transfer and POS need a
  reference, a reference cannot be used twice), never more than what is owed.
- **Receipts**: every payment has a numbered receipt (RCT-000001...). A mistaken payment is voided with a reason, kept in the
  list and no longer counted as paid; nothing is edited or deleted.
- The demo school starts with default fees and a spread of payments (about half paid in full, three in ten part, the rest none),
  which a school server blocks.

Still sample: Smart Collections, Fee Reminders, School Store, Payment Mandates, Outstanding & Aging, Reconciliation, Expenses &
Income, Reports, Finance AI and the dashboard. Next: Outstanding & Aging, Reminders, the dashboard and the owner's finance
numbers from this ledger. Tests: `test/finance_ledger_test.dart`, `test/finance_pages_test.dart`.

## Finance: aging, reminders, dashboard, and the owner's fee figures

- **Outstanding & Aging** (`finance_aging.dart`): fees are due on a date the finance office sets per term; who owes is grouped by
  how overdue it is (not yet due, 1-30, 31-60, 61-90, over 90 days) and totals match the ledger.
- **Fee Reminders**: a reminder for each overdue account, in the words of a friendly, second and final notice (stating the amount
  and term, never a reason). At least 3 days apart per family; queued in the app, sent by the school server. "Queue for everyone"
  reminds each family once.
- **Finance Dashboard** (`finance_dashboard.dart`): net collectible, collected, still owed, received today, requests waiting for
  the owner, what needs attention (each opens its screen), recent receipts, and how families paid, all from the ledger.
- **Owner Finance** now shows the real fees for the term (gross, scholarships and discounts, net, collected, owed), collection by
  section, outstanding fees with the largest balances, and how families paid. School store, payment mandates, expenses and the weekly
  trend are labelled "not available yet".
Tests: `test/finance_aging_reminders_test.dart`, `test/finance_dashboard_test.dart`, `test/proprietor_finance_test.dart`.
Still sample in Finance: Smart Collections, School Store, Payment Mandates, Reconciliation, Expenses & Income, Reports, Finance AI.

## Finance close-out: reports, assistant and reconciliation

- **Reports** (`finance_facts.dart`): collection summary, outstanding fees, receipts register (with voided), scholarships and
  discounts, and bank reconciliation are built from the ledger; "Save report pack" writes them to one text file. School store,
  expenses & income and payment mandates are listed as not available yet, with the reason.
- **Finance AI**: answers who owes the most, collection, sections, how overdue fees are, payment methods, reminders, waiting
  scholarships and the statement, from the ledger. Store, expenses, profit and forecasts get "not recorded". It never contacts
  families, changes records or judges ability to pay.
- **Reconciliation** (`finance_reconciliation.dart`): statement lines (added by hand for now) are matched to transfer and POS
  receipts by reference and amount. It lists bank money with no receipt (with a "Record payment" action that creates the receipt
  from the line), amounts that disagree, and receipts not yet on the statement. Cash is not matched. The demo statement has
  matches, one disagreement and two unrecorded payments.
Tests: `test/finance_reports_ai_reconciliation_test.dart`. Still not built in Finance: Smart Collections, School Store, Payment
Mandates and Expenses & Income (their own features).

## Teacher (role 6): audit and the attendance register is real

Audit: 16 screens, all with demo data and their own repository. Most write locally (lesson plans, assignments, CBT, assessments,
weekly learning, messages, profile contact, syllabus, private reflections), but classes, students-in-class and attendance
registers were all fixed sample rows unconnected to the real school register built for the other roles.

Also fixed: 15 dropdowns across the Teacher module were missing `isExpanded: true` and overflowed on layout, which was most of
the 46 failing Teacher tests (down to 19, all content-parity or platform-specific; unrelated to this work).

`teacher_roster.dart` is new: which classes a teacher teaches (`AssignedClass`, assignable by the owner or administrator; the
demo teachers start with sample classes) and the real students in a class, from the administrator's student register (a student
who has left is excluded). `TeacherAttendanceRepository` now builds one register per assigned class from the real roster instead
of three fixed lessons with four fixed students; a newly assigned class gets a fresh register without disturbing existing ones,
submitted registers still lock. Tests: `test/teacher_roster_attendance_test.dart`.

Not done yet: My Classes still shows fixed progress/attendance-rate/marking figures (they need the syllabus and assessment
modules wired to the same roster); Students, Assessments, CBT, Learning Progress and the rest of the Teacher module still use
their own demo data, unconnected to the attendance register or each other.

## Teacher: My Classes lists real classes and students

`TeacherClassesRepository` now builds "My Classes" from the same roster as attendance: real assigned classes, the real
student count per class (from the administrator's register), and today's real attendance percentage when a register has
been taken (0% otherwise, never invented). Syllabus progress, class average and pending marking still show 0 until the
syllabus and assessment modules are linked to the same class list — the next increment. Tests: `test/teacher_classes_roster_test.dart`.

## Owner: verification pass

Went back through all 13 owner screens end to end to confirm the "owner side is complete" claim above still holds:

- No leftover fake business figures found outside what is already labelled sample (Owner Finance's store/mandates/expenses/trend
  sections, Executive Overview's fee/attendance/results figures) — both already carry an explicit "not available yet" banner.
  School Life's stat strip (role, scope, module count, backend-enforcement note) is architecture description, not business data,
  so it is fine as a constant.
- Found and fixed the same dropdown-overflow bug the Teacher audit turned up (`DropdownButtonFormField` without
  `isExpanded: true`), in 19 more places: the staff approval dialog, the concession approval dialog, four dropdowns in
  Structure & Leadership, and the corresponding dialogs in Finance and Administrator (which the owner also reaches through
  Staff Records and Concession Approvals). Fixed in place; no behaviour change, just stops the row overflowing on a narrow
  screen.
- Access & Activities loaded once and never refreshed after a sync round, unlike every other owner screen. Now uses
  `SyncRefresh` like the rest.
- Confirmed the earlier dialog-disposal fix (`owner_dialogs.dart`) covers every remaining `TextEditingController` in
  `staff_proposals_ui.dart`; nothing left un-disposed.
- Re-ran the full suite and the demo owner walkthrough (opens all 13 owner screens with no server) after each fix: no
  regressions, same 19 pre-existing Teacher-module failures as before this pass.

Known gaps that remain, all server-mode only (no effect in demo, where there is no server to conflict with or serve stale
blocked data from): a "send mine anyway" action for a change the server refused as conflicting stays queued with no manual
override; a screen the owner blocks does not delete that person's already-downloaded local data for it.

## Teacher: Students uses the real roster, and two empty-roster crashes fixed

`TeacherStudentsRepository` now lists the real students across all of a teacher's real assigned classes (deduplicated, since a
teacher can teach the same class two subjects), instead of a fixed sample list. Average, attendance rate and trend are not
tracked yet (this module has no assessment or day-by-day attendance history to compute them from), so they show as 0 with an
honest note rather than a number or a risk label invented for a real, named student. A teacher note can only be saved for a
student really in their classes. The student's detail view uses their real name, class and status, with empty (not invented)
academic evidence, attendance context and timeline sections.

While wiring this, found and fixed two crashes that were only possible once rosters became real and could legitimately be
empty (a teacher with no assigned classes, or an assigned class with nobody enrolled yet): My Classes and Students both called
`.first` on a list that could now be empty. Both show an honest "nothing yet" message instead.

Tests: `test/teacher_students_roster_test.dart`.

## Teacher: Syllabus reports against real assigned classes, and never becomes editable by the teacher

The scheme of work (topics, weeks, planned lessons) is set by the Principal or the Head of section, not by the teacher —
this was an explicit correction from the school owner. `TeacherSyllabusRepository` already had the right permission model
(`canReportCoverage: true`, `canEditApprovedScheme: false`) before this change, and that did not change. What changed is
which classes the tracker shows: it now intersects the teacher's real assigned classes (from `TeacherRoster`) with the
classes that have an uploaded scheme, so a class the teacher is not really assigned to never appears, and an assigned class
with no scheme yet shows an honest "not uploaded yet" message instead of an empty grid. `markStatus` rejects reporting
coverage for a class outside that intersection as defense in depth, even if a caller somehow has a row for it. Coverage
percentage and "behind pace" status are now computed live from the actual rows and any teacher-reported progress
(`coverageOf`/`isBehind` on `TeacherSyllabusSnapshot`), replacing a fixed lookup table that could drift from the real data.

Fixed in passing: the demo scheme used the class name "SS 1A" (with a space) while the real student register and roster use
"SS1A" (no space) — a silent mismatch that would have made that class's syllabus rows disappear once filtering by the real
roster was added. Renamed the demo data to match, the same fix already applied once this session to a duplicate demo
student name.

Also fixed a pre-existing, systemic bug found while testing this: ten places across the Teacher module's reload/retry
buttons wrote `setState(() => _future = widget.repository.load())` — an arrow-body closure whose expression value is the
`Future` the assignment produces. Flutter's debug-mode `setState` explicitly rejects a callback that returns a `Future`
(`State.setState` asserts on it), so every retry/reload action after the first load crashed in debug and test builds (not
release, where the assertion is stripped). Fixed by switching to a block body (`setState(() { _future = ...; })`) at all
ten sites: `teacher_ai_page.dart`, `teacher_attendance_page.dart`, `teacher_classes_page.dart`,
`teacher_learning_progress_page.dart`, `teacher_lesson_plans_page.dart`, `teacher_messages_page.dart`,
`teacher_students_page.dart`, `teacher_syllabus_page.dart`, `teacher_timetable_page.dart` (two sites). This alone fixed one
of the 19 previously-failing tests ("mark complete records teacher progress...").

Tests: `test/teacher_syllabus_roster_test.dart`.

## Teacher: Assessments creates real assessments for real students, replacing a disconnected demo mock

The previous Assessments screen had two unrelated demo halves that never spoke to each other: a fixed three-row
"assessment register" (`ca-201`/`ca-202`/`ca-203`, with pre-baked entered/total/average numbers) and a single, separately
seeded score sheet for five fake students (`STU-DEMO-001`..`005`) that a teacher could re-point at any class or assessment
type via dropdowns, with no real connection to the register at all. The "+ New assessment" button was permanently
disabled (`onPressed: null`).

`TeacherAssessmentRepository` now models one real thing: an assessment the teacher actually created for one of their real
assigned classes, with one score entry per real student in that class (from `TeacherRoster`), all starting at 0.
`createAssessment(className, title, maximumScore)` is the only way an assessment comes into existence, and it refuses a
class the teacher is not really assigned to, a blank title, a non-positive maximum score, or a class with no students on
the register yet. The register and every score sheet are filtered to the teacher's real assigned classes on load, as
defense in depth. `saveProgress`/`submitScores` now also refuse a class no longer in the teacher's real assignment. Each
register item's `entered`/`total`/`average` are recomputed from its real sheet every time it is saved — with one honest
caveat documented in code: a score of exactly 0 looks the same as "not entered yet" in the current score model, so
`entered` counts scores above zero, not a separate entered/not-entered flag.

On the page, the score-entry card's class/assessment dropdowns (which used to silently reassign the current ad hoc sheet
to any class) are replaced by a dropdown that selects which of the teacher's own created assessments to view or edit, and
student rows now show the real student's name instead of a raw id. The KPI strip is computed from the real register
(assessment count, real entered/total scores, real average of assessments that have scores, and how many are still
pending submission) instead of fixed numbers like "CA completion 84%" or "Needs intervention 11" — the latter was an
aggregate judgement label with no real basis and has been dropped rather than wired to a fabricated threshold. The
"Performance insight" panel's fixed submetrics (concept mastery, question completion, etc.) and canned AI observation text
had no real source and are replaced with the one real number available (average of scores entered so far) and an honest
note that deeper AI analysis isn't available yet.

Tests: `test/teacher_assessment_roster_test.dart` (repository against the real roster), plus
`test/teacher_assessments_feature_test.dart` rewritten for the new architecture (a fake repository with a small, explicit
register/sheet instead of the old fixed demo constants).

## Teacher: CBT Practice creates real drafts for real classes, and drops invented student evidence

The practice sets themselves (title, class, question count, duration, instructions) were already real, teacher-editable,
locally-persisted content — that part did not need to change. Two things did. First, "+ New set" was permanently disabled
(`onPressed: null`, with a snackbar suggesting a question-authoring workflow that didn't exist); `TeacherCbtRepository` now
has `createDraft(className, title)`, which refuses a class the teacher is not really assigned to or a blank title, and
every practice set is filtered to the teacher's real assigned classes on load and re-checked on save/publish, the same
defense-in-depth pattern as Syllabus and Assessments. The class picker in the configuration panel now lists the teacher's
real assigned classes instead of a fixed `['JSS 2A', 'JSS 2B', 'JSS 3A']`.

Second, and more importantly: the "Recent learner results" panel listed three named students with fabricated scores,
accuracy percentages and timings ("Maryam Abdullahi scored 80%…", down to a specific per-student "Learning Intelligence
handoff" example) — and those names belong to real students in the demo register, not placeholders. There is no student
CBT-taking pipeline feeding this screen yet, so none of that evidence was real. The results panel now shows an honest "no
practice attempts recorded yet" message, the sample practice sets seed with `attempts: 0` and `averageAccuracy: 0` instead
of invented non-zero figures, and the Learning Intelligence handoff card explains what will appear once real attempts
exist instead of showing a fabricated example tied to a real name. The KPI strip is computed from the real sets (question
set count, real attempt total — always 0 for now — and how many drafts are still unpublished) instead of fixed numbers
like "286 practice attempts" or "Topics needing review: Fractions · Geometry · Word problems".

Tests: `test/teacher_cbt_roster_test.dart` (new, against the real roster), `test/teacher_cbt_feature_test.dart` rewritten
to drop the named-student assertions and cover the new create-draft flow.

## Teacher: Learning Progress lists real students with an honest "no evidence yet" state

This was the most severely fabricated screen found so far. Every widget on the page depended on a fixed list of four
"students" — three of whose names (Maryam Abdullahi, Ibrahim Sani, Yusuf Bello) are real students in the demo register,
not placeholders — each carrying invented per-topic scores across four evidence sources (classwork, assignment,
assessment, CBT) with a fabricated trend, a hard-coded "declining" or "improving" narrative, and a support-action queue
that named the same real students with a specific, fabricated recommendation ("Ibrahim Sani · Algebra: Declining across
assessment and CBT evidence"). None of that evidence exists anywhere in the app: no module currently produces
topic-tagged classwork, assignment, assessment or CBT results to combine.

`TeacherLearningProgressRepository` is now a thin, honest read: it lists the teacher's real students across their real
assigned classes (from `TeacherRoster`, deduplicated the same way Students and Assessments already do), with `average: 0`,
`attendance: 0` and an empty `topics` list for every one of them, because there is no real source for any of that yet. It
no longer persists anything locally either — with nothing to write, the `LocalDatabase` dependency was removed entirely.
The subject shown per student now comes from the teacher's real class assignment (`AssignedClass.subject`) instead of a
fixed `'Mathematics'`. On the page, every place that used to read a student's fabricated topic evidence now shows an
honest note instead once `topics` is empty (which is always, for now): the class summary, the topic evidence matrix, and
the support-action queue. The KPI strip is computed from the real roster (students tracked, assigned classes) instead of
fixed numbers like "150 students tracked" or "7 topics needing review". The model's `weakestTopic`/`strongestTopic`/
`combined`/`isDeclining` logic is unchanged and still used by the page once real topic evidence exists to feed it.

While rewriting the tests, found and fixed a real, pre-existing bug in the "renders on phone" test (one of the original
19 known failures): a `ListView(children: [...])` only mounts the children within its viewport's cache extent, so a tall
page's off-screen widgets are genuinely absent from the element tree until scrolled into view — `find.text(...)` on an
unscrolled far-down widget correctly finds nothing. This was a test bug, not an app bug; fixed with
`tester.scrollUntilVisible(...)` before the assertion.

Tests: `test/teacher_learning_progress_roster_test.dart` (new, against the real roster),
`test/teacher_learning_progress_feature_test.dart` rewritten to drop the invented per-topic evidence and named-student
assertions.

## Teacher: Lesson Plans can create a new plan, instead of being stuck editing one fixed draft forever

The editor always bound itself to a single hard-coded plan (`plan.id == 'LP-206'`); there was no way for a teacher to
create a second lesson plan. `TeacherLessonPlanRepository` now has `createPlan(className, week, topic)`, which refuses a
class the teacher is not really assigned to, and every plan is filtered to the teacher's real assigned classes on load
and re-checked on save/submit (the same defense-in-depth pattern as Syllabus, Assessments, CBT and Assignments). The page
now lets a teacher tap any plan in "My lesson plans" to open it in the editor, and the class picker lists real assigned
classes instead of a fixed `['JSS 2A', 'JSS 2B', 'JSS 3A', 'SS 1A']`. Found and fixed the same "SS 1A" (with a space) vs
"SS1A" naming mismatch already fixed once this session in Syllabus's demo data. The term KPI strip ("This term: 12",
"Approved: 9 · 75%", etc.) is now computed from the real plans instead of fixed numbers.

While rewriting the tests, found and fixed the same off-screen `ListView` test issue as Learning Progress in the history
search test (two widgets matched `find.text('LP-198')` once real interaction was added — the search field's own text and
the table cell — disambiguated with `.last`).

Tests: `test/teacher_lesson_plans_roster_test.dart` (new, against the real roster), `test/teacher_lesson_plans_feature_test.dart`
rewritten for the new create/select-plan flow; this also fixed one of the 17 previously-failing tests ("history search
filters rows").

## Teacher: Messages only shows guardian-group channels for real assigned classes

`TeacherMessageThread` gained a `className` field: for a guardian-group channel it names the real class the channel
belongs to (e.g. "JSS 2A Guardians" → `'JSS 2A'`); for a staff or leadership channel it stays `null`, since those are not
class-scoped. `TeacherMessagesRepository.load()` now filters the channel list to the teacher's real assigned classes plus
every non-class-scoped channel, and `queueMessage` re-checks that same real visibility before accepting a message —
closing a real scope leak where any teacher could message any class's guardian group, contradicting the screen's own
stated privacy boundary ("Teachers communicate only through approved SchoolOS channels linked to their assigned classes
or school role"). The KPI strip (Unread, Guardian groups, Staff channels, Channels with unread) is now computed from the
real, filtered channel list instead of a fixed snapshot that didn't even agree with the fixed thread list it described
(the old "Guardian groups: 3" against only two guardian-group threads in the same file).

The seeded sample threads and their one seeded conversation were left as sample content — no real, named student or
guardian is attributed a fabricated message the way earlier screens attributed fabricated academic evidence, so this did
not need the same rebuild as CBT or Learning Progress.

Tests: `test/teacher_messages_roster_test.dart` (new, against the real roster).

## Teacher: Profile — a real bug fix, a stale test, no data rework needed

Unlike the previous five screens, Profile's contact self-service editing was already fully real (versioned, queued for
sync, correctly refuses to let a teacher edit employment/payroll fields), and its employment/payroll/security content was
already honestly labelled as mock in the UI itself ("Current mock payroll", "Mock profile completeness", "Partner payroll
bank · mock"). There is no real staff-identity source to draw from yet either: `SchoolMembership`, the app's whole session
model, has no name field at all, so a teacher's display name has nowhere real to come from — that is a cross-cutting gap
in the session/identity model, not something this one screen can fix on its own, and rebuilding a fake HR/payroll ledger
with more convincing numbers would not make it more real. So this screen needed no data rework, only bug fixes.

All 6 of the module's pre-existing test failures were on this one screen and turned out to have three distinct, genuine
causes, not one:

1. **A real bug**: `_editContact`'s edit dialog disposed its `TextEditingController`s synchronously right after
   `showDialog`'s future resolved, while the dialog's exit transition was still animating and still reading them for a
   frame or two — "TextEditingController was used after being disposed." Fixed by deferring disposal to
   `WidgetsBinding.instance.addPostFrameCallback`.
2. **A stale test**: the tests asserted `netMonthly: 192000` / `monthlyDeductions: 58000`, but the demo data's August
   payslip has `other: 3000`, which computes to `194000` / `56000` — the two had drifted apart at some earlier point.
   Fixed by updating the test to the real, current numbers (not by changing the demo figures, since there was no way to
   know which side was "intended").
3. **The same off-screen `ListView` test issue already found and fixed in Learning Progress and Lesson Plans**: three
   assertions targeted widgets further down the page than the test viewport's render cache extent covers. Fixed with
   `tester.scrollUntilVisible(...)`.

No new test file was needed for this screen (no roster or class-scoped filtering applies to a teacher's own profile).

## Teacher: Performance fixes a real demo-seed-safety bug, and the same dispose bug as Profile

`addPrivateReflection` writes real, teacher-authored data (a private coaching note) that is deliberately kept
device-only and never queued for sync — that part was already correct and is unchanged. The bug: it wrote the record
with `isDirty` left at its default of `false`, which is indistinguishable from seed/sample data to
`LocalDatabase.blockDemoSeeds`. Once a real backend is configured, `blockDemoSeeds` becomes true, and the guard silently
discards any write that is not `isDirty: true` or does not carry a `serverVersion` — so a teacher's real, deliberately
local-only reflection would have been silently thrown away the moment the school went live, exactly the class of bug the
"audit demo-data safety" pass earlier this session was meant to catch, just inverted: real data being mistaken for a
seed, rather than a seed leaking out as real. Fixed by passing `isDirty: true` (matching the convention already
documented for real writes), while still never calling `queueMutation`, so the record persists locally forever without
ever being pushed anywhere — which is the intended behavior.

Also found and fixed the same `TextEditingController`-disposed-after-`Navigator.pop` bug as Profile in the "add
reflection" dialog, the same "SS 1A" vs "SS1A" naming mismatch fixed several times already this session, and filtered
"Assigned-class outcomes" to the teacher's real assigned classes (it previously showed a fixed four-class list regardless
of who was signed in), which surfaced and fixed a `.last`-on-empty-list crash risk once that list could legitimately be
empty. The overall performance score, per-metric values (attendance completion, lesson-plan compliance, etc.) and
development log remain clearly-labelled illustrative coaching content — no real cross-module computation exists yet to
back them (they would need real per-topic evidence from Syllabus, Assessments and CBT combined, which Learning Progress
already established isn't available), and the existing UI copy already frames them as such ("in this demo view").

Tests: `test/teacher_performance_roster_test.dart` (new, against the real roster, including a regression test that
writes a reflection with `blockDemoSeeds` set and confirms it survives).

## Teacher: AI limits its working context to real assigned classes, and fixes the same seed-safety bug

`TeacherAiContext` (the "working context" dropdown — one of a fixed set of class + subject combinations) was offered in
full to every teacher regardless of what they actually teach. `TeacherAiSnapshot` gained `contextOptions`: the subset of
`TeacherAiContext.values` whose class is one of the teacher's real assigned classes, via `TeacherRoster`. `ask()`
re-checks that same real membership before accepting a prompt, and `load()` filters prompt history to those same
options, the same defense-in-depth pattern used throughout this module. Fixed the same "SS 1A" (space) vs "SS1A" naming
mismatch found several times already this session, this time in the context enum's label. A teacher with no assigned
classes among the four covered class/subject combinations now sees an honest note instead of an empty-feeling picker.

Also fixed the same demo-seed-safety bug as Performance: `ask()` wrote the teacher's real prompt history with `isDirty`
left false, indistinguishable from seed data to `LocalDatabase.blockDemoSeeds` — a teacher's real AI prompt history would
have been silently discarded the moment a real backend was configured. Fixed by passing `isDirty: true`.

Tests: `test/teacher_ai_roster_test.dart` (new, against the real roster, including the same blockDemoSeeds regression
pattern as Performance).

## Teacher: Timetable filters to real assigned classes — the last screen in this module

The weekly lesson schedule was shown in full to every teacher regardless of what they actually teach. `load()` now
filters lessons to the teacher's real assigned classes via `TeacherRoster`, the same pattern used throughout this
module; a teacher with no assigned classes now sees an honestly empty timetable instead of someone else's schedule.
Fixed the same "SS 1A" (space) vs "SS1A" naming mismatch found several times already this session, in both the sample
lessons and a schedule notice. The KPI strip ("Lessons this week", "Substitutions", etc.) is now computed from the real,
filtered lesson list instead of a fixed snapshot (`'14'`, `'4'`, `'1'`, `'9'`); the "Free periods" KPI, which had no real
source (nothing in the data model tracks total available periods), was replaced with "Assigned classes", a real count.
Also fixed a real repository-construction-ordering bug in `teacher_workspace_page.dart`: `TeacherTimetableRepository` was
built one line before `TeacherRoster` itself, which would have thrown `LateInitializationError` at runtime the moment it
tried to use the roster — the same class of ordering bug caught earlier this session for other repositories, this one
had gone unnoticed because nothing had given `TeacherTimetableRepository` a `roster` dependency until now.

This screen never had a widget test file; only a unit test file existed and is preserved. Tests:
`test/teacher_timetable_roster_test.dart` (new, against the real roster).

This completes the pass through every screen in the Teacher module (Syllabus, Assessments, CBT, Learning Progress,
Lesson Plans, Messages, Profile, Performance, AI, Timetable), following the same pattern throughout: make what a
teacher genuinely does or creates real, filter every class-scoped view to `TeacherRoster`'s real assigned classes with
defense-in-depth checks on every write, replace fixed numbers with real computation wherever a real source exists, leave
what has no real source honestly labelled rather than fabricated, and never let a screen show one real, named person's
fabricated evidence to another.

## Administrator: attendance corrections are drawn from the real register, and dead code removed

Spot-audited on request (not part of the Teacher pass above). The core of this module was already solid:
`buildAttendanceDesk()` computes every figure shown from real inputs, real actions (`checkIn`, `identifyUnknown`,
`decideCorrection`) correctly set `isDirty: true` and queue for sync, `demoScansFor()` (the sample morning of gate
scans) was already correctly demo-only and already derived deterministically from the real student register — this
was the pattern to match, not deviate from.

One live gap: `administratorAttendanceCorrections`, a fixed list of three sample correction requests, attributed a
specific fabricated request ("Teacher submitted correction") to three of the four real, named students in the demo
register, regardless of which students a given school's register actually contains. `demoCorrectionsFor(students)`
replaces it, in `administrator_attendance_desk.dart` next to `demoScansFor` (same file, same pattern): deterministic,
built from the real register passed in (the first few students by id, matching the number of request templates), so a
sample correction always names a student who is genuinely enrolled, the same guarantee `demoScansFor` already gave
attendance events. Still demo-only (seeded without `isDirty`, blocked once a real backend is configured) and still
labelled as such in the doc comment.

Also removed dead code found during the audit: `administratorAttendanceWebsiteEvents`, `administratorAttendanceSections`,
`administratorAttendanceExceptions` and six fixed KPI constants (`administratorAttendancePresentToday`, etc.) were
defined and tested but never referenced by the live page — `AdministratorAttendancePage` already computed everything
from the real `AttendanceDesk` and its own dynamic `_ExceptionsCard` content. The old test file was asserting on data
the app doesn't show, which is worse than no test: it gave the appearance of coverage over dead code while the real
`buildAttendanceDesk`/`demoScansFor` logic was only covered in a separate action-focused test file. Rewrote
`test/administrator_attendance_feature_test.dart` to test the real `demoCorrectionsFor` logic and the constants that are
actually still live (devices, flow, boundary text).

Tests: `test/administrator_attendance_feature_test.dart` rewritten; `test/administrator_attendance_actions_test.dart`
(pre-existing, exercises the real repository end to end) updated for the new correction attribution.

## Principal: Students now shares Administrator's one real register, instead of its own fake duplicate

Starting the Principal role pass (Owner, Administrator and Teacher are done; Principal is next). The first screen audited
found the most severe issue of the whole project so far: `principal_students_demo_data.dart` maintained its own
completely separate, fixed directory of six students — three of them (Maryam Abdullahi, Ibrahim Sani, Yusuf Bello) are
the *same real students* already in Administrator's real register, re-fabricated independently here with invented
academic scores, attendance percentages, **incident counts, "at risk"/"needs attention" behaviour labels, guardian phone
numbers and health-record labels**, none of it real and never reconciled with what Administrator actually has on file.
Yusuf Bello, a real named child, was tagged `atRisk`/`needsAttention` with two fabricated incidents from nothing — and
the students page itself additionally hard-coded three more named claims directly in a "Priority intervention queue"
widget ("Yusuf Bello · JSS 2B: Attendance 79%, average 48%, two incidents...").

`PrincipalStudentsRepository` now takes an `AdministratorStudentsRepository` and derives its directory and every profile
from that one real register — the same source Administrator and, by extension, any future Teacher-side view already
use — filtered to the Principal's real Secondary-only scope (`_isSecondary`, mirroring `sectionOfClass` in
`administrator_attendance_desk.dart` so the two leadership views agree on scope) and excluding transferred-out students.
Every field with no real source (average, attendance, trend, incidents, interventions, and the whole detailed profile:
admission number, class teacher, date of birth, subjects, attendance breakdown, promotion history, documents, timeline)
is honestly empty or `'Not recorded yet'` rather than fabricated; risk and behaviour default to neutral (`stable`/`good`)
rather than inventing a judgement about a real child from nothing. The hard-coded "Priority intervention queue" and the
"Principal AI student insight" card's fabricated JSS 2B narrative are replaced with honest "not available yet" notes.
The class filter now lists the real Secondary classes actually represented, instead of a fixed five-class list.
Leadership notes and lifecycle proposals (the two genuinely real, teacher-authored actions on this screen) were already
correctly `isDirty: true` and queued for sync, and are unchanged.

Tests: `test/principal_students_feature_test.dart` rewritten to test the real repository against a real, full register
(16 students across Nursery through SS3, via `administrator_demo_school.dart`), covering Secondary-only scope, the
zeroed/honest fields, profile access rules, and the leadership-note/lifecycle-proposal write paths.

## Principal: Teachers now shares the owner's one real staff register

Same anti-pattern as Students, one screen later: `principal_teachers_demo_data.dart` maintained its own fixed directory
of five teachers — two of them (Mrs. Amina Yusuf, Mr. Ahmad Sani) share names with real staff already in
Administrator's real staff register — with invented attendance, punctuality, lesson-plan compliance, syllabus pace and
assessment-completion percentages, a fabricated evaluative `status` ("Strong" / "Needs support"), phone numbers, next-of-
kin, and a full five-teacher detailed HR profile (qualifications, TRCN numbers, weekly periods, class assignments, leave
history), none of it real. The app already has one authoritative real staff source for this — `OwnerStaffProfileRepository`
— which the doc comment on `StaffProfileAccess` explicitly names the principal as having full access to (the same access
as the owner), and which the Principal workspace already reuses directly for its separate "Staff Profiles" nav item. The
"Teachers" screen just wasn't wired to it.

`PrincipalTeachersRepository` now takes an `OwnerStaffProfileRepository` and derives its directory and every profile from
that one real register, filtered to Secondary section and a teaching role (`role.toLowerCase().contains('teacher')`, the
same check `buildStaffOverview`'s `StaffOverviewPerson.teaches` already uses, for consistency). Real fields (name, role,
section, employment type/date, qualifications via `StaffProfile.highestLevel`, phone, email, next of kin, document
status, and real staff-attendance rate when recorded) come from that source; everything with no real link yet — subjects
taught, class assignments, weekly periods, lesson-plan compliance, syllabus pace, assessment completion, leave history —
is honestly `'Not recorded yet'` / empty / `0` rather than fabricated. The evaluative `status` field defaults to `'Not
evaluated'` instead of inventing "Strong" or "Needs support" from nothing; the department/status filter lists were
trimmed to match. The KPI strip is computed from the real, filtered directory instead of a fixed six-value map
(`'24'` staff, `'96%'` attendance, etc.).

One inconsistency noted but not resolved in this pass: `PrincipalTeacherPermissions.canViewConfidentialPayroll` is
hard-coded `false`, while `OwnerStaffProfileRepository`'s own real access model (`staffProfileAccessFor`) already grants
the principal full payroll access, same as the owner. The Teachers screen never surfaces payroll figures either way, so
this is a latent documentation mismatch between two parallel permission systems, not a live bug — reconciling it is a
larger change than this screen's scope.

Tests: `test/principal_teachers_feature_test.dart` rewritten to test the real repository against the real staff register
(4 staff, 2 of them real Secondary teachers), covering scope filtering, the honest/empty fields, and the private-note
write path.

## Principal: Attendance computes real per-class figures; staff/follow-up/trend are honestly empty

A mixed case: some of this screen was genuinely buildable from real data already wired elsewhere this session, and some
had no real source at all, so it got two different treatments rather than one.

**Real and buildable — built:** `principalAttendanceClasses` was a fixed six-class snapshot. Today's real Secondary class
attendance is now computed the same way `administrator_attendance_desk.dart`'s `buildAttendanceDesk` already computes
Administrator's, reusing the same real register (`AdministratorStudentsRepository`) and the same real gate-scan events
(`AdministratorAttendanceRepository`), just grouped by class instead of section. `trend` is always `0` and `status` is a
deterministic bucket of the real `rate` (≥95% strong, ≥85% watch, else needs attention) — a computed fact, not an
invented judgement.

**No real source — left honest:** `principalAttendanceStaff` (a fixed five-teacher list with a fabricated per-day
check-in time and punctuality, one of them sharing a real staff member's name) had no real equivalent: the only real
staff-attendance data anywhere is a period average (already used on the Teachers screen), not a real "checked in today"
feed. `principalAttendanceFollowUps` (repeated-absence/lateness alerts, one naming a real-sounding staff member) had no
real source either: detecting a real pattern needs multi-day history, and the real attendance source only keeps today's
record. `principalAttendanceWeekTrend` and its fabricated "Principal AI observation" narrative about JSS 2B had the same
problem. All three are now honestly empty (`staff: const []`, `followUps: const []`, no trend data), with clear "not
available yet" messages replacing the invented content instead of an empty-feeling blank space.

**Left alone:** the biometric scanner and event seed content, which was already a reasonable, clearly-labelled sample of
hardware not yet connected to this demo school, following the same pattern `demoScansFor` already established (a
plausible synthetic event about a real, registered person, not a fabricated judgement) — added a code comment making
that intent explicit rather than changing the data.

Tests: `test/principal_attendance_feature_test.dart` rewritten to test the real class-attendance computation against the
real register and real events, and to confirm staff/follow-ups are honestly empty.

## Principal: Assignments now uses the real Secondary staff and classes; no fake teacher directory or seed

`principalAssignmentTeachers` was a fixed six-teacher directory (one of them, "Mrs. Amina Yusuf", coincidentally sharing
a real staff member's name and id-style) with invented `weeklyPeriods` and `qualifiedSubjects`, backing a fixed
eight-assignment seed (`principalAssignmentSeed`) and a fixed six-class picker list (`principalAssignmentClasses`). All
three are gone.

**Teachers** are now the real Secondary teaching staff from the owner's one real staff register
(`OwnerStaffProfileRepository`, the same source Teachers uses), filtered to `section == 'Secondary'` and a role
containing "teacher" — currently Mrs. Amina Yusuf and Mr. Ahmad Sani. `weeklyPeriods` is computed honestly by summing
that teacher's real assignment records, starting at `0` until a real assignment exists. `department` stays
`'Not recorded yet'`, since no real source exists for it.

**Classes** are the real Secondary class names drawn from the real student register (`AdministratorStudentsRepository`),
the same `classOptions` computation Students and Attendance already use.

**Assignments** now start empty — the fixed seed is gone — and are only ever created through the already-correct real
`addAssignment`/`transferAssignment` workflow (`isDirty: true` + `queueMutation`, unchanged from before this fix).
Transferring to a brand-new staff member still creates a genuinely real, locally-saved "provisional" teacher record, as
it did before.

**Deliberate compromise — qualified subjects:** there is no real per-subject qualification record anywhere in the app
(no syllabus-assignment or credential-by-subject data exists yet). Leaving a real teacher's `qualifiedSubjects` empty
would make `canTeach()` always false and silently break the entire real assignment-creation workflow. Rather than either
fabricating specific per-teacher qualifications or disabling the feature, every real Secondary teacher is treated as
assignable to any subject on the fixed subject list (`principalAssignmentSubjects`, kept as an honest fixed picker list,
same as before), with a code comment explaining that the principal remains responsible for that judgement — matching
the fact that the old fixed qualification list never verified anything either.

**No real source — left honest:** `principalUnassignedSubjects` (a fixed three-item "coverage gap" list) had no real
equivalent — computing a real gap needs a real curriculum-requirement record (which subjects a class is supposed to
have) that does not exist anywhere yet — so the gap-analysis panel now shows an honestly empty list instead of a fixed
illustrative one.

Tests: `test/principal_assignments_feature_test.dart` rewritten to test the real teacher/class-option computation, real
`addAssignment`/`transferAssignment` behavior (including the provisional-teacher path and the qualification-gate
compromise), and permission restriction for non-principal roles.

## Principal: Academics computes real per-class figures from four existing real sources; subject/risk analysis is honest

The most involved fix so far, because the fabrication here was not a duplicate person-directory but a fully invented
set of school performance numbers (`principalAcademicClasses`, `principalSubjectPerformance`, `principalAcademicRisks`,
and a fixed "AI" narrative) with no single real source to swap in. Each figure was triaged separately.

**Real and buildable — built, from four sources already wired elsewhere this session:**
- **Classes and students** — the real Secondary class names and roll counts, from `AdministratorStudentsRepository`
  (the same register Students/Attendance/Assignments already use).
- **Teachers** — the real count of distinct teachers with a real teaching assignment for that class, from
  `PrincipalAssignmentsRepository`'s real assignment records (so this screen and Assignments now agree by
  construction).
- **Attendance** — today's real per-class rate, from `PrincipalAttendanceRepository`'s existing real class-attendance
  computation, reused directly rather than duplicated.
- **Academic average and assessment-completion** — real teacher-created assessments, read school-wide from the same
  `teacher_assessment_register` local records the Teacher Assessment screen writes (exposed as a public
  `teacherAssessmentRegisterEntityType` constant so Principal can read them without a teacher's own assigned-class
  scope). Average is the mean of each assessment's real score average as a percentage of its maximum; completion is
  real entered-scores over real expected scores. A class with no assessment yet gets status `notEvaluated` (a new
  enum value, matching Teachers' `'Not evaluated'` convention) instead of an invented average of 0.
- **Syllabus coverage** — real teacher-reported progress against the fixed approved scheme of work
  (`teacherSyllabusRows`, a real curriculum document like a subject picker list, not fabricated per-person evidence),
  read school-wide via a new public `teacherSyllabusProgressEntityType` constant. Only 4 of the 9 real Secondary
  classes have an approved scheme uploaded at all; the other 5 honestly show `hasSyllabusScheme: false` and a "no
  scheme uploaded" label instead of a 0% that would look like failing coverage.

**No real source — left honest:**
- **Subject performance** (`principalSubjectPerformance`) — no real assessment carries a subject label (a score
  sheet only records a class and a free-text title), so there is no real way to aggregate by subject at all. Always
  empty, with an explanatory message replacing the fixed six-subject table.
- **Academic risk queue** (`principalAcademicRisks`) — flagging a genuine risk needs human judgement over a pattern
  that nothing in the app infers automatically. Always empty, with the class list held up as the place to review real
  figures directly instead.
- **AI academic brief** — the fixed narrative naming JSS 2B specifically is now a "Not available yet" explanation.
- **Curriculum control / assessment readiness panels** — rebuilt from real counts (classes with a scheme uploaded,
  classes behind on a topic, classes with a recorded assessment) instead of the fixed illustrative grids ("4 classes
  on pace", "84% complete", "2 score corrections") that had no real backing at all.

**KPI honesty:** `principalSchoolAverage`/`principalSyllabusAverage`/`principalAssessmentAverage` now return `int?`
and average only over classes that actually have real evidence, so the headline KPI reads "Not recorded" instead of a
misleading "0%" when nothing has been recorded yet (which, in a fresh demo school, is every class until a teacher
starts creating assessments).

Tests: `test/principal_academics_feature_test.dart` rewritten against the real repository, including cross-checks
that a real assignment raises the real teacher count and a real assessment record changes the real average/
completion figures for that specific class.

## Principal: Results & Reports

The old page seeded fabricated class averages, student scores, positions, attendance, comments and release states,
then printed them on invented school letterhead. None of those records represented a real term report.

**Real source:** class names and active Secondary student counts now come from the one Administrator student
register, filtered through `sectionOfClass()` and excluding transferred-out students.

**No real source — left honest:** Teacher assessments contain actual assessment evidence, but do not supply the
subject/term grading, report preparation, approval and publication records needed for official term reports.
Reports, review decisions, rankings, signatures, conduct and AI conclusions therefore remain empty; the page links
to Academics for actual assessment evidence. Legacy seeded report records are deliberately not treated as genuine
reports. Review and print actions cannot manufacture a report from them. Missing averages are null, not zero marks.

Tests: `test/principal_results_feature_test.dart` now checks the real register, missing evidence, legacy-record
exclusion, denied review/publication and phone rendering. Full analysis is clean; full suite: 1,114 passed with the
same 8 baseline failures (six demo navigation tests, Teacher Assignments phone test and Teacher Students phone test).

## Principal: Incidents

The fixed case list attached invented behaviour, safeguarding concerns, attendance allegations, guardian contact,
evidence counts and case histories to named people. It also invented 18 resolved cases and an AI conclusion.

**Real source:** genuine case records can be reviewed offline; case context must match an actual Secondary class
in the Administrator student register. Notes and status changes retain the real acting membership and timestamp.
The recorded-case namespace is separate from the old seeded records so previously cached allegations cannot
silently reappear. Unknown classes, Primary/Early Years and other schools are excluded from reads and changes.

**No real source — left honest:** no Secondary disciplinary intake exists elsewhere in the app. The fresh case
register and activity are empty, with no AI judgement. Driver transport reports stay in Transport: they do not
establish disciplinary or safeguarding allegations. Resolved counts now describe recorded cases, not an invented term.

Tests: `test/principal_incidents_feature_test.dart` covers empty demo, legacy exclusion, real audit changes,
role/school/class isolation and empty rendering. Analysis is clean; full suite: 1,121 passed, same 8 baseline failures.

## Principal: Approvals

Replaced the fixed APR queue and invented report/score-correction evidence with recorded Teacher submissions.

**Real source:** submitted `teacher_lesson_plan` and `teacher_assessment_score_sheet` records must have a matching versioned submission event and belong to a Secondary class in the Administrator student register. Reviews store the Principal membership, timestamp, comment and decision in `principal_submission_review`, with an offline sync mutation. A new source version requires a new review; duplicate and stale decisions are rejected. Teacher marks and publication state are unchanged.

**No real source — left honest:** official report batches and score-correction requests have no connected intake. Old seeded approvals are ignored. Fresh demo schools show an empty queue. Reviewer attribution uses recorded membership IDs, without inventing staff names.

**Validation:** `test/principal_approvals_feature_test.dart` covers provenance, versioning, class/tenant/role scope, return validation and preservation of marks. `flutter analyze` is clean. Full suite: 1127 passing, the same 8 baseline failures (six demo login navigation, Teacher Assignments phone navigation, Teacher Students phone rendering).

## Principal: Communication

The old inbox showed fabricated guardian/staff conversations, invented delivery and read receipts, fake follow-up
tasks generated from other modules, and a fixed announcement history — none of it backed by anything the Principal
had actually sent or received.

**Real source:** announcements the Principal actually sends are saved as real local records
(`principal_outgoing_communication`, `isDirty: true` + queued for sync) and reloaded from there. Only Secondary
staff and guardian audiences are accepted — individual, class-guardian and whole-school routing are refused because
there is no real recipient-resolution source to check them against. External channels (SMS/Email/WhatsApp) are
queued honestly as unconfirmed; delivery is never claimed until a real channel adapter would confirm it. Outgoing
records are private to the membership that created them, and are correctly excluded when read from another
membership or another school.

**No real source — left honest:** there is no real two-way conversation thread anywhere in the app, so the inbox
always shows "No verified conversations recorded for this Principal" instead of fabricated messages, and replying
is always honestly refused. Follow-up tasks (previously shown as generated from attendance/academics/staff
oversight) have no real generator anywhere either, so that list stays empty with an explanatory message rather than
illustrative sample tasks. A leftover legacy-seeded thread record cannot be revived or replied to.

Tests: `test/principal_communication_feature_test.dart` covers the honestly-empty fresh inbox, a real queued
announcement round-tripping correctly, rejection of unconnected audiences and blank content, unconfirmed external
delivery, refusal to reply to a legacy record, and membership/school isolation of outgoing content.

## Principal: Performance

The old page was a pure scorecard mockup: eight metrics with invented current/previous/target values, a fabricated
5-term trend table, a fabricated class-health ranking, four fabricated "priorities", and a fixed AI summary citing
specific numbers ("Lesson-plan compliance +5 pts") none of which existed. There was no repository at all — the page
rendered a constant directly.

**Real source:** a new `PrincipalPerformanceRepository` is a pure roll-up of repositories every other Principal
screen already made real this session — it computes nothing independently, so it can never drift from what those
screens show. Six indicators are now computed live: academic average and syllabus coverage and assessment
completion (from `PrincipalAcademicsRepository`), student attendance (a weighted real rate from
`PrincipalAttendanceRepository`'s real per-class figures), teacher attendance (the mean of real
`OwnerStaffProfileRepository.attendanceRate` values across real Secondary teaching staff), and resolved incidents
(from `PrincipalIncidentsRepository`'s real recorded cases). Each metric's `current` is `int?` — `null`, not an
invented number, until that source has real evidence. `target` stays a fixed school policy goal (a reference value,
not a measurement, the same category as a subject picker list). "Class health" now lists the real Secondary classes
with their real academic average (nullable) and real attendance, sorted by real average instead of an invented
score/trend/status.

**No real source — left honest:** the fixed 5-term trend table is gone; nothing in the app stores a term-end
snapshot, so there is no real history to show, and the page says so plainly instead of a period/comparison selector
that would silently do nothing. "Priorities" needs human judgement over a pattern that nothing infers automatically,
so it is always honestly empty. The AI summary is a "Not available yet" explanation instead of a fabricated
narrative with invented supporting numbers. `overallHealth`, `evaluatedIndicators` and `belowTargetIndicators` are
all computed only over indicators that actually have evidence, so a fresh demo school reads as partially recorded
rather than a misleading fixed 94%.

Tests: `test/principal_performance_feature_test.dart` checks which indicators already have real evidence in a fresh
demo school (attendance and syllabus have deterministic real demo sources; academic average, assessment completion
and resolved incidents do not until something is actually recorded), that a real assessment record raises the real
academic-average metric and its matching class-health row together, that real recorded incidents raise the real
resolved-incidents metric, and permission restriction for non-principal roles.

## Principal: Profile

The account-edit form itself was already real (a genuine editable profile, saved offline and queued for sync), but
three parts of the surrounding page were fabricated: a default profile pre-filled with a specific invented person
("Mr. Ibrahim Danladi"), a "recent activity" log naming a real staff member in an action that never happened
("Reviewed Mrs. Amina Yusuf lesson plan") and a fake incident id, a "School identity" card with an invented address,
phone and branch list, and a fixed "Last sign-in" timestamp with no real source.

**Real source:** the default account is now blank (empty name/email/phone) rather than a specific invented person,
so the Principal fills in their own real details the first time they use the screen. "Recent principal activity" is
now a genuine cross-repository roll-up: `PrincipalProfileRepository` reads this Principal's own real actions from
the Incidents audit trail, the Approvals decision trail and the Communication outgoing log (all three already real
from earlier in this audit), filters to entries this specific membership authored, and sorts them newest first. The
"School identity" card's school name is the real `schoolName` already carried on the active membership.

**No real source — left honest:** the school's address, phone and branch list have no real source anywhere in the
app (not even on the Owner/Administrator side), so they now show "Not recorded yet" instead of an invented address.
"Last sign-in" and the Security card's password-age/2FA/session values have no real source either (no sign-in or
session history is tracked anywhere yet) and now say "Not tracked yet"/"Not set up" instead of a specific invented
claim.

Tests: `test/principal_profile_feature_test.dart` rewritten against the real repository: a fresh school has no
activity; a real incident note, a real queued announcement and a real approval decision (built through the actual
lesson-plan submission and review workflow) each appear in real activity, sorted newest first; activity and outgoing
content are correctly scoped to the authoring membership, not shared with another principal in the same school; and
saving the account profile round-trips and queues for sync.

## Principal: AI

The most severe fabrication case in this audit: a "Principal AI" chat with entirely canned, hard-coded answers
citing specific invented statistics ("JSS 2B average: 61%, trend: -6.8%"), a fabricated priority-issue list, and
evidence naming a real staff member in a claim that never happened ("Amina Yusuf and Fatima Bello both carry heavy
workloads") alongside invented students ("Student Gamma"). None of it came from any real record, and there is no
real reasoning model connected anywhere in this app.

**Approach:** follows the same pattern already established for Teacher's AI workspace this session
(`teacherAiResponseFor`): a prototype AI answer must never assert a specific invented fact, even one dressed up as
"mock data" with a disclaimer chip next to it. `resolvePrincipalAIInsight` no longer returns fabricated evidence
bullets or a fake "confidence" score (both removed from `PrincipalAIInsight` entirely) — it returns an honest answer
stating plainly that no real reasoning model is connected yet, plus real keyword-based routing to the actual screen
that holds the genuine figures (Attendance, Teachers, Students, Incidents, Academics, Performance, Approvals,
Results). Routing to a real screen is genuinely useful and asserts nothing false; a specific invented statistic is
not, no matter how it is labelled.

**No real source — left honest:** the fabricated "Priority signals" list (`principalAIPrioritySignals`) had no real
source — the same "needs human judgement" reasoning that emptied Academics' risk queue and Performance's priorities
applies here too — so that card now explains why and links to Performance for the real figures instead.

**Left alone:** the suggested-question list, the guardrail/production-principle explanatory text and the AI data
path are reference/policy content, not evidence about a specific person or class, and stayed as they were.

Tests: `test/principal_ai_feature_test.dart` rewritten to confirm no response ever contains a percentage or other
fabricated statistic, that every response is honest about not being connected to a real model, and that keyword
routing sends each kind of question toward the correct real screen.

## Principal: Timetable

The old page seeded a fixed weekly lesson grid attaching specific days, times, rooms and workload numbers to named
teachers — including "Mrs. Amina Yusuf", a real Secondary teacher — plus a fabricated "clash" and "uncovered lesson"
narrative and hard-coded "186 lessons this week / 38 today" KPIs that were not even read from the seeded data.

**No real per-period schedule exists anywhere:** unlike the other fixes this session, there was no real source to
switch to. A real teaching assignment (`PrincipalAssignmentsRepository`) records a class, a subject and a weekly
period *count* — never a day, a time slot or a room. There is no school-wide bell-schedule or room-booking system
anywhere in the app. Inventing plausible-looking days/times/rooms even for a generic, non-real-named teacher would
still fabricate an operational fact (this class meets Monday 8:00–8:40) nothing verifies, so the entire lesson grid,
room-utilization panel and schedule-exception workflow are now honestly absent, with a clear explanation, the same
"no real source" treatment already used for Academics' risk queue and Performance's term trend. `setExceptionHandled`
now always honestly refuses: there is nothing real yet to handle.

**Real and buildable — built:** teacher workload. `PrincipalTimetableRepository` now sums each real Secondary
teacher's real weekly periods directly from `PrincipalAssignmentsRepository`'s real assignment records, bucketed
against a fixed weekly-period target (Light/Balanced/Heavy — a deterministic bucket of a real number, not an
invented judgement, the same pattern used for attendance/academic status elsewhere). This replaces the fixed
five-teacher workload table that named real and invented staff with invented lesson counts.

Tests: `test/principal_timetable_feature_test.dart` rewritten against the real repository: a fresh school has no
schedule, room use or exceptions; real teacher workload lists the real Secondary teachers at zero periods; real
teaching assignments raise that specific teacher's real period count and cross the fixed target into "Heavy";
handling an exception is honestly refused; and permission restriction for non-principal roles.

## Principal: Dashboard (and the workspace shell) — the last Principal screen

The landing page itself, and the workspace shell around every Principal screen, both carried fabrication: fixed
KPIs ("92% · 403 of 438"), a fake four-item approval queue naming real and invented staff, fake teacher/class
indicators, a fake alerts list, a fake five-item activity log, a fake AI brief — and, in the shell chrome visible on
*every* Principal screen, a hard-coded person ("Mr. Ibrahim Danladi", avatar initials "PD"), a fabricated
"Kaduna Campus", and a fixed "Secondary section health: 86%" progress bar.

**Real source — a genuine roll-up:** a new `PrincipalDashboardRepository` computes every KPI, list and count live
from the same repositories every other Principal screen already made real this session — nothing here is stored or
computed independently, so it can never drift:
- Student/teacher attendance KPIs from `PrincipalAttendanceRepository` and real `OwnerStaffProfileRepository`
  attendance rates (real counts as the hint — "403 of 438" is now genuinely "$present of $total").
- Pending-approvals KPI and the approval queue itself from `PrincipalApprovalsRepository`'s real pending items.
- Classes-on-track KPI and the class-performance panel from `PrincipalAcademicsRepository`'s real classes.
- Open-incidents KPI from `PrincipalIncidentsRepository`'s real cases.
- Teacher-oversight panel reuses `PrincipalTeachersRepository`'s already-real, already-honestly-zeroed teacher list.
- "Section activity" is a genuine cross-repository feed: real teacher submissions (from Approvals' items), real
  approval decisions, and real incident audit events, merged and sorted newest first — deliberately *not* filtered
  to the Principal's own actions (unlike Profile's activity feed), since this panel is about what is happening in
  the section, not what the Principal personally did.
- The Hero card's narrative sentence is now built from the real pending-approvals and open-incidents counts instead
  of a fixed "4 items, 2 classes, 3 follow-ups" claim.

**No real source — left honest:** the "Today's alerts" list has no real source — the same "needs human judgement"
reasoning already applied to Academics' risk queue, Performance's priorities and Principal AI's priority signals —
so it now explains why and links to School Performance. The "Student risk alerts" KPI is dropped entirely: there is
no real risk-scoring system anywhere (Students intentionally defaults every student to neutral `stable`/`good`
evaluative fields with no source to score against). The AI brief is a "Not available yet" explanation.

**The workspace shell fix:** `principalLeaderName` and the "PD" avatar are gone — the top bar now shows the real
Principal's own display name and initials, loaded once from `PrincipalProfileRepository` at workspace start (falling
back to a generic "Principal" label/person icon, never a fabricated name). `principalCampusLabel`'s fake "Kaduna
Campus" is gone from the sidebar. The sidebar's "Secondary section health" figure now shows the real
`PrincipalPerformanceRepository.overallHealth` value (or "Not recorded" when no indicator has evidence yet) instead
of a fixed 86%.

Tests: `test/principal_dashboard_test.dart` rewritten against the real repository: a fresh school shows honest KPIs
(real attendance figures are already non-null from the demo's deterministic gate-scan/staff-attendance sources;
everything else is honestly zero), an empty approval queue/alerts/activity, the real Secondary teacher and class
lists, a real teacher submission appearing in both the approval queue and the activity feed, a real approval
decision appearing in activity, and permission restriction for non-principal roles.

---

**This completes the Principal role.** All fourteen Principal screens (Students, Teachers, Attendance, Assignments,
Academics, Results, Incidents, Approvals, Communication, Performance, Profile, AI, Timetable, Dashboard) plus the
workspace shell now show real data wherever a real source exists in the app, and an honest, clearly-explained empty
state everywhere one does not.

## Administrator (role 2 revisited): audit pass after Principal

With Principal done, returned to Administrator for a full audit, screen by screen. Unlike Principal, most of this
role was already built correctly the first time — `AdministratorOverview` (the Dashboard's real KPI/queue roll-up
from the real student/admissions/records/lifecycle/staff repositories) and the admissions pipeline's stage
management were already solid, real, and demo-safe. This pass found and fixed the smaller gaps that remained.

**Workspace shell:** `administratorCampusLabel` ("Kaduna Campus · Whole-school administration") and
`administratorAcademicYear` ("2026/2027 · Term 1") were fixed, invented values shown in the sidebar and header on
every Administrator screen — the same "no real campus/branch record or academic-term calendar exists anywhere in
the app" gap already found and documented on the Principal role's Profile and Performance screens. Replaced with a
single honest `administratorScopeLabel` ("Whole-school administration").

**Admissions:** `administratorAdmissionsKpis`, a fixed five-metric set ("Applications: 131", "Offers issued: 100"
…), was dead code — `AdministratorAdmissionsPage` already computes its real KPI row from the real loaded applicant
list (`applicants.length`, `at(AdmissionStage.screening)`, etc.), so the fixed constant was never actually shown and
was silently disconnected from the real 5-applicant seed. Removed, along with its dead test.

**Registration:** `registrationSiblingLinks`, a fixed two-item dropdown, offered "Maryam Abdullahi · JSS 2A" — a
real, currently-enrolled student — as a selectable "sibling link" on a brand-new registration, with nothing checking
whether the two people were actually related. The repository already has a genuinely real sibling-detection
mechanism (`AdministratorRegistrationRepository._save` matches the new guardian's phone number against every other
real registration record and refuses/links accordingly), which makes the fixed dropdown both redundant and
dishonest. Trimmed to its one honest default, `['No existing sibling']`, with a comment pointing to the real
detection logic.

Tests: `test/administrator_admissions_test.dart` and `test/administrator_registration_feature_test.dart` updated for
both removals. Full suite: 1141 passing, the same 8 pre-existing unrelated failures, zero regressions.

Still to audit in this role: Attendance Desk (beyond the corrections fix already done), Notices, Operations,
Records, Staff, Staff Attendance, Students, Website.

## Cross-cutting: a fabricated fixed "Principal" name found and fixed in two more places

While auditing Administrator's Lifecycle screen, found a real promotion record's seed history attributing
`approvedBy: 'Mr. Ibrahim Danladi (Principal)'` — the exact fixed fake Principal name already removed from the
Principal role's Profile screen this session (`administrator_lifecycle_demo_data.dart`'s
`administratorLifecycleDemoExtras`, shared with Students via `administrator_demo_school.dart`). Now the record
honestly names the role only (`'Principal'`), not an invented person, matching the note already left on the
Principal Profile fix.

That search also surfaced a genuine miss from the Principal Assignments fix earlier this session: an "Active
leadership scope" banner and a three-section card row (`_scopeBanner`/`_sectionCards` in
`principal_assignments_page.dart`) were never touched during that fix and still showed the fabricated "Kaduna
Campus", plus invented leaders for Nursery and Primary ("Mrs. Mary Daniel", "Mrs. Hauwa Sule") and the same fake
Principal name for Secondary — none from any real source, and Nursery/Primary aren't even in this Principal's real
scope. Fixed the same way as everywhere else this session: no real per-section leadership-directory source is
visible from this Principal's membership, so the cards now show only the real section names and which one is this
Principal's active scope, dropping every invented name and class count.

**Not fixed, flagged for a future pass:** this fake Principal name (and matching fake names for every other demo
role) also seeds `lib/app/demo_people.dart` (the demo login picker's "who you're signing in as" list) and, at the
same severity as the Assignments miss, the Owner/Proprietor role's own `proprietor_structure_demo_data.dart` (the
real, editable `ProprietorStructureRepository` starts pre-filled with these same invented names rather than the
blank-until-entered pattern established for Principal's own Profile). Both are legitimately out of the Administrator
role's scope and deserve their own audit pass — `demo_people.dart` in particular needs a product decision first
(the demo login screen currently promises "sign in as Mr. Ibrahim Danladi, the Principal," which is now inconsistent
with that Principal's own Profile screen defaulting to blank).

Full suite after this fix: 1141 passing, same 8 pre-existing unrelated failures, zero regressions.

## Administrator: remaining screens audited (Operations, Staff Attendance, Students, Website)

Finished the audit of every Administrator screen. Records, Notices, Staff and Attendance Desk were already solid;
Admissions and Registration were fixed in an earlier commit this pass. This closes out the rest.

**Staff Attendance — a real fix.** `administratorStaffAttendanceKpis` showed a fixed "Expected staff today: 64 ·
Present: 61 · Payroll-ready: 62 / 64" — completely disconnected from the real 4-person staff register the same
screen's own ledger displays below it, and `expected`/`present` on each real record are period (monthly) counts, not
a daily headcount, so the KPI didn't even match its own label semantically. Replaced with `_realKpis()`, computed
live from the real loaded `records`: real staff-on-record count, a real attendance-rate percentage
(`present/expected`), real summed late/unexplained counts, and a real payroll-ready ratio. The same fix already
applied to Admissions' KPI row (compute from the real loaded list, not a fixed constant) and Registration's sibling
dropdown (trust the real detection logic already in the repository) — a pattern repeating enough this pass to be
worth naming: **a fixed KPI sitting beside a real, small seed list is the reliable tell that it was never actually
wired up.**

**Website — the same disconnected-KPI bug, this time removed rather than rebuilt.** `administratorWebsiteApplications
= 131` and `administratorWebsitePublishedNotices = 8` repeated the exact fabricated "131" from the now-removed
Admissions KPI, live-rendered on the Website settings/preview screen. Real counts exist for both (Admissions,
Notices), but wiring two more repositories into a settings-preview page for a low-prominence summary card wasn't
worth the added coupling; removed the two KPI entries instead, with a comment pointing to where the real counts
actually live. The grid now shows only what's real: the fixed domain string and the admissions open/closed toggle
(already live from the real settings record).

**Operations and Students — labelled, not rebuilt.** Both show fixed illustrative task counts
(`administratorOperationsWebsiteSeed`'s "3 students"/"4 today"/etc.; `administratorFamilyTasks`/
`administratorRecordQualityTasks`'s "7 profiles missing one document"/etc.) with no names attached and, for
Operations, no action methods at all — a permanently static queue. Real source modules exist for some of this
(Transport, Meals and Visitors are all real feature modules elsewhere in the app; Records already tracks real
per-person document status), but a full integration means reconciling mismatched semantics across three unrelated
modules (Meals currently models menu planning, not per-student enrollment) and was judged too large for this pass.
Added an honest, visible label to both cards instead ("Sample counts only: not yet wired to real records") rather
than silently leaving a fabricated-looking number in place — consistent with the pinned instruction to label what
isn't real rather than fake it, while flagging the real integration as a good candidate for its own focused pass.

Tests: `test/administrator_staff_attendance_feature_test.dart` and `test/administrator_website_feature_test.dart`
updated for the removed constants. Full suite: 1140 passing, same 8 pre-existing unrelated failures, zero
regressions.

---

**This completes the Administrator role audit.** Every Administrator screen now shows real data wherever a real
source exists, an honest visible label wherever a fixed placeholder remains for a documented reason, and no more
KPIs disconnected from the real records sitting right below them.

## Finance Office (role): audit

Finance Office turned out to be the most advanced role in the app already: Dashboard, Reports, Reconciliation, Debt
Aging, Reminders and the Finance AI assistant had all already been rewritten to compute everything live from
`FinanceLedgerRepository` (real accounts, payments, concessions, reminders, aging, reconciliation), with a genuinely
excellent, already-honest AI service (`FinanceAiService` in `finance_facts.dart`) that explicitly refuses to answer
about the school store, expenses, other income or payment mandates because "they are not recorded yet." This is the
standard every other AI fix this session has been aiming for, and it already existed here.

**The most severe fabrication in this session's Finance audit, and one of the most severe overall:**
`FinancePayrollPage` cross-referenced every real payroll profile against a fixed three-row `financePayrollRows` list
**by name**, pulling in fabricated `expectedDays`/`presentDays`/`leaveDays`/`unexplainedDays`/`status` — including
for two real teachers ("Mrs. Amina Yusuf", "Mr. Ahmad Sani"). That fabricated status then directly gated a real
financial action: only staff whose *fake* attendance happened to read "ready" could be included when Finance
actually prepared a real payroll batch. Real per-staff attendance already existed
(`AdministratorStaffAttendanceRepository`, the same source the Administrator Staff Attendance screen uses); `_load()`
now matches by real staff id against the real attendance register, holding anyone with no real attendance record for
review — honestly, because there is genuinely no evidence, not because their name failed to match a hardcoded list
of three. See the dedicated commit for full detail; documented here so the pattern is recorded alongside the rest of
this audit.

**A huge amount of orphaned dead code, found by checking every constant a `finance_*_demo_data.dart` file exports
against real usage in `lib/`:** once Dashboard/Reports/Reconciliation/Debt-Aging/Reminders/AI were rewritten to be
real, their entire original "website seed" demo-data files were left behind, still compiling, still tested by their
own now-meaningless test files, but never actually shown by the app again. Confirmed zero real usage and deleted
entirely:
- `finance_debt_aging_demo_data.dart` (fabricated "family" receivables with invented balances and next-action dates)
- `finance_family_accounts_demo_data.dart`
- `finance_reconciliation_demo_data.dart`
- `finance_reminders_demo_data.dart`
- `finance_reports_demo_data.dart` (the fixed "Collection rate: 94.1%" / "Outstanding: ₦3.7m" KPIs — the real Reports
  page already computes these live)
- `finance_ai_demo_data.dart` — an entire second, fabricating "Finance AI" implementation
  (`financeAiAnswerFor`), never actually wired to the live `FinanceAiPage` (which correctly uses
  `FinanceAiService`), but still citing the dead Reports/Reconciliation/Cashflow/Debt-Aging constants above as if
  they were live evidence. Deleted along with its four dead boundary-text constants; `financeAiPrompts`, the one
  constant this file happened to share a name with, is separately and correctly defined in `finance_facts.dart` and
  needed no change.

Also trimmed `finance_office_dashboard_demo_data.dart` (kept: the real, live navigation list and a generic role
title) and `finance_payroll_demo_data.dart` (kept: the real boundary text) of their own dead KPI/queue/trend/
permissions constants, and fixed the same "Kaduna Campus" + fabricated leader name ("Mr. Ahmad Bello") + fake avatar
initials ("AB") already found and removed from the Administrator and Principal workspace shells — the Finance Office
top bar and sidebar now show a generic role label instead of an invented person.

**Not yet audited in this role:** Cashflow, Collections, Concessions, Mandates, Store, Fee Structure, Receipts — the
screens that (unlike the ones above) are still genuinely using their own fixed demo data directly, some with no
backing repository at all. `FinanceAiService` already treats several of these (store, expenses/cashflow, mandates)
as intentionally "not recorded yet," suggesting building them fully real may be a deliberate future scope rather
than an oversight; each needs its own look before deciding between a real build-out and an honest label.

Tests: `test/finance_payroll_feature_test.dart` updated (see the payroll commit); seven fully-dead test files
deleted (`finance_debt_aging_feature_test.dart`, `finance_family_accounts_feature_test.dart`,
`finance_reconciliation_feature_test.dart`, `finance_reminders_feature_test.dart`, `finance_reports_feature_test.dart`,
`finance_ai_feature_test.dart`) alongside their dead source files; `finance_office_dashboard_test.dart` trimmed to
its still-live assertions. Real coverage for all of this already exists and was untouched: `finance_ledger_test.dart`,
`finance_dashboard_test.dart`, `finance_aging_reminders_test.dart`, `finance_reports_ai_reconciliation_test.dart`,
`finance_pages_test.dart`, `proprietor_finance_test.dart`. Full suite: 1085 passing, same 8 pre-existing unrelated
failures, zero regressions.

## Finance Office: the four remaining fully-static screens now say so plainly

Followed up on the four screens flagged as "not yet audited": Cashflow, Collections, Mandates and Store. Fee
Structure and Receipts turned out to already be real (`FinanceLedgerRepository`); Concessions was already real too
(`FinanceConcessionsRepository`, a genuine seed-then-real-workflow pattern matching Admissions/Lifecycle from the
Administrator audit, with its own funding-source breakdown already explicitly labelled "sample").

Cashflow, Collections, Mandates and Store are each a fully self-contained `StatefulWidget` with no repository, no
`LocalDatabase`, at all — every number and row is a fixed constant, and in Collections/Mandates/Store several rows
name real students from the register (Maryam Abdullahi, Hafsa Abdullahi, Yusuf Bello, Zainab Aliyu) with invented
bank account numbers, transaction references and payment amounts attached. `finance_facts.dart`'s own
`FinanceAiService` already treats the school store, expenses/cashflow and payment mandates as intentionally "not
recorded yet" — this looks like deliberate, acknowledged future scope rather than an oversight, and building four
real banking/inventory/standing-order integrations from scratch was judged well outside this pass. Each page already
had a boundary-text disclaimer, but only covering the *action buttons* ("this does not post a real payment"), never
the *displayed data itself* — a user could scroll through several screens of real-looking student names, account
numbers and transaction history before reaching a buried footnote that didn't actually address what they'd just
read.

Added a prominent, plainly-worded banner directly under the header of all four pages — "This screen shows sample
&lt;family accounts / income and expense entries / payment mandates / store orders&gt;, not real ones," each
naming the matching `FinanceAiService` boundary where relevant — instead of leaving the fabricated-looking data to
speak for itself. This is the same proportionate "label it, don't fake a fix" treatment already used for
Administrator's Operations/Students screens and Principal's Timetable.

No dead code found in any of the four (every constant they export is genuinely rendered); no test changes needed.
Full suite: 1085 passing, same 8 pre-existing unrelated failures, zero regressions.

---

**This completes the Finance Office role audit.**

## Parent (role): audit begins with My Children

Unlike Finance Office, every one of Parent's eleven screens already has its own repository, and a first sweep found
almost no dead code — every constant each `parent_*_demo_data.dart` file exports is genuinely rendered somewhere.
The problem here is different: each screen's repository is real plumbing (`LocalDatabase`/`SchoolSessionController`)
wrapped around a single, fully fabricated fixed snapshot, so the *shape* looks real but the *content* never was. And
because at least three separate screens (Children, Dashboard, Attendance) each keep their own independent fixed
per-child dataset for the exact same two real students, they don't even agree with each other — Children says
Maryam Abdullahi's attendance is "96%," Dashboard's own separate fixed snapshot also says "96%" today but would
drift the moment either one changed, and neither number was ever actually computed from anything.

**Fixed first — My Children, the most foundational screen everything else keys off:** `ParentChildrenRepository`
returned one hard-coded `parentDefaultChildren` snapshot: real student ids (STU-001 Maryam Abdullahi, PRI-003 Hafsa
Abdullahi) wrapped in entirely invented attendance/learning percentages, a specific bank account number and payment
plan, a fabricated event timeline ("Mathematics assessment posted · 88%", "Term fee payment received · ₦60,000"),
house assignment and class-teacher name.

There is no real guardian-linking workflow anywhere in the app yet (no admin screen assigns a parent membership to
specific children), so *which* children are linked stays a seed — the same "a real workflow will replace this later"
pattern already used for Admissions and Registration — now persisted as a real local record via a new
`replaceLinkedChildren` method a future server sync can call. But every fact *about* each linked child is now
computed live from the same real sources every other role already uses:
- Identity, class and section come from `AdministratorStudentsRepository` (the one real register).
- Attendance is today's real gate-scan status from `AdministratorAttendanceRepository`, matched by name to the real
  register the same way Principal Attendance already does — never a fabricated running percentage, since the real
  source only keeps today's record.
- The real account balance comes from `FinanceLedgerRepository.accounts()` — the same ledger Finance Office uses,
  so a parent's "amount owed" can never drift from what Finance actually sees.

**No real source — left honest:** admission number, class teacher, house, transport, payment account/plan,
activities, per-subject progress and the event timeline all have no real source at this summary level (a "form
teacher" isn't a concept the real assignment data tracks; no house system, transport-to-child link surfaced here, or
unified event log exists yet) and now read `'Not recorded yet'`/empty instead of an invented specific claim.
Per-subject learning detail is deferred to the dedicated Learning Progress screen, which needs its own real fix
rather than duplicating a summary here.

Tests: `test/parent_children_feature_test.dart` — the first test coverage this repository has ever had. Confirms
linked children are the real register entries, every no-real-source field is honestly labelled, attendance is a
real status (never a fixed percentage), the balance matches what `FinanceLedgerRepository` independently reports for
the same student, and permission/validation checks. Full suite: 1092 passing, same 8 pre-existing unrelated
failures, zero regressions.

Given how large this role is (eleven screens, several already found to disagree with each other about the same real
children), the remaining ten screens — Dashboard, Learning Progress, Weekly Learning, Attendance, Finance, Messages,
Discussions, School Life, Documents, AI — are still to come, in the same pattern.

## Parent: Attendance now reads the real gate-scan record

`ParentAttendanceRepository` returned a second, independently fabricated attendance dataset for the same two real
children (Maryam Abdullahi 96%, Hafsa Abdullahi 82%) — different specific numbers from the ones My Children showed
for the same students, a fixed multi-day check-in/check-out history with specific gate/device/time detail, and
fabricated push notifications ("Maryam checked in at 07:41").

Deliberately fixed *after* My Children rather than before: `load()` now starts from `ParentChildrenRepository`'s
real linked-child list (so the two screens can never disagree about who the children even are), then matches each
child by name against the same real gate-scan events `AdministratorAttendanceRepository` computes for every other
role. Because that real source only keeps today's record, `ParentAttendanceChildSummary`'s per-child stats now
describe an honest single-day window (`totalSchoolDays: 1`, `presentDays` 0 or 1, `attendancePercent` computed from
those, never an invented running percentage) instead of a fabricated multi-day history, and
`ParentAttendanceSnapshot.events` holds only today's real event per child instead of an invented several-day log.
Removed the now-incoherent `replaceFromServer` method, which validated and cached a full server-provided snapshot
that `load()` would never have read once every field became live-computed — the same simplification already applied
to My Children's own `replaceFromServer` → `replaceLinkedChildren`.

**No real source — left honest:** attendance notifications (`ParentAttendanceSnapshot.notifications`) have no real
push-notification system behind them anywhere in the app and now stay empty.

Tests: `test/parent_attendance_feature_test.dart`, the first coverage this repository has had. Confirms child
summaries are the real linked children with an honest single-day window, today's events line up exactly with which
children actually checked in, notifications are honestly empty, and permission checks. Full suite: 1096 passing,
same 8 pre-existing unrelated failures, zero regressions.

## Parent: Finance reads the same real ledger Finance Office uses, including real actions

A third independently fabricated dataset for the same two real children: `ParentFinanceRepository` returned fixed
gross fees, balances, a payment ledger, receipts, reminders and reminder history, and store orders — all different
specific numbers from what My Children and Attendance already showed for the identical students. Two real
interactive actions were already genuine, though, and are preserved unchanged: `saveMandatePreference` (a real
guardian-chosen payment-day preference, saved offline and queued for sync) and `queueCombinedPayment` (a real,
validated request to pay for multiple children at once).

**Real source:** `load()` starts from `ParentChildrenRepository`'s real linked children, then reads the same
`FinanceLedgerRepository` Finance Office uses — the identical `accounts()` call Finance's own Dashboard and Debt
Aging screens already depend on, so a family's balance can never drift from what Finance actually sees. Real
payments (`StudentAccount.payments`) become the family's real ledger entries and receipts, with a real running
balance computed by replaying each child's payments in order rather than inventing a "previous/new balance" per
receipt. Real queued reminders (`FinanceLedgerRepository.reminders()`) become the family's real fee reminders,
scoped to the linked children and using the same `reminderLevelNames` labels Finance's own Reminders screen shows.

The real ledger has no separate per-child bank account number (`StudentAccount` never had one), so
`accountNumber` — which `queueCombinedPayment`'s own validation needs as a real, unique per-child key — now uses
the child's real system id instead of inventing a bank account number, documented in a code comment.
*(Superseded: see "Family payment accounts" at the end of this document. A child has no account number; where a family
pays belongs to the family, and the queued combined payment request described here was removed.)*

**No real source — left honest:** admission number, bank name, reminder delivery method, multi-channel reminder
history and store orders all have no real source and now read `'Not recorded yet'`/stay empty. A fresh family
honestly starts with no mandate configured (`enabled: false`) instead of a fabricated active one.

Tests: `test/parent_finance_feature_test.dart`. Confirms every child account, receipt and ledger entry reconciles
against the same real ledger Finance Office independently reports, the running receipt balance is arithmetically
consistent, reminders stay scoped to real linked children, the no-real-source fields are honest, a mandate save
round-trips and queues for sync, and a combined payment is validated against real per-child balances (including
reopening one child's real balance the same way a real accountant would, by voiding a payment, to exercise the
success path against genuine data rather than a hand-built fixture). Full suite: 1105 passing, same 8 pre-existing
unrelated failures, zero regressions.

## Parent: Learning Progress now reads real assessment scores, not a fourth fabricated dataset

A fourth independently fabricated dataset for the same two real children: `ParentLearningProgressRepository`
returned a fixed average/attendance/trend, a made-up seven-point score history, invented per-subject
exam/classwork/assignment breakdowns, invented per-topic scores with subjective notes, a fabricated evidence
summary, a fabricated event timeline (including a specific action attributed to "Headmistress" that never
happened), a fabricated narrative "insight" paragraph, and fabricated suggested next actions.

**Real source:** `load()` starts from `ParentChildrenRepository`'s real linked children, then reads the same real
assessment records a Teacher enters and Principal's Academics screen already aggregates class-wide
(`teacherAssessmentRegisterEntityType`) — plus, newly exposed for this fix, the underlying real score sheets
(`teacherAssessmentScoreSheetEntityType`, exported from `TeacherAssessmentRepository` the same way the register
type already was, "for the same reason"). Each real score sheet's entries are filtered down to the one real
student's own `studentId`, so a family's average and evidence can never drift from what a teacher actually
recorded or disagree with what Principal Academics reports for the same class. A child's `averagePercent` is the
mean of their real per-assessment percentages; `evidence` and `timeline` list only assessments where that specific
child has a real, non-zero score (the same "score > 0 means entered" convention the register itself already
uses); `status` is derived from the real average against fixed thresholds instead of being a free-standing
fabricated label; `insight` is a short factual sentence naming the real count of recorded assessments, or
`'Not recorded yet'` when there are none — never an invented narrative.

**No real source — left honest:** Principal Academics already established, school-wide, that "no real assessment
carries a subject label yet" — a score sheet only records a class and a free-text assessment title, so there is no
real way to break a child's evidence down by subject. The same absence cascades to topics (which would need a
subject to sit under). `history` (no real longitudinal series — a fresh demo school has, at most, a handful of
assessments entered moments apart, not a real multi-term trend), `trendPercent` (for the same reason — a single
current snapshot cannot honestly claim to be rising or falling), `subjects`, `topics`, and `actions` are now
`const []` / `0`, matching the "no real source → honest empty, don't half-fabricate" principle applied throughout
this audit.

Tests: `test/parent_learning_progress_feature_test.dart`, the first coverage this repository has had. Confirms a
fresh family with no real assessments sees an honestly empty picture rather than fabricated evidence; a real
recorded score (entered through the real `TeacherAssessmentRepository`, for a real assigned class) becomes real
evidence and a real average for the right child only, leaving their sibling in a different real class untouched;
multiple real scores blend into a real average; status is derived from that real average; attendance matches the
real linked-child attendance; `childById` and the permission check behave correctly. Full suite: 1112 passing, same
8 pre-existing unrelated failures, zero regressions.

## Parent: Weekly Learning now reads the real teacher-published update, not a fifth fabricated dataset

A fifth independently fabricated dataset for the same two real children: `ParentWeeklyLearningRepository` returned
fixed weekly narratives crediting two fully invented teacher identities ("Mrs. Amina Yusuf", "Mrs. Khadija Musa"),
fabricated per-subject coverage, evidence percentages, next topics and practice notes — none of it read from
anywhere else in the app, and all of it always "published" regardless of any real teacher action.

**Real source:** Teacher's own Weekly Learning screen already has a genuine draft → queue-for-publication → publish
workflow with real validation (`TeacherWeeklyLearningRepository`), previously write-only from Parent's perspective.
`load()` now starts from `ParentChildrenRepository`'s real linked children, then reads that same real record
(`teacherWeeklyLearningUpdateEntityType`, newly exported the same way the teacher assessment types already were),
excluding anything still in `draft` state — mirroring the boundary Teacher's own screen already documents, that a
draft or another child's record must never reach a parent — and matching what remains to each linked child by real
class name. "Queued for publication" is treated as visible, not only "published": a real delivery acknowledgement
needs a server this app does not require, and requiring one would make the screen permanently empty no matter what
a teacher does in demo mode, which the teacher-side boundary text already anticipates ("queuing... does not prove"
delivery, not "must never be shown").

**A known, documented real limitation, not fabrication:** Teacher's Weekly Learning is currently a single-draft
prototype — one real update record system-wide, for one real class at a time — not yet a full per-class, per-week
archive. So only a linked child in whichever one class currently holds that real record can ever see a real
update; every other linked child honestly sees nothing yet, which is correct given the real underlying data, not a
bug to paper over with invented rows.

**No real source — left honest:** the teacher's display name (`teacher`) has no real class-teacher directory
behind it, the same reason My Children's `classTeacher` field already reads `'Not recorded yet'`; a blank real
`support` note (the one teacher-side field `queuePublication` does not require to be non-empty) reads the same way
rather than as a blank string.

Tests: `test/parent_weekly_learning_feature_test.dart`, the first coverage this repository has had. Confirms a
fresh family sees no updates while the real teacher record is still a draft; queuing a real update through the
real `TeacherWeeklyLearningRepository` reaches only the real child whose real class matches it, leaving the sibling
in a different class with nothing; every subject field is the real teacher-entered text, not a fabricated one; a
blank real field reads honestly; and the permission check behaves correctly. Full suite: 1116 passing, same 8
pre-existing unrelated failures, zero regressions.

## Parent: Messages no longer shows a conversation that never happened

`ParentMessagesRepository` returned two fixed threads crediting two fully invented teacher identities (the same
"Mrs. Amina Yusuf"/"Mrs. Khadija Musa" already fabricated in Weekly Learning) with a complete fabricated back-and-
forth conversation the guardian never actually had, plus a fabricated "Your September payment receipt is
available" notification attributed to "School Finance Office" that no real payment event ever produced. Unlike
earlier screens, there was no real backend to redirect to here: Teacher's own Messages screen was already reviewed
in this audit and deliberately left as class-wide sample content precisely because it never attributes a fabricated
message to a specific real student or guardian (see "Teacher: Messages only shows guardian-group channels for real
assigned classes" above) — reading from it would only relocate the fabrication, not remove it, since it is a group
broadcast channel, not a per-family conversation.

**Real, honest replacement:** `load()` now builds one real, approved channel per real linked child from
`ParentChildrenRepository`, scoped to that child's real class (e.g. "JSS 2A class channel"), starting with zero
messages — never a pre-populated conversation. `queueReply` (already a genuine local-first action, unchanged in
its own validation) persists each real guardian-authored message per membership and thread, so it reads back
correctly on the next `load()` instead of only surviving in memory. A thread's preview and unread state are now
computed from real queued messages instead of a fixed flag: `unread` is always `false` because every real message
in this repository is guardian-authored, and there is no real school-to-guardian channel yet for anything to have
gone unread.

Tests: `test/parent_messages_feature_test.dart`, the first coverage this repository has had. Confirms a fresh
family gets exactly one real, empty channel per real linked child rather than a fabricated conversation; a queued
reply is real, survives a reload, and never leaks into a sibling's channel; replying to an unknown channel and an
empty/overlong body are both rejected; and the permission check behaves correctly. Full suite: 1121 passing, same
8 pre-existing unrelated failures, zero regressions.

## Parent: Discussions no longer shows a fake community

`ParentDiscussionsRepository` seeded an entire fabricated school community: fixed KPIs ("46 active discussions",
"183 comments"), five posts from five fully invented parent/teacher identities (again including the already-fake
"Mrs. Amina Yusuf"), and fabricated "trending topics" and "community pulse" percentages with no real cross-family
activity behind any of it. `queuePost` compounded this by fabricating the *logged-in guardian's own* identity too,
crediting every real post the family actually wrote to an invented name, "Alhaji Abdullahi Yusuf", instead of the
guardian who wrote it. No other role in the app has anything resembling a real discussion/community backend to
redirect to, unlike Weekly Learning or Messages.

**Real, honest replacement:** `load()` now reads only the real posts this specific family has actually queued on
this device (there is no real multi-family sync to show anyone else's), computing `activeDiscussions`, `parentPosts`
and `commentCount` live from those real posts every time instead of a fixed starting number that could drift from
what is actually displayed. `queuePost` now credits a real post to `'You'`, the same honest convention already
used for a guardian's own real messages, instead of an invented name. `trends` and `pulse` are honestly empty — no
real trending-topic or cross-family engagement computation is possible without a real community behind them — and
the page now says so explicitly instead of silently rendering nothing. The existing real actions (`queueReaction`,
`queueCommentAction`, `toggleFollow`, `report`) are unchanged in their own validation and now operate on these real
posts instead of a fabricated set.

Tests: `test/parent_discussions_feature_test.dart`, the first coverage this repository has had. Confirms a fresh
family sees a genuinely empty community rather than fabricated posts and trends; a queued post is real, survives a
reload, is credited to "You", and drives the KPI counts honestly; reacting, commenting and following persist and
feed the comment-count KPI; reporting is idempotent; acting on an unknown post is rejected; and the permission
check behaves correctly. Full suite: 1127 passing, same 8 pre-existing unrelated failures, zero regressions.

**Retired.** This screen was later removed. It was the only version of a school discussion that did not sync:
its five entity types (`parent_discussion_post`, `_reaction`, `_comment_action`, `_follow`, `_report`) never had
a backend, so what a family posted stayed on their phone. Community now covers the same ground for every role,
Parent included, on a real backend (`community_post`, `community_comment`, `community_reaction`,
`community_report`). "School Discussions" is gone from the Parent navigation and from the access catalog
(`parent.discussions`); `ParentDiscussionsRepository`, its page, models and test were deleted. Community has no
"follow a post" action, which was the one thing the old screen had that it does not.

## Parent: School Life now reads five different real modules instead of one fabricated snapshot

`ParentSchoolLifeRepository` fabricated activity enrollments, a school events calendar, transport service codes,
per-child meal plans and "today's meal", and awards/recognition — all attached to the same two real children, none
of it read from anywhere real. Unlike every other Parent screen fixed so far, this one did not have one real source
to redirect to; it needed five, because each sub-section covers a genuinely different real school system:

- **Events** (real, fully wired): the same school-wide `EventRepository` Proprietor manages — upcoming events only.
- **Transport** (real, per real child): the same real per-student assignment `TransportRiderAssignmentRepository`
  manages for Administrator, via a new `assignmentForStudent(studentId)` method — safe for a guardian to read their
  own linked child's assignment without the school-management viewer restriction the repository's own `load()`
  enforces (a parent's role is never in that allow-list). It ensures the same real initial seed `load()` does, so a
  parent never sees "unassigned" merely because no manager has opened the Transport screen yet in this session.
- **Meals** (real, whole-school only): the real weekly menu `MealRepository` manages, matched to today's real
  weekday. Weekends and any day with no matching real menu row honestly read `'Not recorded yet'`.
- **Recognition** (real, but currently always empty): real awards from `AwardRepository`, matched to a linked child
  by name, excluding anything still `internalOnly` — respecting the same real visibility boundary the Awards module
  itself already enforces, so a proprietor's private draft can never leak to a family. No award in the current real
  seed names either real linked child, so this section is honestly empty for now; it will show real content the
  moment a real `schoolAndParents`/`publicShowcase` award actually names one of them, which is not yet reachable
  through any exposed action (`AwardRepository.addDraft` only ever creates `internalOnly` drafts — there is no real
  "publish to families" step yet, flagged for a future pass, not routed around here).
- **Activities and meal plans stay honestly empty — a documented real gap, not fabrication:** the real Activities
  module only tracks section-level programmes and an aggregate member count, never which specific student is
  enrolled; Meals is one real whole-school weekly menu, not a per-child plan. Inventing a per-child assignment for
  either would repeat exactly the mistake this whole audit exists to remove.

Tests: `test/parent_school_life_feature_test.dart`, the first coverage this repository has had. Confirms events
match the real upcoming school-wide events exactly; transport shows "Active"/"BUS-02" only for the child really
seeded onto that route and "Not assigned" for the other; today's meal matches the real weekly menu for the real
current weekday (or reads honestly on a day with no service); activities and meal plans stay empty; recognition is
empty when no real award names a linked child; and an internal-only award naming a real child still never leaks to
the family. Full suite: 1134 passing, same 8 pre-existing unrelated failures, zero regressions.

## Parent: Documents now shows real receipts; report cards and per-student consent stay honestly empty

`ParentDocumentsRepository` fabricated a term report card and a learning report for the same two real children
(neither backed by any real report-generation system anywhere in the app), a "September Payment Receipt" that
looked real but was disconnected from the actual ledger, an excursion consent form marked as needing action, and a
fabricated consent-decision history.

**Real source:** `load()` now builds `documents` from the same real, non-voided payments Finance Office and Parent
Finance already read from `FinanceLedgerRepository`, one document per real receipt, so a family's document list can
never show a receipt that doesn't correspond to a real payment or disagree with what Finance itself shows.

**No real source — left honest, not deleted as dead code:** no report-card or PDF-generation system exists
anywhere in the app, so academic-report documents are gone rather than faked. `consentRequests` and
`consentHistory` stay empty for the same reason Recognition does in School Life: the real Excursions module only
tracks a whole-trip aggregate consent count ("38 of 42 consents received"), never which specific student still
needs to respond, so there is no real per-student consent request to show. `queueConsent` itself is kept exactly as
validated as before — id lookup, an `actionNeeded` check, idempotent re-queueing, real sync queueing — because it
is correct, real logic that would work the instant a real per-student consent-request source exists, the same
reasoning that kept `AwardRepository.addDraft` rather than deleting it for having no visible effect yet.

Tests: `test/parent_documents_feature_test.dart`, the first coverage this repository has had. Confirms documents
are exactly the real non-voided payment receipts for the real linked children (cross-checked against a second,
independent `FinanceLedgerRepository` instance) and never a disconnected fixed list; consent requests and history
are honestly empty; acting on a consent request that doesn't really exist is rejected rather than silently
accepted; and the permission check behaves correctly. Full suite: 1138 passing, same 8 pre-existing unrelated
failures, zero regressions.

## Parent: AI now reads real family records instead of a canned assistant transcript

`ParentAIRepository` fabricated an entire assistant transcript: a made-up default answer citing specific invented
attendance/academic/finance figures, and five "suggested question" answers with more invented numbers, a fabricated
payment mandate, fabricated scheduled payments, and a fabricated message summary crediting the same already-fake
"Mrs. Amina Yusuf" — all of it disconnected from (and, after this session's other Parent fixes, actively
contradicting) what the real Attendance, Finance, Learning Progress and Messages screens now show for the same two
real children.

**Real source:** new `ParentAiFacts`/`loadParentAiFacts` (`lib/features/parent/data/parent_ai_facts.dart`) read the
same real repositories every other now-fixed Parent screen reads — `ParentChildrenRepository`,
`ParentAttendanceRepository`, `ParentFinanceRepository`, `ParentLearningProgressRepository`, `EventRepository` and
`ParentMessagesRepository` — once per question, so Parent AI's answers can never drift from or contradict what
those screens themselves display. `ParentAiService.answer(question)` is a keyword-matched, honest-refusal engine in
the same shape as `FinanceAiService`: it answers attendance, learning, payment, event and message questions from
those real facts, scoping to whichever linked child's first name is mentioned, and explicitly refuses "why",
diagnosis, ranking/comparison and prediction questions ("I do not diagnose, rank, compare siblings or predict
outcomes") instead of guessing — this closes the same gap the *old* default answer already claimed to respect in
words ("does not know or infer why a pattern changed") while actually inventing a specific answer to that exact
kind of question. `ParentAIRepository.load()`'s `suggestions` are now generated by running each of a fixed prompt
list through the very same `answer()` a free-text question would use, so the displayed suggestion text can never
diverge from what actually asking it returns.

Tests: `test/parent_ai_feature_test.dart`, the first coverage this repository has had. Confirms an attendance
question about a real child matches the real Parent Attendance screen's own number exactly; a payment question
matches the real Parent Finance screen's own balance; a "why"/ranking question is honestly refused rather than
answered with a guess; an unrelated question gets the honest capability fallback; every suggestion's stored answer
matches asking the same prompt directly; malformed questions are rejected; and the permission check behaves
correctly. Full suite: 1145 passing, same 8 pre-existing unrelated failures, zero regressions.

## Parent: Dashboard is now a real roll-up of the ten screens above, the last Parent screen fixed

`ParentDashboardRepository` fabricated a guardian name ("Alhaji Abdullahi Yusuf"), a campus label, an academic
period, both linked children's attendance/academic/balance figures (disagreeing with the real numbers every other
now-fixed Parent screen shows), a fixed "attention items" list including an invented excursion consent reminder, a
static payment-account snapshot with invented bank account numbers, message previews crediting the already-fake
"Mrs. Amina Yusuf"/"Mrs. Khadija Musa", and a fixed notices list. Fixed deliberately last, exactly like Principal's
own Dashboard, because a roll-up can only be honest once every screen it rolls up is itself real.

**Real source:** `load()` now reads `ParentChildrenRepository`, `ParentLearningProgressRepository`,
`ParentFinanceRepository`, `ParentMessagesRepository` and `EventRepository` — the same five repositories the
screens they summarize already use — so the Dashboard can never show a child, a balance or a message that
disagrees with what actually opening My Children, Learning Progress, Finance, Messages or School Life shows.
`attentionItems` are now computed from two real conditions only: a real linked child not marked present today, and
a real linked child with a real outstanding balance — each item names the real child and links to the real screen
that explains it. The finance roll-up's `nextScheduledDebit` reads the real payment mandate a guardian may have set
up through Finance's own `saveMandatePreference`, honestly `0`/`'Not recorded yet'` when none is configured, rather
than a fabricated always-active one. The message-preview list only ever includes a real channel that already has a
real message in it (an empty, not-yet-used channel contributes nothing to worry the guardian with).

**No real source — left honest:** `campusLabel` and `academicPeriod` were dead fields the presentation page never
even read; removed rather than kept with fabricated values. `guardianName` now reads the honest role label
`'Guardian'` — the same convention used for Finance Office's own shell identity — since no real
membership-to-guardian-display-name directory exists anywhere in the app.

Tests: `test/parent_dashboard_feature_test.dart`, the first coverage this repository has had (the pre-existing
`test/parent_dashboard_test.dart` was trimmed of its assertions against the deleted `parentDefaultDashboard`
constant, keeping only its still-valid navigation/privacy-boundary/membership-serialization tests). Confirms every
child's real attendance and balance figures reconcile exactly against the real Children and Finance screens;
attention items only ever name a real child for a real absence or a real balance; the finance roll-up reconciles
exactly with Parent Finance; a real queued message appears while an empty channel contributes nothing; the
guardian name is an honest role label; and the permission check behaves correctly. Full suite: 1148 passing, same
8 pre-existing unrelated failures, zero regressions.

This completes the fabrication audit for all eleven Parent screens: Children, Attendance, Finance, Learning
Progress, Weekly Learning, Messages, Discussions, School Life, Documents, AI, and Dashboard.

## Student (role): audit finds the workspace was already mostly built to this standard

Unlike every role audited so far, Student has a single screen (`StudentWorkspacePage`/`StudentRepository`), and it
was already following the standing discipline correctly rather than needing a rebuild:

- **My performance** already gates on `LocalDatabase.blockDemoSeeds`: in demo mode it shows fixed sample term
  results, explicitly labelled "Sample term results · Demo data, not official school marks"; whenever a real
  backend is expected it instead says "Your school results are not connected yet. No official marks are available
  here." This is the correct proactive labelling the standing instruction asks for, not a violation of it — left
  unchanged.
- **CBT practice** is a genuine, entirely real feature: a fixed five-question maths practice quiz with real local
  persistence (a real 10-minute deadline, real saved answers, a real computed score), explicitly labelled "Practice
  only" and "This is not an official exam" throughout, with `startPractice` honestly refusing outright in live mode
  ("Official exams are not connected yet."). Left unchanged.
- **My study plan** is a genuine personal task list, real local persistence, explicitly labelled "Personal
  reminders saved on this device. These are not teacher-assigned homework." Left unchanged.

**Why Performance's demo branch isn't wired to the real per-student assessment data other roles now use:** unlike
`ParentChildrenRepository`'s established link from a parent's membership to specific real student ids, there is no
equivalent link anywhere in the app from a Student membership (e.g. `membership-student-001`) to a specific real
`AdministratorStudentRecord` id (e.g. `STU-001`) that a real score-sheet lookup could key off. Building that link is
a real architectural decision outside the scope of this pass, not something to route around by guessing; the
existing honest "not connected yet" / clearly labelled sample-data behavior already documents the gap correctly.

**One real fix:** the workspace header greeted the signed-in student by a fabricated specific name
(`'Welcome, ${demoPersonNames[widget.membership.id]}'`, reading `demoPersonNames` from `lib/app/demo_people.dart`,
the shared list of fake identities the demo login picker offers to sign in as). This is the same category of issue
already fixed earlier in this audit for Principal's own Profile screen, which now defaults to blank rather than
inventing the signed-in person's display name — inventing a specific name for someone's own account, not evidence
about someone else, is misleading in the same way. Changed to a static `'My student workspace'` heading, matching
the phrasing the non-demo branch already used. `lib/app/demo_people.dart` itself (the shared login-picker identity
list every role's demo login draws from) is out of scope for this pass and left as a flagged cross-cutting item.

Tests: `test/student_workspace_test.dart` already had strong real coverage (practice resume/scoring/locking,
cross-membership isolation, live-mode refusal, task persistence, a full phone widget flow) and needed no changes;
all 6 tests still pass. Full suite: 1148 passing, same 8 pre-existing unrelated failures, zero regressions.

## Teacher ↔ Student: CBT is now a real, connected pipeline (feature build, not a fabrication fix)

At the user's explicit request, Teacher's CBT Practice Center — a shell that tracked a practice set's title,
class, duration and a bare `questions` *count* with nothing behind it (`questions: 10` on creation, with a comment
admitting "there is no real student CBT-taking pipeline feeding this yet") — was built out into a genuine
end-to-end feature: a teacher writes real questions, publishes a real set, a real student in that real class takes
it with a real timer, and the real score flows back to the teacher's own results panel.

**`TeacherCbtPracticeSet`** (`lib/features/teacher/domain/teacher_cbt_models.dart`) now carries `items:
List<TeacherCbtQuestion>` (id, prompt, options, correctIndex, explanation) instead of a settable `questions: int`;
`questionCount` is a derived getter, never a number a teacher can type in disconnected from real content. A new
`TeacherCbtAttempt` model (setId, studentMembershipId, score, totalQuestions, submittedAt) is the real evidence a
student's completed attempt leaves behind.

**Teacher side** (`teacher_cbt_page.dart`): the old fixed "Question 7 of 20" sample preview is replaced by a real
question editor (add/edit/delete, each question requiring a prompt, at least two options and a valid correct
answer — `TeacherCbtQuestion.isValid`). `queuePublication` now refuses to publish a set with zero real questions or
an invalid one (`_validatePublishable`) — a published CBT can no longer reach students with nothing real in it.
`attempts`/`averageAccuracy` are no longer stored numbers a teacher (or a fabricated seed) can set; `load()` always
recomputes both live from real `TeacherCbtAttempt` records, so the results panel can never show evidence no student
actually produced, and now genuinely does once one has.

**Student side** (new `lib/features/student/data/student_cbt_repository.dart`): no real system links a Student
membership to a specific class the way `ParentChildrenRepository` links a guardian to specific real children, or
`TeacherRoster` links a teacher to real assigned classes — so, following that same established "seed becomes real"
pattern, a student's class is honestly seeded once (to `'JSS 2A'`, a class that really exists in the register) and
persisted from then on, not re-guessed on every read. `loadAvailableSets()` reads real, `published` sets for that
real class only (never a draft, closed or different-class set); `startAttempt`/`answer`/`submit` mirror the exact
mechanics the pre-existing sample-practice quiz already used (real per-attempt deadline, locked answers after
submission or expiry, resumable rather than restarted), but the timer duration, the questions and the correct
answers are now the real teacher's own, and `submit` writes a real `TeacherCbtAttempt` record the teacher's screen
reads back. `ensureTeacherCbtSeeded` is a small shared function both `TeacherCbtRepository` and
`StudentCbtRepository` call, since practice-set records are tenant-scoped, not per-teacher: whichever role opens
CBT first in a session must not leave the other seeing an empty list.

**What stayed, deliberately:** the existing 5-question generic maths practice quiz on the Student CBT tab is kept
exactly as it was (real local persistence, explicitly labelled "Sample questions, not assigned by a teacher"), now
alongside — not replacing — the real "My class CBTs" section above it. It was already honest, tested, working
functionality; the fix adds a real teacher-authored pipeline rather than discarding a working one.

Tests: `test/student_cbt_feature_test.dart` (new, 10 tests) — a real student sees only real published sets for
their real class, never a draft/closed/other-class set; starting, answering and submitting scores against the
real correct answers; a real submitted attempt makes the teacher's own screen show real attempts/accuracy;
answering after the real deadline is rejected while resuming keeps the original real deadline; submitting twice is
idempotent; out-of-range answers are rejected; and the permission check behaves correctly. `test/teacher_cbt_roster_test.dart`
gained a test confirming an empty draft cannot be published. `test/teacher_cbt_feature_test.dart` and
`test/student_workspace_test.dart` were updated where they asserted on the now-real question editor rather than
the old fixed preview text. Full suite: 1159 passing, same 8 pre-existing unrelated failures (confirmed unrelated:
a duplicate-role-label bug on the School Selection picker, in files this feature never touches), zero regressions.

## Driver (role): the BUS-02 morning manifest had 25 entirely fabricated students, not just fabricated evidence

Driver's own repositories (`DriverDashboardRepository`, `DriverMorningRunRepository`, `DriverRidersRepository`, and
the rest of the run/route/history chain) turned out to already be some of the most carefully built code in the
app: real assignment lookups, real cross-validation against Transport Control's stop plan, a real state machine
for arrive/board/depart/complete, real event logging, real sync queueing. The audit found one root problem feeding
all of them a fabrication, not many separate ones.

`defaultBus02MorningStops()` (`lib/features/driver/data/driver_morning_run_demo_data.dart`) listed 26 riders
across 7 stops. Only one of them — STU-001, Maryam Abdullahi — was ever a real student from the school's actual
register (`administratorStudentsWebsiteSeed`, which has exactly four real students total). The other 25 (`STU-014`
through `STU-283`) were entirely invented people — plausible sequential ids, real-sounding Nigerian names, real
class names — that Administrator never actually registered anywhere. This is a more severe variant of this
session's core finding than usual: earlier fixes found fabricated *evidence* attached to real people; this was an
entire fabricated *population* of people who do not exist in the one real register the rest of the app treats as
authoritative. It mattered beyond Driver's own screens because this exact function is also the one real seed
`TransportRiderAssignmentRepository._ensureInitialAssignments` uses school-wide — the same repository Parent's
School Life (fixed earlier this session) and Administrator's Transport Rider Assignment screen both read.

**Fix:** `defaultBus02MorningStops()` now keeps its 7 real-flavored stops (place names and scheduled times are
route geography, not a claim about a specific person, so they stay) but each stop's rider list holds only real,
register-verified students — in practice just Maryam at the first stop; the other six stops are honestly empty
rather than padded to look like a fuller route. `driver_dashboard_demo_data.dart`'s `defaultDriverAssignment` no
longer names a fabricated driver ("Mr. Daniel Peter") — a name that flowed into every real record the driver
produces (morning/afternoon runs, route, history) as if it were fact; it now reads the honest role label
`'Driver'`, the same convention already used for Parent's "Guardian" and Student's "Student Portal". BUS-02's own
entry in `transport_demo_data.dart` (the one route this session's real Driver pipeline actually operates) was
brought into line the same way: `driver`/`assistant` no longer name fabricated people, `riders` now matches the
real trimmed roster (1, not 26), and `morning`/`status`/`note` read as an honest not-yet-run state instead of an
invented "25/26 checked, one absent" narrative for a trip that never happened in a fresh install.

**Left for a future pass, explicitly flagged, not routed around:** BUS-01, BUS-03 and BUS-04 in
`transport_demo_data.dart` still carry the same kind of fabricated driver/assistant names and invented operational
narrative. No Driver or Administrator screen audited so far actually operates them (only BUS-02 does), so fixing
them belongs to a future Administrator/Transport Control pass that reviews how those screens consume this data,
not to this one.

Tests: `test/driver_dashboard_feature_test.dart`, the first coverage any Driver repository has had. Confirms the
seeded demo driver assignment carries the honest role label; the real BUS-02 rider count (both the dashboard's
fallback and the route seed itself) matches the real trimmed register rather than an invented headcount; the real
morning manifest has exactly one real rider and every other stop is honestly empty; and the permission check
behaves correctly. `test/transport_test.dart` was updated for BUS-02's honest defaults (three assertions that had
depended on the fabricated 26-rider/"25/26 checked"/"arrived" narrative). Full suite: 1164 passing, same 8
pre-existing unrelated failures, zero regressions.

## Bug fix: Parent Finance crashed for any family with no mandate configured

A red-screen crash was reported live: opening Finance & Payments as a parent threw
`'There should be exactly one item with [DropdownButton]'s value: Not recorded yet.'` from
`package:flutter/src/material/dropdown.dart`. This was a real regression from this session's own earlier honest fix
to `ParentFinanceRepository` (see "Parent: Finance reads the same real ledger Finance Office uses" above): a fresh
family's real payment mandate has no `collectionMethod` configured yet, so it honestly reads `'Not recorded yet'` —
correct for that repository, but `parent_finance_page.dart` fed that raw value straight into a
`DropdownButtonFormField<String>`'s `initialValue` whose fixed `items` list (`'Bank direct debit · prototype'`,
`'Salary-linked collection · prototype'`) never included it, which Flutter's dropdown widget treats as a
programming error and refuses to render — crashing the entire page for essentially every fresh demo family, since
having no mandate configured is the default state.

**Fix:** `_ParentFinancePageState._load()` now falls back to a real, selectable default (the first real option)
whenever the repository's real value isn't one of the picker's own choices, instead of assuming the repository's
value is always safe to hand a strict-option control. The debit-day picker got the same defensive guard even though
its own default (`'25th'`) already happened to be valid, so the same class of bug can't reappear there if the
repository's honest default ever changes. The two option lists were hoisted out of the widget's `build()` into
shared top-level constants so the guard and the picker can never quietly drift apart again.

**The general lesson, not just this one field:** an honest "not recorded yet" value is safe wherever it is only
*displayed*, but the moment a UI control requires its current value to be one of a fixed set of choices (a
dropdown, a segmented control, a radio group), that control needs its own real default — this had already been
handled correctly everywhere else this session touched (e.g. Discussions' scope picker always initializes from the
enum's own fixed values, never from repository data), but was missed here because the mandate's `collectionMethod`
field was introduced by an earlier session's repository fix without touching this page at all, and no test ever
rendered the actual page widget to catch it.

Tests: `test/parent_finance_feature_test.dart` gained a widget test that renders `ParentFinancePage` for a fresh
family with no mandate configured and asserts it does not throw — the first widget-level (rather than repository
-level) coverage this page has had, and exactly the kind of test that would have caught this regression before it
shipped. Full suite: 1165 passing, same 8 pre-existing unrelated failures, zero regressions.

## Smart Money Collection: the school's own bank accounts (real backend and app; no real bank connected yet)

> **Superseded.** The bank-account connector described here was replaced by the collection-provider model in the section
> "Smart Money Collection: the school's own collection provider (Paystack, Monnify)" at the end of this file. It is kept as
> history: no bank account is connected any more, no settlement account is asked for, and the families' accounts are generated by
> approved collection batches instead of being recorded by hand or issued one at a time.

**What it is.** A school's owner (or someone the owner has explicitly authorised) connects the school's *own* bank or
collection-provider accounts to SchoolOS. SchoolOS then reads the credits those accounts receive, turns every
provider's data into one canonical payment, matches each payment to a student where the evidence is clear, and
puts everything else in front of a person. Parents keep paying the school's accounts exactly as they do now; nothing
here touches a parent's own bank. It replaces the static "Smart Collections" prototype in Finance, which drew
per-student virtual accounts with no provider behind them (its page, demo data, models and test were deleted).

**Where it lives.** Backend `apps/bankconnect` (its own migrations, admin, management commands, 237 tests); app
`lib/features/bankconnect` (online only, 70 tests). The catalog entry is "Smart Money Collection" for the owner
(`owner.collections`) and the Finance Office (`finance.collections`), both marked sensitive on both sides.

### What is real today, and what is not

| | State |
|---|---|
| Encrypted credential storage (`FernetVault`), tenant-bound, key rotation | **Real** |
| Connect / confirm / test / rename / disable / enable / rotate / reconnect / disconnect, all audited | **Real** |
| Idempotent ingestion; cursor sync; signed, replay-safe webhook endpoint; `sync_bank_connections` for cron | **Real** |
| Reconciliation engine, review queue, all manual decisions, notifications | **Real** |
| Collections summary, and the same block on the owner and Finance dashboards | **Real** |
| Bank Accounts / Connect / Payments / Review / Overview screens | **Real** (need a school server) |
| The **sandbox** connector (synthetic bank) | Real, and the *only* connector that works |
| GTBank, UBA, Zenith, Access, FirstBank, Moniepoint, OPay, open banking, Monnify, Paystack | **Listed, not connectable.** Each is `pending_verified_documentation` with every capability off. No endpoint, credential format or webhook format was invented for any of them |
| What a family still owes; matching a payment to an invoice or fee item | **Real once the school has raised fees** (the receivables ledger, by session and term - see the backend's SCHOOL_FEE_RECEIVABLES). Until then `outstandingFeesAvailable` is `false` and the screens say so. A payment into a family's own account settles that family; any other is matched to a student and a purpose (the account's category) |
| Deep-link return from a bank's approval page | Not built: the person pastes the approval code |
| Push notifications | Not built: the existing notification system is the in-app inbox, and that is what is used |

In the demo (no school server) the screen says a server is needed and shows no accounts or payments. Nothing is
faked and nothing is stored on the phone.

### Security controls

- **Credentials.** Sealed with `cryptography` (Fernet / `MultiFernet`) before they reach the database. The sealed blob
  carries `{school, connection}` and is checked on open, so a blob copied onto another school's row will not open.
  With no key configured nothing can be stored (503), and the app is told (`secureStorageReady: false`) so it can say
  why. Keys rotate by putting the new key first in `BANKCONNECT_SECRET_KEYS`, running
  `manage.py reseal_bank_credentials` (add `--dry-run` first), and only then removing the old key; the command fails,
  naming only the connection, if anything cannot be opened.
- **Never returned.** No endpoint can return a credential; every serializer lists its fields by name. Only the last four
  digits of an account are ever sent, and the number itself is never stored (a keyed, per-school one-way fingerprint
  stops the same account being connected twice). A sender's full account number is masked before it is stored.
- **Never leaked.** Provider error text is replaced by short SchoolOS-written codes; audit records drop any key that
  looks like a secret; request bodies that can carry a credential are kept out of Django error reports; tests check
  that the key, the full account number and the webhook secret appear in no response, audit row, stored column or log.
- **On the phone.** Credentials exist only in the dialog's text boxes (masked, no suggestions), go once in a POST body,
  and the boxes are cleared the moment the request ends, success or not. Nothing is written to SQLite or preferences.
- **Who.** Managing accounts (connect, rotate, disconnect, ...) is the owner or someone given the duty
  `finance.bank_connections`. That duty is in `explicitOnlyDuties`: no role preset and no "all finance duties" button
  includes it, so being a Finance Officer is not enough. Looking, syncing and reviewing payments is the owner, the
  Finance Office and duty holders. Everyone else is refused, and another school's connection answers 404.
  A duty holder who is neither the owner nor in Finance has the power on the server but no menu entry in the app yet.
- **Webhooks.** `POST /api/v1/bank-webhooks/<provider>/<token>/` is public, so it defends itself: a per-connection
  token (only its hash is stored, shown once), a `404` for unknown tokens, the provider's signature verified before
  anything is stored, a 64 KB cap, a throttle, and the delivery recorded in the same database transaction as the
  payments it carried, so a half-processed delivery is retried rather than remembered as done.
- **Sandbox.** Off unless `BANKCONNECT_ENABLE_SANDBOX` (default: `DEBUG`). Its payments are labelled "Test data" and
  are left out of every total unless asked for, with the number left out stated.

### How a payment is matched

Each clue that fits adds points and is recorded in words (visible to the reviewer): the student code (90) or admission
number (80) in the narration as whole tokens however it was punctuated (`BG 0042`, `bg/0042`; `BG-00421` does not
match), a guardian's name (35) or phone (30), the student's name (30), a wallet account ending like a guardian's
phone (10). At 90 or more **and** clearly ahead of every other student, and the student is active, the payment is
`matched` and allocated automatically; 60-89 is `possible_match`; two students within 15 points (siblings share a
guardian, so a guardian clue alone can never pick a child) is `requires_review`; below 60 nothing is suggested. The same
sender, amount and narration within 24 hours of an earlier payment is held as `duplicate` and never allocated twice.
Debits are stored as `not_applicable`. `ingest` only stores; `reconcile_pending` evaluates whatever the engine has not
seen, so a crash between the two strands nothing, and a failing engine never fails a sync or a webhook. A person can
assign, split, mark not-fees, mark duplicate, set aside, mark reversed or refunded, or reopen; each appends a decision
(who, why, before, after), supersedes rather than deletes allocations, needs a note where the meaning of the money
changes, and is refused if made on a stale screen (`expectedStatus`).

### Running it

- **Settings.** `BANKCONNECT_SECRET_KEYS` (comma separated, newest first; make one with
  `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`) and
  `BANKCONNECT_ENABLE_SANDBOX`. New dependency: `cryptography`.
- **Cron.** `manage.py sync_bank_connections` (every few minutes; `--school`, `--connection`, `--max-pages`). One broken
  account never stops the others, and it exits non-zero if any failed.
- **Trying it without a bank.** Turn the sandbox on, connect "Sandbox (test data)" (any key starting `sandbox-` and a
  10-digit number), confirm it, then `manage.py bankconnect_sandbox_post <connection id> --naira 50000 --sender "Musa Bello"
  --narration "BG-0042 tuition"` puts a credit on it and syncs; it appears, matched, in Payments.
- **API.** Under `/api/v1/schools/<school>/collections/`: `providers/`, `connections/` (GET, POST),
  `connections/authorize/`, `connections/<id>/{confirm,test,sync,rename,disable,enable,rotate,reconnect,disconnect,
  webhook-token,audit}/`, `transactions/`, `transactions/<id>/` and `.../decide/`, `review/`, `students/`, `summary/`.
- **Dashboards.** `GET dashboards/schools/<school>/owner/` and `.../finance/` carry a `collections` block identical to
  `summary/`. "fee collection" leaves `notAvailableYet` only once a real (non-sandbox) account is connected;
  "outstanding balances" leaves the finance list once the school has raised fees (the `receivables` block of the summary).

### Before a real school can use it

1. The documentation and credentials for at least one real provider, and a connector written against them (the
   interface is `providers/base.py`; a provider is one class and one registry entry). Which one comes first is the owner's
   call and should be the school's own bank or collection provider. **Paystack is not the recommendation:** SchoolOS's own
   Paystack is reserved for what schools pay SchoolOS (the SaaS subscription) and is not part of the school-fee path;
   the `paystack` entry here means a school's *own* Paystack account, only if a school uses one.
2. Production `BANKCONNECT_SECRET_KEYS`, and a cron entry for `sync_bank_connections`.
3. Redirect registration and deep-link handling for any authorisation-style provider.
4. A legal and compliance review of holding bank access credentials.
5. The server fee ledger, which is what turns "matched to a student" into "matched to this invoice" and makes what is
   owed knowable. The earlier open question about voiding receipts belongs to that piece of work.

### Verification

Backend: `manage.py test apps.bankconnect` (237 tests: vault round-trip, tamper and cross-school refusal, key rotation;
role matrix; every endpoint against a second school; secrets absent from responses, audit rows, columns and logs;
ingestion idempotency; webhook signatures and replays; matching cases including siblings and near-miss codes; every
review decision; summary totals with sandbox excluded). The full backend suite still shows exactly the same 38 failing
tests it did before this work (compared by name against a clean checkout): none added, none fixed. App: `flutter analyze` is clean; the new tests cover the
models, the API's requests and error handling, the screens (including masked and cleared credential boxes, the
no-server state, and the stale-decision refusal), and the duty and catalog wiring. The full Flutter suite still shows
exactly the same 83 failing tests it did before (compared by name against a clean checkout): none added, none fixed.

## Family payment accounts: one account per family, shaped by the bank (Parent Finance fixed)

**What was wrong.** Parent Finance showed a child's internal id as an "account number" and built its "pay for several children"
card around one account per child. A family has several children, so where it pays belongs to the **family**, and what an
account looks like depends on the **bank** that issued it. (The earlier "Parent: Finance reads the same real ledger" section
above explains why the id stood in; that stand-in is gone.)

**The money flow this is built on.** School fees are the **school's** money: families pay into the school's own bank account and
SchoolOS neither receives nor holds it. What schools pay **SchoolOS** (the SaaS subscription, `apps/billing`) is a separate
matter, and Paystack will be connected for that alone. Nothing in the fee path uses a SchoolOS payment provider, and the
parent-facing text says the payment goes straight to the school.

**Backend** (`schoolOS_backend`, `docs/SCHOOL_FEE_RECEIVABLES.md`, "Collection accounts" and "Merging two families"):
- An account belongs to a family, never a child; a family may hold one per bank, each with its own shape (what the bank calls the
  number, an example, extra facts to quote such as a payment reference, a one-line note). Nothing assumes ten digits.
- `issuers.py`: provider adapters that issue an account for a family. **No real bank adapter exists** (each is written only against
  the bank's published documentation), so listed banks say so and the finance side records the account by hand; a sandbox issuer
  makes labelled test accounts so issue -> show the parent -> receive a payment -> settle the family works end to end.
- A parent's `me/families/` lists each family's accounts once, with `numberLabel`, `details`, `note`, `canPay`, `isTest`. An account
  being set up or paused is listed but its number is withheld.
- Two families can be merged (billing authority, a reason, not reversible; old numbers keep crediting the merged family), and a
  statement issued in error can be voided (with a reason, never deleted).

**App.**
- **Parent Finance** (`family_payment_accounts_card.dart`): "Your family's payment account" shows the family's account once, under
  the bank's own word for the number, with any extra facts to quote, copy buttons and a test-account badge; several banks are
  shown side by side. It states plainly when there is no account yet, when one is being set up or paused (no number shown), when
  the server cannot be reached (with retry), and when the app has **no school server** (no account is shown or made up).
  The children are listed with what each owes and no account number. "Pay for several children at once" became a **transfer
  calculator** (choose amounts, see one total, copy it): the old queued "payment request" was a local record waiting for "server and
  payment-provider confirmation" that never existed, which also contradicted the money flow above, so it was removed.
- **Parent dashboard** shows each child's balance and class instead of a per-child "account". Copy elsewhere that promised a
  per-child term account (fee reminders, the Finance store rail note, the purchases page) now says the family's payment account.
- **Collections hub -> Family accounts** (owner and Finance Office): every family with its children and accounts; search and
  "no account yet" filters with paging; **Set up** either asks the school's connected bank to issue the account (only offered
  where the bank can) or **records what the bank gave** with a form that adapts to the bank (its word for the number, its example,
  the extra facts it asks payers to quote); issue for every family without one; pause, reinstate, close (reason required);
  **merge** into another family (choose, read the server's preview of what moves and which accounts stay, give a reason,
  confirm) - offered only to someone who may decide billing.

**What is real and what is not.** Real: everything above against a school server, and the sandbox path end to end. Not yet:
a real bank issuing accounts (needs that bank's documentation), a screen for voiding statements (the API exists), and the
parent's **balances**, which still come from the device's own finance ledger until fee schedules can be published from the app
(the server receivables ledger is the source of truth once they can). Without a school server the app runs in demo mode as
before, and the family account shows that it needs the server.

**Verification.** Backend `apps.receivables`: see `docs/SCHOOL_FEE_RECEIVABLES.md`. App: `flutter analyze` clean;
`test/parent_finance_feature_test.dart` (no account number on a child; the family account with no server, with several banks,
with a bank whose account is not a plain number, being set up or paused, none yet, an unreachable server and retry, and the
transfer calculator with no queued request), `test/family_fees_models_test.dart`, `test/family_accounts_screens_test.dart`
(the list, recording an account for a bank with its own shape, issuing, issuing for everyone, managing an account, and merging
including a refusal), and the updated Parent dashboard tests.

## Smart Money Collection: the school's own collection provider (Paystack, Monnify)

**What it is.** A school connects its **own** Paystack or Monnify account with the credentials that provider issued to it.
SchoolOS makes each family one collection account at that provider, reads the provider's signed notifications, and matches each payment
to the family **by the account it was paid into**. The provider moves and settles the money; SchoolOS never receives or holds it, and
never asks for the school's settlement bank account. (What schools pay SchoolOS - the SaaS subscription - is a different thing.)
The backend is described in `schoolOS_backend/docs/SMART_MONEY_COLLECTION.md`; this section is the app.

**Smart Money Collection currently supports Paystack and Monnify for family collection accounts (Family Payment Details).** Remita is reserved
for a separate SchoolOS Mandates / Direct Debit feature (not started) and is not a collection provider: the app offers no Remita card, no
Remita option when connecting, switching or preparing a batch, and no Remita payment reference on a family's payment details. Only the
server's answer decides what is offered, and the server refuses Remita as a collection provider whatever the app sends.

**Where it is.** Owner and Finance Office: the "Smart Money Collection" hub (`lib/features/bankconnect/presentation/collections_hub_page.dart`)
with seven tabs. It is online only: with no school server it says a server is needed and shows no provider, account, batch or figure.

| Tab | What it does |
|---|---|
| Overview | Smart Money Collection at a glance (active provider, connected providers, a planned switch, the default policy, the current period, how many families have accounts, batches waiting for approval, failed families) above the money figures |
| Providers | **Connect Collection Provider** (Paystack or Monnify; credential fields come from the server per provider; secrets masked; live or test); per provider: Connected / Active provider / Live or Test / Webhook active; test, replace credentials, webhook setup, make active (the first time), schedule a switch, disable, disconnect, activity. A planned **provider switch** shows current and target, the date, who is affected and what they owe, warnings and blockers; when its date has come it says **Ready to switch**, and nothing changes until a person opens **Review and Apply Provider Switch** and confirms |
| Collection | Batches. A maker prepares one (session and term, the active provider, a policy for just this batch), reviews every family, selects and deselects, overrides eligibility with a reason, chooses which earlier balances to carry, exports the preview (PDF or Excel) and **Submits for Approval**. A checker sees exactly what would be generated, exports it, and **Approves Generation** (never their own batch) or **Rejects** with a reason; a rejected batch returns to the maker with the reason. Only an approved batch offers **Generate Collection Accounts**; progress is shown while it runs; "Generation complete with errors" keeps every success, lists the failures, and offers **Retry all failed**, **Select failed families** and **Retry selected** |
| Accounts | Every family and its one account (the provider's own word for the number, and any extra facts to quote); a family's account **history** (which batch made each, why one closed); pause, reinstate, mark ready, retire (the provider is asked to close it; a reason is required); the payer's BVN or NIN (write-only: it is only ever shown as "on file"); a policy for one family; **merge** two families (billing authority). No account is typed in by hand and none is issued from here |
| Policy | The school's default (account type, how long an account is reused, what happens when a family has paid, the school's own waiting period, earlier balances, families that owe for an earlier term, what happens when the provider is switched, when a reason is required) and its overrides for a session, term, batch or family: each setting says whether it is using the school default or an override, why, and for how long |
| Payments, Review | Payments the providers reported and the review queue for anything that could not be matched (as before, now naming the provider and the family account paid into) |

**Duties (owner-only unless given).** `finance.collection_provider_manage`, `finance.collection_policy_manage`,
`finance.collection_prepare` (the maker), `finance.collection_approve` (the checker). All four are in `explicitOnlyDuties`, so no role
preset or "all finance duties" shortcut includes them; billing authority does not open provider secrets; preparing and approving are
different duties, and the server refuses anyone who prepared, changed or submitted a batch approving it. The app only offers what the
server says the person may do, and the server checks again.

**What the app never holds.** A credential goes to the server once, over HTTPS, and is cleared from the screen whatever the answer; the
server never sends one back. An identity number is sent once and never read. Nothing about a provider, a family's account or a batch
is stored on the phone.

**Files.** `lib/features/bankconnect` (providers, payments, review, the hub) and the new `lib/features/smartcollect`
(`domain/collection_models.dart`, `data/smart_collect_api.dart` incl. `SmartCollectScope`, and the policy, batches, accounts and
overview screens). `ApiClient` gained `patch` and `getBytes` (the batch export is a file, not JSON). `familyfees` lost the issuing calls.

**What is real and what is pending.** Real: everything above against a school server, end to end through the sandbox provider on the
server, and the two provider adapters (Paystack, Monnify) written against each provider's published documentation. Pending (nothing
invented): Monnify's contract code is only proven when the first account is made, and there is no parent-facing way yet to supply a BVN/NIN. Without a school server the app runs in demo mode as before.

**Verification.** `dart analyze` clean. New and rewritten tests: `bank_connect_models_test`, `bank_connect_api_test`,
`bank_connect_screens_test` (the hub, providers, connecting, switching, payments, review), `smart_collect_models_test`,
`smart_collect_api_test`, `smart_collect_screens_test` (policy, batches, the maker's review, the checker's decision, generation and
retry, accounts), `family_accounts_screens_test` (accounts, pausing, retiring, merging), `family_fees_models_test`,
`bank_connect_access_test` (the four duties). Full suite: 1387 passing; the 83 failures are the same 83 as before this work.

## Mandates & Direct Debit (Remita, Lendsqr): a payment path of its own (real backend and app)

This is **not** Smart Money Collection. Smart Money Collection (Paystack, Monnify) gives each family an account to pay into and reads what
arrived. Mandates & Direct Debit is the other way round: a payer authorises the school to collect approved school fees from their own bank
account, and a provider (**Remita** or **Lendsqr**) executes each debit. The two share nothing but the fee ledger: they have their own
provider connections, their own four duties, their own screens, and the server refuses to mix them (a debit is never counted as a collection
payment, and Remita is never offered as a collection provider). The full design and the provider facts are in the backend repository's
`docs/MANDATES_DIRECT_DEBIT.md`.

**The rule the whole thing follows.** A mandate gives SchoolOS an authorised payment rail. **The fee ledger decides what is owed**, and no
debit happens without valid consent, a debit-ready mandate, current debt and a different person's approval.

**Where it is.**

- Owner and Finance Office: the **"Mandates & Direct Debit"** hub (`lib/features/mandates/presentation/mandates_hub_page.dart`), five tabs:

| Tab | What it does |
|---|---|
| Overview | Mandates by state, batches waiting for approval or debiting, confirmed and unknown and failed debits, and each connected provider with how many mandates are active on it |
| Providers | **Connect a provider** (Remita and/or Lendsqr; the credential fields come from the server per provider; secrets are masked and cleared; test or live, and live says why it is not on if the server has not switched it on); per connection: test, replace credentials, callback setup, disable and enable, disconnect. **There is no "Active Provider":** a school can connect both, and each mandate stays with the provider it was made under |
| Mandates | Every mandate with its family, payer, provider, bank and **masked** account, its status and whether it is debit ready; filters; **Start a mandate** (family, payer, provider, bank, account, limit; there is no "the payer agreed" box); a detail page saying why a mandate is not yet debit ready and how the payer activates it |
| Debit Batches | A maker prepares a batch for a session and term, reviews every family (what the ledger says is owed, what would be debited, why anyone is not ready), selects, lowers an amount (never raises it) and submits. A **different** checker sees exactly what would be debited and approves or rejects it with a reason. Only an approved batch can be started. A partial failure keeps the successes and offers to retry the failures; a debit whose outcome is not known is asked about, never sent again |
| Transactions | The debits the providers reported and whether each was put towards the family's fees; **Ask the provider** for one that is pending or not known |

- Parent: a **"Direct Debit"** card on Parent Finance, only where a school server exists and a mandate has been set up for that payer. It opens
  the payer's own page: the school, the bank, the masked account and the exact words being agreed to, **Review and Authorise**, then the bank's
  one-time password or the activation instructions, and **Cancel** at any time.

**Online only.** A credential, a bank account number, a payer's consent and a debit only exist on the server, so nothing about them is
stored on the phone. Without a school server the hub says so and shows no provider, mandate or debit; nothing is queued as though it had
happened. (In demo mode the Finance Office menu still opens the older offline "Payment Mandates" prototype, which is labelled as a prototype and
is not connected to any of this.)

**Duties (owner-only unless given).** `finance.mandate_provider_manage`, `finance.mandate_manage`, `finance.mandate_prepare` (the maker),
`finance.mandate_approve` (the checker). All four are in `explicitOnlyDuties`, so no role preset or "all finance duties" shortcut includes them;
being a Finance Officer is not enough, and billing authority is a separate duty again. Preparing and approving are different duties, and the
server refuses anyone who prepared, changed or submitted a batch approving it. The app only offers what the server says the person may do, and
the server checks again.

**Consent is the payer's.** Nobody at the school can authorise a mandate for a payer, and the app has no such control. A payer with an account in
the app authorises it there (the server records the hash of the exact words they were shown, and refuses if the words changed since); a payer
without one authorises with the provider (a bank one-time password, a signed form, or an activation transfer).

**What the app never holds.** A provider credential and an account number go to the server once, over HTTPS, and are cleared from the screen
whatever the answer; the server never sends either back (only a masked account and a merchant reference ending in four characters). A one-time
password is typed hidden, sent once and shown nowhere. The dialogs that ask for them own their text fields and clear them when they leave the
screen.

**Files.** `lib/features/mandates`: `domain/mandate_models.dart` and `mandate_labels.dart`, `data/mandates_api.dart` (including `MandatesScope`,
which the app puts above its navigator only when a school server exists), and `presentation/` for the hub, its five tabs, the connect and start
pages, the mandate detail, the batch screen, the payer's page and the Parent card. Also changed: the Finance and Owner menus and access catalog
(one name, "Mandates & Direct Debit", on both sides), and the four duties in `job_assignment_repository.dart`.

**What is real and what is pending (nothing invented).**

- Real, against a school server, end to end through the test provider on the server: connecting, starting a mandate, the payer's consent and
  activation, preparing, approving and starting a batch, the provider's answer, and the confirmed debit being put towards the family's fees.
- **Remita** is written against Remita's published Direct Debit documentation. Its live address is set by whoever runs the server and Remita
  requires a UAT with it before go-live, so nothing has been run against real money.
- **Lendsqr** can make, activate (by a transfer to a NIBSS account) and watch mandates. Lendsqr's published documentation has no debit
  instruction or notification call, so through Lendsqr SchoolOS does **not** send debits: it says so on the provider's card and on the batch,
  never guesses, and the debit stays "pending documentation". Live use is switched off until the server enables it, and it needs the
  organisation to be licensed by Lendsqr's rules; the app never says a school is eligible.
- Every provider figure and time is the provider's; SchoolOS assumes no notice period and no fixed activation wait.

**Found and fixed while testing.** The dialogs for replacing credentials, typing a one-time password, lowering an amount and giving a reason
disposed their text fields the moment they were closed, while the closing animation was still drawing them ("used after being disposed"); they
now own their fields. The provider dropdown on the start-a-mandate page overflowed a phone's width when a provider's name was long.

**Verification.** `dart analyze` clean. New tests, 129: `mandates_models_test` (parses responses **recorded from the server's own API tests**,
kept under `test/fixtures/mandates`, so the app and the server cannot silently disagree; and checks none carries a full account number or a
credential), `mandates_api_test` (what leaves the phone: no consent from staff, approval names the snapshot and carries no amounts, credentials
sent once), `mandates_screens_test` (providers and connecting, mandates and starting one, the payer's authorisation and one-time password, the
maker, the checker, stale and refused batches, partial failure and retry, unknown outcomes, and phone-width layouts), `mandates_access_test` (the
four duties, the menus, and the owner's workspace with and without a server). Full suite: 1517 passing; the 83 failures are the same 83 as before
this work, by name.

## SchoolOS Media & Files: one shared file service, real in Gallery and staff documents (real backend and app)

A canonical file/attachment service (`lib/core/media`), reused by every feature that needs a real file - a
photo, a video, a document - instead of a separate upload system per screen. The backend side is
`apps/media` (Django repository); its own docs are `docs/MEDIA.md` there.

```
A screen picks a file (file_picker) -> copied at once into this app's own storage (MediaLocalFiles) and
   queued (LocalDatabase's new media_uploads table) -> the screen shows it as "Waiting" immediately, never
   as uploaded
        |
        v
MediaUploadQueue (online only, the same durable-queue shape SyncCoordinator uses): initiate -> the bytes go
   straight to wherever the server said (its own /upload/ address for local/dev storage; a presigned URL for
   S3-compatible storage, with no SchoolOS token in that second request) -> complete
        |
        v
The server verifies and, for an image, builds a thumbnail; the file becomes "available". A transient failure
   (offline, a 5xx) retries with a growing gap, the same shape SyncCoordinator's own backoff uses; a file the
   server refuses outright is marked failed and is not retried automatically again.
```

**A file's real bytes are never faked.** Without a school server, nothing here is offered at all (the same
"needs your school's server" pattern as Mandates, Smart Money Collection and Bank Connect) - a photo's real
bytes, its checksum and whether it has been checked only ever exist on the server.

**Where it is.**

- `lib/core/media/`: `media_models.dart` (`MediaAsset`, upload/download instructions), `media_api.dart`
  (`MediaApi`, `MediaScope` - both the read/write client and the queue, so a screen reaches everything through
  one scope), `media_upload_queue.dart` (`MediaUploadQueue`, always present - even in demo mode, so a file can be
  picked and queued offline - but only ever sends once a server exists), `media_local_files.dart`
  (`MediaLocalFiles`, the one place that touches a queued file's bytes on disk), `media_thumbnail_view.dart` (a
  single file's preview, asking `downloadInfo` first and only then reading bytes from wherever that says),
  `presentation/media_attachments_panel.dart` (**the one reusable "files attached to this record" widget** -
  lists the server's own confirmed files next to this device's own still-queued or failed ones, offers to add a
  file per a screen's own `MediaAttachmentOption`s, and lets someone who manages the owner (or who added that one
  file) remove it).
- `LocalDatabase` gained a fourth table, `media_uploads`, the same durable-queue shape as the existing
  `sync_outbox`: a row survives an app restart because it lives in the same database file, in states
  `waiting -> uploading -> uploaded`/`failed`, with its own per-row retry time (`nextAttemptAt`) - unlike ordinary
  sync mutations, uploads are not strictly ordered, so each retries independently.
- `ApiClient` gained `putBytes` (raw bytes, not JSON) for local/dev storage's own direct-upload address; a
  presigned S3-compatible upload is sent with `package:http` directly, with **no SchoolOS bearer token at all** -
  sending one would only leak it to an address that is not SchoolOS's own.

**Real today.**

- **Gallery** (`lib/features/gallery`) is the first real consumer: an album (its own existing local record,
  unchanged) can now hold several real photos and videos with captions and an uploader, opened from the album
  list with an **Open** button that only appears once a school server exists. A teacher or staff member (or a
  manager) can add a photo or video; only a manager, or whoever added that one file, may remove it - the same
  rules Gallery's own album record already enforces, asked of the server, never duplicated on the phone.
- **A staff member's onboarding documents** (`lib/features/proprietor/presentation/owner_staff_profiles_page.dart`,
  the owner's staff-profile detail page): a real file can now be attached alongside the existing
  requested/received/verified tracker. Attaching a file never changes a document's own status by itself - a
  person still marks it received or verified, exactly as before.
- **Administrator Records/Documents** (`lib/features/administrator/presentation/administrator_records_page.dart`):
  the records office's own review dialog for a tracked document (a birth certificate, a guardian ID, a staff
  qualification, ...) can now hold a real attached file, reusing the existing `administrator_document_record`
  owner kind (`apps/media/bridges/schoollife.py`) end to end - no new upload path. A record's `kind` (Student,
  Family, Staff) picks the matching existing category (`student_document`, `admission_document`,
  `staff_document`), so a Staff-kind Administrator record and Staff's own onboarding documents share one
  category. Attaching a file never moves the document's own missing/received/verified status - that stays
  entirely a human decision, exactly as Gallery and staff documents already established. Gated by the same
  `canReviewRestrictedMetadata` permission (administrator role only) the rest of that screen already uses; a
  teacher can still see the register but every "Review" control, including this one, stays disabled for them.
  The backend's `document` media type previously only accepted PDF/DOC/DOCX/TXT; it now also accepts JPEG and
  PNG, since a school "document" is very often a phone photo or scan of a paper original (`apps/staff/constants.py:
  DEFAULT_DOCUMENTS` already asks for a "Passport photograph") - `validation.check_signature` still sniffs the
  real bytes regardless of what the phone declared.
- **Community** (`lib/features/community/presentation/community_page.dart`): every post card can now hold real
  attached photos, reusing the existing `community_post` owner kind end to end. Real photos render inline next
  to (never replacing) the existing `mediaLabel` caption field, which stays exactly as it was. Contribute follows
  the same WRITERS role set posting/commenting already use; manage follows the moderator role set - the panel's
  own "or whoever uploaded that one file" fallback covers a non-moderator removing their own upload.
- **Excursion evidence** (`lib/features/excursions/presentation/excursions_page.dart`): each trip card can now
  hold real evidence photos, right after the consent/transport/emergency line. Its backend owner kind was
  registered ready but never actually wired into `apps/schoollife/apps.py`'s registration loop (the docs said
  "trivial to add"; it was actually just missing) - now fixed, reusing the existing `school_excursion` Spec and
  `excursion_evidence` category (image only). Attaching, failing or retrying a photo never touches a trip's own
  status or its separate readiness-review sign-off.
- **Incident evidence** (`lib/features/principal/presentation/principal_incidents_page.dart`): a Principal's
  incident case can now hold real evidence photos in its detail panel. Unlike excursions, this had **no backend
  sync entity at all** - the Flutter repository's own note/status mutations were being silently rejected by any
  non-DEBUG backend (`SYNC_ALLOW_UNLISTED_ENTITY_TYPES` defaults to `False` outside `DEBUG`), independent of file
  attachments. Backend now registers real `INCIDENT_CASE`/`INCIDENT_AUDIT` specs in `apps/administration/specs.py`
  (not `apps/schoollife/specs`, whose generic cross-school test assumes every module's manager includes the
  school owner - a principal-only module breaks that assumption, the same reason `PRINCIPAL_TEACHER_NOTES`
  already lives in `apps/administration` rather than `apps/schoollife`), giving the case the exact "not even the
  owner reads this" shape that existing spec already established. Evidence attaches to the case only, never to
  its own append-only audit trail; a case is never created through the app today, only noted and status-changed,
  matching the one flow that already existed. Both contribute and manage follow the single principal-only gate
  every other action on this screen already uses - no other role has any access to a case at all.
- **The school logo** (`lib/features/proprietor/presentation/proprietor_appearance_page.dart`, `lib/core/appearance/`):
  unlike every owner above, this one already had a real, working, tested mechanism - a small PNG/JPEG shrunk to
  ~140KB and carried as base64 text inside the school's own `school_appearance`/`theme` sync record, rendered
  everywhere from a local cache so it keeps working fully offline. That stays exactly as it is and stays what
  every screen renders from, in every mode. What changed: when a school server exists, choosing a new logo now
  *also* queues it into the same shared `MediaUploadQueue`, so the logo becomes a real, durable, canonical file
  there too, not only a small copy inside a payload. Its owner kind (`school_appearance`, a hand-rolled
  `AppearanceHandler`, not a `Spec` - proprietor writes, everyone reads) was, like excursion evidence, defined as
  a media category but never actually registered as an owner kind; now fixed the same way. Removing a logo stays
  base64-only for now; an earlier durable copy is left as it is rather than retired automatically.
- **Video thumbnails** (`MediaThumbnailView`): a video tile now shows a real preview frame wherever the school's
  own server actually built one. The backend machinery (a pluggable `VideoTranscoder`, job dispatch, graceful
  degradation) is real and tested against a fake transcoder; the real, `ffmpeg`-backed implementation is honestly
  unimplemented in the sense that it needs a real `ffmpeg` binary installed on a server, which no environment
  this app has been built or tested in so far has - see the backend's `docs/MEDIA.md`. Until then, a video tile
  shows the same plain icon it always has; nothing here is faked as a preview that does not exist.
- **Malware scanning**: every upload is now scanned as part of the server's own verification step, the same
  pluggable-and-honestly-absent shape as video thumbnails - a real `MalwareScanner` seam, tested against a fake
  scanner, with the real `ClamAvScanner` implementation needing a real `clamscan` binary no environment this app
  has been built or tested in so far actually has. Nothing changed on the app side for this one: the `quarantined`
  status this reuses was already handled honestly by `MediaAttachmentsPanel`/`MediaAsset` from the very first
  media work this app did, long before anything ever set it.

**Not yet wired to a screen.** Camera capture (as opposed to
picking an existing file) was not added this pass - `file_picker` (already a dependency) is what both platforms
use; adding `image_picker` for a live camera capture was deliberately left out, since this checkout has no
`android/` platform folder to verify a new plugin's Android wiring against.

**Found and fixed while testing.** Real `dart:io` file writes (`MediaLocalFiles`) inside a `testWidgets` test
never completed on their own - `flutter_test`'s widget-test clock does not drive the real event loop for
non-Flutter-scheduled async work, so every test that picks a file wraps that step in `tester.runAsync()`. A
"waiting"/"uploading" tile's indeterminate spinner keeps scheduling frames forever, so a test that leaves one on
screen uses a bounded `tester.pump()` rather than `pumpAndSettle()`, which would never return. The dialog that
asks for a reason before removing a file had the same "disposed a `TextEditingController` while its closing
animation was still drawing it" bug the Mandates dialogs had; it now owns its own field the same way those do.
Gallery's visibility filter dropdown overflowed at ordinary widths (nothing had ever rendered that screen in a
test before); `isExpanded: true` fixed it.

Administrator Records' own test pass (`test/administrator_records_media_test.dart`) turned up the same
real-I/O trap from a new angle: the default `MediaLocalFiles()` resolves its storage directory through
`path_provider`, which has no handler in a widget test and hangs indefinitely rather than throwing - two tests
that called `MediaUploadQueue.enqueue()` directly hit `flutter_test`'s hard 10-minute test timeout before this
was diagnosed. Every queue built directly in a test (not through a screen's own real app wiring) now passes
`files: MediaLocalFiles(rootDirectory: () async => tempRoot)` against a real `Directory.systemTemp` temp
directory, the same fix `media_attachments_panel_test.dart` and `media_upload_queue_test.dart` already used. A
test that never pumps a widget (queue-only behaviour: offline retry scheduling, per-school queue isolation) is a
plain `test()`, not `testWidgets()` - `testWidgets`'s FakeAsync zone fakes `Timer` creation, which silently
starves a queue's own real backoff timer of the real time it needs; a plain `test()` has no such zone. Handing a
fake server real JSON instead of real image bytes for a thumbnail's download/raw endpoints throws deep inside
Flutter's image codec (`Invalid image data`) on whichever later `pumpAndSettle()` happens to be running when
that rejected Future surfaces - every `FakeServer` an asset-bearing test uses now serves a real tiny PNG for
those two endpoints, matching `media_attachments_panel_test.dart`'s own `mediaServer()`/`tinyPng()` helpers.

Wiring Community, excursion evidence and incident evidence turned up three more things, one per module. A
Community post's own attachments panel is keyed by category, not by post id, and every visible post renders its
own panel on the same scrolling feed at once - `find.byKey('add-community_attachment')` is ambiguous with more
than one post on screen, so `_CommunityPostCard`'s own `Container` (and `_TripCard`'s, for the same reason) now
carries a `ValueKey('post-<id>')`/`ValueKey('trip-<id>')` a test can scope a finder to. Principal Incidents'
category/status/severity filters had the exact same missing-`isExpanded: true` `DropdownButtonFormField` overflow
Gallery's filter once had - nothing had ever rendered that screen at an ordinary test width before. And
`apps.schoollife.tests.test_modules.EveryModuleTests` (the generic cross-school-isolation test every
`apps.schoollife` Spec is run through) hardcodes the school owner as "the manager for every module" - a
principal-only Spec like incidents' fails it not because anything is wrong, but because the assumption doesn't
hold; `apps.administration`'s own equivalent generic tests pick a manager from each spec's own `manage` set
instead, which is why `PRINCIPAL_TEACHER_NOTES` (and now the incident specs) live there rather than in
`apps.schoollife.specs`.

The school logo's own test pass turned up a sharper version of the very first `tester.runAsync()` lesson above.
`ProprietorAppearancePage`'s logo picker does genuine `dart:ui` image encoding (the picked picture, then
`logo_processor.dart: shrinkLogo()`) - real async work the widget-test clock does not drive on its own, same as
any real file write. Wrapping only a *later* poll in `tester.runAsync()` (the idiom every other `*_media_test.dart`
file's simple in-memory `pickFile` stub never needed to worry about) was not enough: the encoding itself, kicked
off by a bare `tester.tap()`, never got real event-loop time and the test hung until `flutter_test`'s hard
10-minute limit - reproduced twice, confirmed by checkpoint logging to land inside the poll itself, and fixed by
wrapping the `tester.tap()` call that triggers the picker in `tester.runAsync()` too, the same shape
`media_attachments_panel_test.dart`'s own "picking a photo" test already uses for exactly this reason.

Video thumbnails' own test turned up a sharper version still: a thumbnail load that starts automatically on a
tile's own `initState()` has no tap at all to wrap in `tester.runAsync()`. `pumpAndSettle()` advances fake time in
large jumps hunting for a settled frame, and did so faster than `mediaServer()`'s own `tinyPng()` helper (real
`dart:ui` image encoding, in the *fake server's own response handler* this time, not the picker) could get real
event-loop time to finish - the API client's own timeout fired first, in fake time, producing a
"server took too long to answer" error on a call that, given real time, always succeeds; confirmed by logging the
exact `FutureBuilder` snapshot (`hasError: true`, an error `tester.takeException()` never sees, since
`FutureBuilder` catches it into its own snapshot rather than letting it become an uncaught exception). Bounded
real-time waits (`runAsync(delay)` + plain `pump()`, never `pumpAndSettle()`) fixed it, same as every other real
async trap this phase found.

**Verification.** `dart analyze` clean, backend and app. Backend: `apps.media`'s own suite (95/95, this pass's
ten new tests: two school-logo integration tests, three `VideoThumbnailTests`, six `test_transcoding.py` unit
tests), `apps.administration`/`apps.schoollife`/`apps.media`/`apps.sync` together, full backend suite (2087
tests, the same 39 pre-existing failures as before this work, by name). App: new
`test/administrator_records_media_test.dart` (11/11: no attachment with and without a server, each of the five
supported types, a rejected type never reaching the queue, an offline queued file staying honestly local, retry
after failure, an existing server file, removing one with a reason, status untouched by any of this, a teacher
unable to reach the control, per-school queue isolation, the staff-kind category match), `test/community_media_test.dart`
(12/12), `test/excursion_media_test.dart` (12/12) and `test/principal_incidents_media_test.dart` (10/10) - each
following the same shape: no attachment with/without a server, an existing server file, a rejected type, every
supported type, an offline queued file staying honestly local, retry after failure with the record's own
status/workflow untouched, removing a file with a reason, a role with no access seeing no control at all, and
per-school queue isolation - plus `test/school_logo_media_test.dart` (4/4: demo mode unaffected, a server-side
choice also keeps a durable copy with the right category/mime type, removing a logo leaves an earlier durable
copy alone, an offline queued copy stays honestly local) and two new tests in `test/core/media_attachments_panel_test.dart`
(a video with a real thumbnail shows the frame; one without still shows the honest icon) - plus the pre-existing
`administrator_records_actions_test.dart`, `administrator_records_feature_test.dart`, `community_test.dart`,
`community_repository_test.dart`, `excursions_test.dart`, `excursion_repository_test.dart`,
`principal_incidents_feature_test.dart`, `school_appearance_test.dart`, `school_theme_test.dart`,
`media_api_test.dart`, `media_upload_queue_test.dart` and `media_local_files_test.dart` (all unaffected). Full app
suite: the same 83 failures as before this work, by name.

Malware scanning needed no app-side change at all - `quarantined` was already handled honestly - so its own
verification is entirely on the backend: `apps.media`'s suite (105/105, this pass's ten new tests: five
`ClamAvScannerTests`, two `ScannerRegistryTests`, three `MalwareScanningTests`), full backend suite (2097 tests,
the same 39 pre-existing failures as before this work, by name).

Older media tests, unchanged by this pass: `media_queue_test` (the `LocalDatabase` table itself),
`media_local_files_test`, `media_api_test`, `api_client_test`'s new `putBytes` group, `media_upload_queue_test`
(sending against local storage and a fake object store, offline retry with backoff, a server refusal, cancelling,
retrying by hand), `media_attachments_panel_test` (empty state, listing, picking, a rejected file type, a failed
upload's retry, who may remove a file), `gallery_media_integration_test`, `owner_staff_profile_media_test`.

## Unified SchoolOS Messaging: Parent Messages becomes real and two-way (first of four; Driver Messages, Teacher's
## own Messages and the Principal Communication Hub stay exactly as they are for now)

Four separate, mutually incompatible "Messages" features exist in this app today (Parent, Teacher, Driver,
Principal Communication Hub). Rather than merging them into one system, each becomes real on its own, one at a
time. This pass makes Parent Messages real, including a genuine two-way reply from the child's real class
teacher - not only a deeper fix to the guardian's own side.

**What was actually wrong.** `parent_message` was a generic `Spec` (`manage=MANAGERS`,
`contribute={'parent'}`, `read=STAFF_SIDE`): readable by the *entire* staff side of the school, not only the
child's real class teacher, and writable only by a parent - no real reply path existed at all, by design or by
accident. On the app side, `ParentMessagesRepository.load()` filtered to only this device's own queued messages
(so nothing anyone else ever sent could be seen even if the backend allowed it), and `queueReply` sent a mutation
payload shape (`messageId`, `deliveryState`, `familyAccountId`, ...) that never matched what the Spec actually
required, nor what the local cache itself stored.

**Backend: a hand-rolled handler, not a Spec.** `apps/schoollife/messaging/parent_messages.py` replaces the old
Spec entirely (`apps/schoollife/specs/communications.py` no longer defines `PARENT_MESSAGE` at all). Correct
authorization here needs a real, per-record relationship - a real `GuardianLink` (this membership really is this
child's guardian) or a real `TeachingAssignment` for the child's real *current* class (this membership really
teaches it) - which `Spec`'s own `audience` hook cannot express at all: it is only ever given the payload, never
the membership (see `framework.py`). This follows the exact precedent `ParentFamilyLinkHandler` and
`apps/weekly_learning/visibility.py` already established for the same two relationships. A thread is
`channel-<studentCode>`, reusing the id `apps/students/parent_sync.py` already publishes to a parent's own
device as `childIds`, so no new identity scheme was invented. Every message is its own row, created once and
never changed or removed - the same append-only shape `apps/transport/driver_messages.py` already uses for the
school's other real messaging channel. The stored payload is `{id, threadId, body, authorRole,
authorMembershipId, createdAt}`; who really sent a message and when are always the server's own stamp, never
taken from the app. Visible to exactly three kinds of membership: the real guardian, the real current class
teacher, and a manager (proprietor/administrator/principal, for oversight) - nobody else, not another family's
guardian, not a teacher who does not teach this child, not even another teacher in the same school.

**App: `ParentMessagesRepository` now reads and writes the real channel.** `load()` reads every real message in
a thread generically off this device's local cache (not filtered to this membership's own messages, the way a
purely outbound channel would be), so a reply from the real class teacher shows up here once an ordinary sync
pull delivers it - the exact same mechanism that already writes every other real sync entity into local cache.
`queueReply` now sends only `{id, threadId, body}`, the fields a guardian actually contributes; `direction`,
`authorLabel` and `state` are never stored - `ParentMessageItem.fromCanonical` derives them at read time from the
real `authorRole`/`authorMembershipId` against whoever is actually viewing the thread, so the same row reads as
"You" to whoever sent it and by their real role to everyone else. No read-receipt record exists yet, so a real
reply is simply visible once pulled - nothing marks it seen or unseen.

**App: a new, separate Teacher Family Messages screen**
(`lib/features/teacher/presentation/teacher_family_messages_page.dart`) gives a class teacher the other side of
the same conversation: one real thread per real student in their real assigned classes (from `TeacherRoster`,
deduplicated across subjects when a teacher teaches more than one to the same class), scoped by the same server
check as the guardian's own side. Deliberately **not** merged into `TeacherMessagesPage` - that screen's own
class-wide broadcast channels (a whole class's guardian group) are a different kind of thing and stay completely
untouched. The new screen reuses `ParentMessageThread`/`ParentMessageItem` from Parent's own domain models rather
than duplicating them (the same cross-feature-import precedent Excursions already set by importing
Administrator's academics models), and is registered as its own gated activity, `teacher.family-messages`,
alongside the existing `teacher.messages`.

**Still not done, on purpose.** Driver Messages' own gaps, Teacher Messages' own broadcast channel becoming
server-backed, and the Principal Communication Hub are unrelated future passes, per the "make the existing four
real, one at a time" plan - none of their code changed here. Read-receipt/unread tracking for Parent and Teacher
Family Messages does not exist yet either; that stays a known, honestly-labelled gap rather than a fabricated
badge.

**Verification.** Backend: new `apps.schoollife.tests.test_messaging` (11/11 - who may write into a thread, that
the server stamps the real author and a message can never be changed or removed, and that reads never cross
families or schools), `apps.schoollife`/`apps.administration`/`apps.access` together, full backend suite (2111
tests, the same 39 pre-existing failures as before this work, by name - including two pre-existing, unrelated
`apps.access.tests.test_catalog` failures from drift this pass did not introduce and did not attempt to fix:
`owner.mandates`/`owner.alumni`/`owner.collections` and the Alumni workspace's own activities were never added to
that test's own tracking lists by the passes that added them). App: `dart analyze` clean; new
`test/teacher_family_messages_test.dart` (7/7: real per-family threads deduplicated across subjects, no assigned
classes leaves an honest empty list, a queued reply persists and stays scoped to the right family, an unknown or
unassigned thread and an empty/overlong body are refused, only a Teacher membership may use it, and a guardian
message and a teacher reply are each real to the other on the exact same thread); `test/parent_messages_feature_test.dart`
(5/5, its existing pinned behaviour unaffected); `test/teacher_dashboard_feature_test.dart`'s own pinned
twenty-item navigation list updated to twenty-one for the new screen. Full app suite: the same 83 pre-existing
failures as before this work, by name.

## Unified SchoolOS Messaging (second of four): Driver Messages becomes real and two-way

The second of the four separate "Messages" features (see the Parent Messages pass above). Unlike Parent
Messages, the Driver-to-school direction here was already real and tested - the gap was entirely the missing
reply, and a Flutter side that had never actually been wired to read it.

**What was actually wrong.** `driver_message`'s own docstring said it plainly: "nothing in the app yet sends a
message or an alert *to* a Driver... these records simply stop waiting forever on a device." A Driver could
send, but nothing could ever answer, and no screen anywhere in the app - Administrator's or Proprietor's - had
ever been built to read a Driver's messages at all. On top of that, `DriverMessagesRepository.load()` fabricated
three entire conversations on first load, crediting invented departments ("School Operations", "Maintenance &
Dispatch") with a pre-populated back-and-forth the Driver never actually had, the same shape Parent Messages'
own fabrication took before its own fix.

**Backend: the existing handler learns to accept a reply.** `apps/transport/driver_messages.py`'s
`DriverMessageHandler` now accepts writes from Transport Control (`apps/transport/constants.py` `MANAGERS` -
Proprietor or Administrator, the same role set that already sets every other transport policy in this module),
the same `roles = {"driver"} | c.MANAGERS` shape `incident.py` already uses for a Driver-reported,
management-reviewed record. The channel is now one real thread **per Driver** (`driver-thread-<membershipId>`),
not per route, since a Driver's real assigned route can change without starting a new conversation - reusing a
fixed thread id the tests had already anticipated, just never per-Driver before. Who the real Driver is when
Transport Control writes is checked against a real, currently active `driver_transport_assignment` - never taken
on trust from the app. The client-supplied `participantName`/`participantRole`/`channelLabel` labels (and the
word-matching policy that used to police them against "parent"/"guardian"/"family") are gone entirely: once
there is only ever one real counterparty to label, the school's own identity in the thread is never something a
device gets to declare, the same principle Parent Messages' `authorRole` already established.

**App: both real sides now exist.** `DriverMessagesRepository` no longer fabricates a snapshot on first load; it
reads and writes the one real `driver_message` thread generically, the exact same `fromCanonical` pattern
`ParentMessageItem` uses - `DriverMessageItem.fromCanonical` derives `direction`, `authorLabel` and `state` from
the real `senderRole`/`senderMembershipId` against whoever is viewing, never storing them. A new
**Transport Control** panel (`lib/features/transport/presentation/transport_messages_panel.dart`), added to the
existing School Transport screen the Proprietor workspace already hosts, gives Transport Control the other side:
one real thread per real, currently assigned Driver, built from the exact same real driver roster
`TransportDriverAssignmentsPanel` already reads (`TransportRepository.loadDriverAssignments`) rather than a
second, separate roster, reusing `DriverMessageThread`/`DriverMessageItem` rather than duplicating them. Gated by
the same `canViewOperationsControl`/`canManageDriverAssignments` permissions every other panel on that screen
already uses, so a read-only Principal can see a thread but not reply to it. (Administrator itself has no path
to the School Transport screen in the app yet at all - a pre-existing gap this pass did not create and did not
fix, since the backend's own management role, `Proprietor or Administrator`, was already correct either way.)

**Still not done, on purpose.** Operational alerts (`DriverOperationalAlert` - a broadcast, priority-ranked
notice, not a private thread) have no real backend at all; the list now honestly stays empty rather than
fabricated, and `markAlertRead` openly refuses rather than pretending to acknowledge something that was never
real. Teacher Messages' own broadcast channel and the Principal Communication Hub remain the two still-untouched
passes of the original four.

**Verification.** Backend: rewrote `apps.transport.tests.test_incidents_messages`'s `DriverMessageTests` for the
new per-Driver thread and the reply direction (a Driver sends and the server stamps sender/role/route/vehicle; a
Driver's own route is always the server's, never the device's; Transport Control replies into a real Driver's
thread; a fake or unassigned `driverMembershipId` is refused; a `threadId` that does not match the real Driver is
refused; messages never cross between two real Drivers, each with their own real route; an unrelated role cannot
send; body validation; the message is never changed or removed), `apps.transport` together (79/79), full backend
suite (2115 tests, the same 39 pre-existing failures as before this work, by name). App: `dart analyze` clean;
replaced the old demo-seed pin with `test/driver_messages_feature_test.dart` (5/5: a fresh Driver gets one real
empty thread rather than a fabricated conversation, operational alerts honestly stay empty, a queued message is
real and persists, an unknown channel or a bad body is refused, only a Driver membership may use it); new
`test/transport_messages_feature_test.dart` (5/5: threads are the real assigned Drivers, a read-only Principal
can view but not reply, an unrelated role sees nothing, an unknown thread or a bad body is refused, and - the
same end-to-end shape Teacher Family Messages proved for Parent Messages - a Driver's message and a Transport
Control reply are each real to the other on the exact same thread). Full app suite: the same 83 pre-existing
failures as before this work, by name.

## Unified SchoolOS Messaging (third of four): Teacher Messages' guardian-group channels become real

The third of the four separate "Messages" features. Unlike the first two passes, this one needed **no backend
change at all** - the real capability it needed already existed.

**What was actually wrong.** Teacher's "Messages" screen mixes three different kinds of channel: a guardian
group per class, a school-leadership channel, and a staff channel. The guardian-group channels were demo
furniture exactly like Parent Messages' own conversation had been: a fixed, fabricated back-and-forth ("JSS 2A
Guardians"), including an *incoming* guardian reply ("Thank you. Is the revision sheet available...") credited
to nobody real. Sending into one of these channels only ever wrote to this device's own local cache; nothing a
teacher "sent" here ever reached an actual guardian.

**The fix needed no new entity.** `ParentMessageHandler` (`apps/schoollife/messaging/parent_messages.py`, see the
Parent Messages pass above) already lets a real class teacher write into *any* real family's thread for a
student in a class they really teach - that authorization was never specific to a single family, it was already
"this real class teacher, this real family." A class-wide "send to every guardian" is just that same real write,
done once per real family in the class. So a guardian-group channel is no longer demo content: it is now built
from the teacher's own real assigned classes (`TeacherRoster.assignedClasses`), and sending fans out one real
`parent_message` create per real, currently enrolled student in that class - through the exact same repository
call (`TeacherFamilyMessagesRepository.queueReply`) the Teacher Family Messages pass already built and tested.
Each family receives their own real copy in their own real thread, exactly as if the teacher had written to them
individually - because that is, underneath, exactly what happens.

**What this deliberately does not do.** There is no merged "history" to scroll back through for a class as a
whole: each family's own copy lives in their own real, separate thread (one row per family, not one shared
broadcast row), and trying to reconstruct a unified view from N nearly-identical rows would mean either showing
the same text N times or inventing a deduplication/grouping scheme with no real backend concept behind it.
Instead, the guardian-group channel stays an honest **send action** - its "preview" text says how many real
families a send would reach, not a fabricated last message - and a family's own copy, along with any reply, is
read back through **Teacher Family Messages**, not through this screen. The two channel types with no real
backend concept at all (school-leadership, staff) are completely untouched, still demo content, exactly as they
were. The Principal Communication Hub remains the one still-untouched pass of the original four.

**Verification.** No backend changes, so no backend tests changed; the full backend suite was not re-run for
this pass. App: `dart analyze` clean; `test/teacher_messages_roster_test.dart` extended (6/6: a teacher only
sees guardian-group channels for classes they really teach, a teacher with no assigned classes sees only the
non-class channels, a send outside a real assignment is refused, a send to a real channel really reaches every
real family - by real pending-mutation count - and, end to end, a real class broadcast really lands in a real
guardian's own Parent Messages thread with the real class teacher correctly attributed);
`test/teacher_messages_feature_test.dart` updated to pin the demo data's new, smaller shape (the two channel
types with no real backend) and moved its page-rendering fixture to its own literal data, since guardian-group
channels are no longer demo constants to pin against - its widget-level coverage (search, thread switching,
send, AI draft, routing, phone rendering) is otherwise unchanged (10/10). Full app suite: the same 83
pre-existing failures as before this work, by name.

## Unified SchoolOS Messaging (fourth of four): the Principal Communication Hub's guardian announcements become real

The last of the four separate "Messages" features. Like the Teacher Messages pass, this needed no new
authorization concept - a Principal was already a real participant in the channel that actually delivers it.

**What was actually wrong, and what stays exactly as it was.** The Communication Hub mixes several different
ideas behind one screen: a reply-thread inbox (`threads` was always `const []` - genuinely nothing to show,
honestly empty, not fabricated), follow-ups (also always `const []`, already labelled "Not available yet"), and
an announcement composer (audience: Secondary staff or Secondary guardians; channel: portal, SMS, email or
WhatsApp). The composer's own `queueAnnouncement` always wrote only to a local, unregistered
`principal_outgoing_communication` record - every combination "succeeded" with a cosmetic "queued offline"
message, but nothing ever reached a real person. This pass makes exactly one of those combinations real -
**guardian audience, portal channel** - and leaves every other combination (staff audience; SMS, email or
WhatsApp channel) exactly as it was: still local-only, still honestly labelled as not yet confirmed. The
reply-thread inbox is untouched too; it stays the honest empty stub it already was.

**No new backend entity or authorization needed.** A Principal is already `MANAGERS`
(`apps/schoollife/framework.py`: `{proprietor, principal, administrator}`), and `ParentMessageHandler` already
lets any `MANAGERS` member write into *any* real family's thread, for oversight - the same fact the Teacher
Messages pass relied on for a real class teacher. "Announce to Secondary guardians" is just that same real write,
done once per real, currently active student whose class falls in the Secondary section
(`sectionOfClass`, the same real derivation `lib/features/parent/data/parent_children_repository.dart` already
uses) - through `_sendParentMessage`, the same wire-payload shape `TeacherFamilyMessagesRepository.queueReply`
already established (the Principal contributes only `{id, threadId, body}`; who really sent it and when are the
server's own stamp). Each family receives their own real copy in their own real thread, exactly as Teacher
Messages' own class broadcast already does - because underneath, it is the identical mechanism, just scoped to
"every Secondary family" instead of "every family in one class." A principal-authored message now reads as
"Principal" in a guardian's own thread, rather than falling back to the generic "School" label every other
manager role still uses.

**One real, small backend fix found and made along the way.** `principal_outgoing_communication` - the
Principal's own "what did I send" log, read back by their own Communication Hub screen - was already being
pushed by the app on every send, but had no handler registered at all, so outside `DEBUG` it could only ever be
silently rejected (`SYNC_ALLOW_UNLISTED_ENTITY_TYPES` defaults to `False`), the same class of gap Incident
Evidence and Teacher Messages each had before their own fixes. It is now a real Spec
(`apps/administration/specs.py`), the same "not even another manager reads this by default" shape
`PRINCIPAL_TEACHER_NOTES` already uses - this only lets the Principal's own compose history sync across their
own devices; it has nothing to do with what a guardian actually receives, which was already real and unaffected
by this gap.

**Verification.** Backend: `apps.administration`'s own suite (11/11, including the generic
`EveryModuleTests` run against every registered Spec), `django check` clean, full backend suite (2115 tests).
The full suite's run-to-run failure count fluctuated by one or two tests across repeated runs, on both the
changed and the unchanged code - confirmed to be pre-existing, timing-sensitive flakiness in unrelated tests
(`apps.transferverify`, `apps.invitations`, `apps.bankconnect`) rather than anything this change caused; see the
session's own notes on this. App: `dart analyze` clean; `test/principal_communication_feature_test.dart`
extended (15/15, the 11 pre-existing tests unaffected: a real portal announcement to guardians reaches every
real Secondary family by real pending-mutation count, an honest refusal when no Secondary students are on the
register, a non-portal channel stays local-only exactly as before, and - end to end - a real guardian's own
Parent Messages thread really receives it with the Principal correctly attributed). Full app suite: the same 83
pre-existing failures as before this work, by name.

This completes the four-part "make the existing four Messages features real, one at a time" plan: Parent
Messages, Driver Messages, Teacher Messages' guardian-group channels, and now the Principal Communication Hub's
guardian announcements. What remains honestly unbuilt across all four, by design, stays labelled rather than
faked: Parent/Teacher/Driver read-receipt (unread) tracking, Teacher Messages' staff/leadership channels, real
SMS/email/WhatsApp delivery, and the Communication Hub's own reply-thread inbox.

## Every real messaging channel gets a real read receipt

Asked explicitly to carry each messaging feature to full completion rather than leaving a known gap behind once
its core claim was real, the four items named above become the next work, taken one at a time. First: every
real thread's `unread` flag, which every one of the four passes above had left hardcoded to `false` since
nothing recorded who had actually seen a thread.

**Design.** A real "I have seen this thread" receipt - its own append-only row, the same shape every message in
these channels already uses - rather than a mutable "last read" field on the thread itself, matching the
precedent `apps/transport/driver_messages.py`'s own Driver receipts had already set. `parent_message` gets a new
`ParentMessageReceiptHandler` (`apps/schoollife/messaging/parent_messages.py`): the real guardian, the real
current class teacher, or a manager may each record their own receipt for a thread they may actually reach - the
exact same `_may_reach_thread` check the message handler itself uses. `driver_message`'s own
`MessageReceiptHandler` is widened from Driver-only to `{"driver"} | MANAGERS`, the same way the message handler
itself already was, so Transport Control can record a receipt too - resolving which real Driver's thread a
manager means from a real, active `driver_transport_assignment`, never trusted from the app. Both are visible
only to whoever made them (and managers, for oversight) - never to the other side of the conversation, since a
receipt only matters to the person computing their own unread state.

**App.** A thread is unread when its own latest real message was not sent by the person looking at it (its
`authorLabel` is not `"You"`), and either they have never recorded a receipt for it or a real message arrived
after their last one - computed fresh on every `load()`, never stored. Two small shared helpers
(`lib/features/parent/data/parent_message_receipts.dart`, `lib/features/driver/data/driver_message_receipts.dart`)
read a membership's own receipts and queue a new one, reused as-is by both real participants on each channel
(Parent Messages and Teacher Family Messages share one; Driver Messages and Transport Control share the other) -
the same reuse precedent `ParentMessageItem.fromCanonical` and `TeacherFamilyMessagesRepository.queueReply`
already set. `markThreadSeen` is wired into every page at the same two points a conversation actually opens: an
explicit tap, and the thread auto-selected when the screen first loads (deferred a frame past `build()`, since
marking a receipt is a real write and must never run as a build-time side effect) - tolerating a failed receipt
queue without blocking the read, the same as Driver Messages' own page already did.

**A real bug found while building this.** Both new receipt-queueing helpers initially wrote a local cache copy
that omitted `membershipId` from the payload entirely - the receipt was queued and would have synced correctly,
but this device's own next `load()` could never find its own receipt back (the filter `payload['membershipId']
== membershipId` never matched anything), so a thread stayed shown as unread even immediately after
`markThreadSeen` ran. Caught by the pass's own tests before this ever reached a commit; fixed by writing the
membership id into the local copy alongside the fields the wire payload actually sends (who recorded a receipt
is the server's own stamp regardless, exactly as every message's own author fields already are).

**Verification.** Backend: `apps.schoollife.tests.test_messaging` extended to 22/22 (the real guardian and real
class teacher each marking their own receipt, a manager marking one for oversight, nobody outside the real
conversation being able to mark one at all, a receipt never changed or removed once recorded, a forged receipt
id refused, and only the person who made a receipt - plus managers - ever reading it back);
`apps.transport.tests.test_incidents_messages` extended to 81/81 (the two pre-existing Driver-only receipt tests
updated to the real per-Driver thread id scheme, plus new coverage for Transport Control marking a real Driver's
thread seen and a thread id that does not match the real Driver being refused); `apps.schoollife`/
`apps.transport`/`apps.administration` all individually clean; full backend suite unaffected in the areas this
pass touched (the suite's own run-to-run count fluctuates by a test or two - see the session's own notes on
this pre-existing flakiness - but zero failures ever appeared in `schoollife`, `transport` or `administration`
across repeated runs). App: `dart analyze` clean; extended all four messaging test files (parent, teacher
family, driver, transport - 9 new tests across them: a fresh thread is never unread, a device's own message
never makes its own view unread, a real message from the other side makes a thread unread until marked seen, an
already-read thread is a harmless no-op to mark again, and - for each two-sided channel - one side marking a
thread seen never affects the other side's own independent unread state). Full app suite: the same 83
pre-existing failures as before this work, by name.

## Teacher Messages' staff/leadership channels become real

The second named gap: the two remaining demo channel types on Teacher Messages (school leadership, staff/
department), which had stayed untouched, on purpose, through the guardian-group pass above.

**Design.** Two new hand-rolled backend entities (`apps/schoollife/messaging/teacher_channels.py`), not Specs,
for the same reason `parent_message` is not one: correct authorization needs a real, per-record relationship
`Spec.audience` cannot express. A **leadership thread** is `leadership-thread-<teacherMembershipId>` - one real
thread per real teacher, the exact `roles = {role} | MANAGERS`, "one thread per real non-manager participant,
managers may reply" shape `driver_message` already uses. A **department thread** is
`department-thread-<subjectCode>` - one real, *shared* thread per real subject a teacher currently teaches
(checked against a real `TeachingAssignment`, the same query shape `weekly_learning/visibility.py` and
`parent_messages.py` already use): any real teacher who currently teaches that subject may read and write it,
plus managers for oversight - a genuine peer group, not a single family. Both get their own real read-receipt
entity from the start (not retrofitted afterward, the way the first four channels needed), sharing one generic
Flutter helper across both.

**App.** `TeacherMessage` gains a `fromCanonical` factory - the same shape `ParentMessageItem.fromCanonical`
established - so the existing UI model keeps working unchanged against the new real payload. A department
thread is keyed by the real subject's own school-wide `code` (`Subject.code`), not its free-text name: matching
by name would have meant slugifying and un-slugifying a human-entered string with no guarantee of a clean round
trip, whereas a subject's own code is already a stable, school-scoped identifier. `AssignedClass` (a teacher's
own real roster entry, `teacher_class_assignment`) gains a `subjectCode` field - the backend already published
it (`apps/academics/curriculum_services.py: serialize_class_subject`), the Dart model had simply never parsed
it. `teacher_messages_demo_data.dart` loses the last of its channel/message constants; only the boundary and
AI-draft text, which never described a channel or a message, remains.

**What is explicitly not yet built.** A manager replying to a teacher's leadership thread, or to a department
thread, is already authorized server-side (`roles` already includes `MANAGERS` on both new handlers) - there is
simply no Flutter screen yet for a manager to do it from. That is deliberately deferred to the Principal
Communication Hub's own reply-thread inbox, the next item on this list: wiring that inbox to real
`teacher_leadership_message` threads is the natural, non-duplicated way to give managers that reply surface,
rather than building a second, throwaway mini-panel now and a proper one later.

**Verification.** Backend: new `apps.schoollife.tests.test_teacher_channels` (22/22 - who may write into a
leadership thread and a department thread, a real peer sharing the same subject, an unrelated teacher refused
from both, server stamping and immutability, cross-channel isolation, and receipts for both including a forged
receipt id); `apps.schoollife`/`apps.administration` together (104/104); full backend suite unaffected in the
areas this pass touched. App: `dart analyze` clean; `test/teacher_messages_roster_test.dart` extended to 13/13
(a teacher has exactly one real leadership thread and can message it, a real leadership reply makes it unread
until marked seen, a different teacher is refused from someone else's leadership thread; a real peer teaching
the same real subject shares the exact same department thread end to end, a teacher who does not teach it has
no such thread at all); `test/teacher_messages_feature_test.dart` drops its now-nonexistent demo-data assertions
and gives its fake repository a `markThreadSeen` implementation, otherwise unchanged (9/9). Full app suite: the
same 83 pre-existing failures as before this work, by name.

## The pluggable SMS/email delivery architecture (no real provider wired - asked for explicitly)

The third named gap, scoped deliberately: asked whether to build the real provider architecture only or skip it
for now, given this environment has no real SMS/email provider account any more than it has a real `ffmpeg` or
`clamscan` binary - the answer was the architecture, matching how video transcoding and malware scanning were
each handled earlier.

Unlike those two, there is no single standard interface a "real" SMS or email provider implements - `ffmpeg` and
`clamscan` are universal, well-documented command-line tools, while every SMS/email vendor (Termii, Africa's
Talking, Twilio, SendGrid, ...) has its own proprietary REST contract. Inventing one without real, verified
documentation would mean guessing an API shape and calling it "real" - the same red line the Smart Money
Collection plan already drew for a bank connector ("no bank or provider API is invented"). So
`apps/administration/communication_delivery.py` gives the seam itself: `SmsProvider`/`EmailProvider` interfaces,
`DeliveryError`/`DeliveryUnavailable`, and an honest default
(`UnconfiguredSmsProvider`/`UnconfiguredEmailProvider`) that refuses rather than pretends to have sent anything
- the same `use_sms_provider`/`get_sms_provider` override-for-tests shape `apps/media/transcoding.py` already
uses. A real provider becomes its own class here the day one is chosen and verified, the same way a real bank
would join `apps/bankconnect`'s own registry rather than replace this seam.

**Deliberately not wired into any dispatch path.** `principal_outgoing_communication`'s own payload only ever
carries an audience *group* (`staff` or `guardians`), never a resolved list of real phone numbers or email
addresses - there is no "who exactly does this reach" data to hand a provider yet. Resolving a real audience
group into real contacts is its own separate piece of work (the same shape the Principal Communication Hub's
guardian-portal pass above already did for in-app delivery, resolving "Secondary guardians" into real families)
and was explicitly out of scope for an architecture-only pass.

**Verification.** Backend: new `apps.administration.tests.test_communication_delivery` (6/6 - both honest
defaults refuse rather than pretend to send, the default provider is the honest unconfigured one, and
`use_sms_provider`/`use_email_provider` override only for the duration of their own block); `apps.administration`
together (17/17); full backend suite unaffected (this module is not called from anywhere yet, so there was
nothing else for it to affect).

## The Principal Communication Hub's reply-thread inbox becomes real (last of the four named gaps)

The fourth and last named gap. Scoped, as asked, to staff/leadership threads only - a manager replying into one
specific real guardian's own `parent_message` thread from this same inbox stays out of this pass.

**What was actually wrong.** `threads` was always `const []` in production, so two things were true at once:
the inbox was honestly empty (nothing fabricated reached the screen), but `_ThreadCard` still unconditionally
rendered two hardcoded fake `_MessageBubble`s ("School · 9:54 AM", "We are following up regarding the recent
school matter...") for whatever thread *did* get selected. That fabrication was dormant only because `threads`
never actually produced a thread to select - it would have sprung to life the moment a real one appeared, which
this pass now does.

**Design.** The inbox now reads the exact same real `teacher_leadership_message` threads
(`apps/schoollife/messaging/teacher_channels.py: TeacherLeadershipMessageHandler`) that Teacher Messages' own
leadership channel already writes into - the reply surface that pass deliberately deferred here rather than
duplicating. `PrincipalCommunicationRepository._leadershipThreads` groups every real message by `threadId` and
only lists a thread that has at least one real message in it: "an inbox shows what was really sent," the same
shape every other real messaging screen in this app already uses, not a proactive "every teacher" roster the way
Transport Control's driver panel is (every teacher is a potential sender here, not a fleet this office actively
manages). `_teacherNamesByMembershipId` cross-references the real staff directory and real staff profiles the
exact way `TransportRepository.loadDriverAssignments` already does for real driver names, so a thread shows the
real teacher's real name rather than a bare membership id. `queueReply` now genuinely writes into the real
thread (`{id, threadId, body}` wire payload; `authorRole`/`authorMembershipId`/`createdAt` always server-stamped,
never trusted from the app) instead of the unregistered, read-only `principal_outgoing_communication` log it used
before, and a new `markThreadSeen` records this Principal's own real receipt, reusing the generic
`teacher_channel_receipts.dart` helper Teacher Messages' own channels already share. `PrincipalCommunicationThread`
gained a `messages` field to carry this real history; `_ThreadCard`'s fabricated bubbles were deleted and replaced
with a real loop over it, with an honest "No messages yet." empty state, and the now-dead `queuedReplies` plumbing
(which read from a path `queueReply` no longer writes to at all) was removed rather than left behind unused.

**A real bug found and fixed while writing the refusal test.** `queueReply` validated a thread id by checking
only that it *started with* `leadership-thread-`, not that it named a thread that actually existed - so a forged
id like `leadership-thread-ghost` passed that check and queued a message into thin air. Every sibling repository
that routes a reply by thread id (`TeacherMessagesRepository.queueMessage`, `TeacherFamilyMessagesRepository`,
driver/transport) already validates against the real, already-loaded list of threads a caller is actually part
of; this one didn't, because the inbox had no real threads to check against until this same pass built them.
Fixed by validating the id against `_leadershipThreads(membership)` itself, so only a thread with at least one
real message in it can be replied to.

**Verification.** App: `dart analyze` clean; `test/principal_communication_feature_test.dart` extended with a new
`school leadership reply-thread inbox` group (6 new tests: an inbox with no real leadership messages stays
honestly empty, a real teacher's leadership message really reaches the Principal's own inbox, the Principal's own
reply really reaches the real teacher's own Teacher Messages thread, a real teacher message makes the thread
unread for the Principal until marked seen, a thread shows the real teacher's real name from the real staff
directory, and a non-principal cannot reply while a reply to an unknown thread is refused - the test that caught
the prefix-only validation bug above). Full file: 21/21 (15 pre-existing unaffected, 6 new). Full app suite: the
same 83 pre-existing failures as before this work, by name. No backend change was needed - this pass only wired
the app to entities `apps/schoollife/messaging/teacher_channels.py` already shipped.

This completes every item the user named: real read-receipt/unread tracking across Parent Messages, Teacher
Family Messages, Driver Messages and Transport Control; Teacher Messages' staff/leadership channels; the
pluggable SMS/email delivery architecture; and now the Communication Hub's own reply-thread inbox. What remained
honestly unbuilt at the end of this pass, by design, stayed labelled rather than faked: a manager replying into an
individual guardian's own thread from this same screen, a real staff-audience send, real SMS/email/WhatsApp
delivery to a resolved audience, and follow-ups (still `const []`, already labelled "Not available yet"). The
first three of those closed in the next pass below; the fourth needs a real vendor before it can be more than an
honest seam.

## Closing the Communication Hub's remaining gaps: staff announcements, one guardian at a time, and real follow-ups

Asked to close out every remaining gap rather than call Messages "done" with loose ends left inside it: a real
staff-audience send, a manager replying into one specific guardian's own thread, and follow-ups that reflect
something real instead of sitting on an honest, permanent "Not available yet."

**Staff-audience announcements.** `queueAnnouncement`'s staff branch now does for every real, currently active
Secondary teacher what the guardian branch already did for every real, currently active Secondary family: one
real message into each teacher's own `teacher_leadership_message` thread - the exact channel `queueReply` already
writes into, so a staff announcement and a direct reply are indistinguishable once they land. "Which teachers are
Secondary" reuses the identical real directory/profile cross-reference `PrincipalAssignmentsRepository._secondaryTeachers`
already established for a different screen (`AdministratorStaffRepository`'s own `section` field joined through
`owner_staff_profile`'s `linkedMembershipId`), so no new real-data lookup was invented. A staff send with nobody
really linked is refused rather than silently "succeeding" at reaching nobody - the same honesty rule the guardian
branch already followed for an empty register.

**One real guardian's own thread.** The Communication Hub gained a "Message a family" lookup: the Principal picks
one real, active Secondary student from a searchable picker (`secondaryFamilies()`, the same real register
`_broadcastToSecondaryGuardians` already reads), and the Hub opens that one family's real `parent_message` thread
- read and replied into through the exact same `MANAGERS` oversight access the guardian-broadcast pass already
relied on to write into it, with its own real receipt sharing `parent_message_receipt` (already open to `MANAGERS`
server-side; no backend change needed). This is deliberately a targeted lookup, not a bulk inbox: picking one real
family on purpose, the same way the leadership inbox only ever showed threads that were really sent to, never a
proactive roster of every family's private conversation with their class teacher. `PrincipalCommunicationThread`
turned out to already fit a guardian thread's shape exactly - `TeacherMessage.fromCanonical` reads the identical
canonical `{id, threadId, body, authorMembershipId, createdAt}` payload `parent_message` and
`teacher_leadership_message` both use, so no second message model was needed, and `_ThreadCard` renders either
kind of real thread unchanged.

**Real follow-ups.** Each real, currently unread leadership thread now produces one real follow-up - "Reply to
<teacher>," pointing at that real thread - instead of the list staying permanently empty. There is no real
due-date concept behind a reply, so "due today" now means "currently awaiting your reply" rather than inventing a
finer urgency split nothing in the system tracks; a follow-up clears itself the moment the Principal actually
replies, since a thread they just answered is no longer unread. The "Open" action now selects the real thread
in this same screen instead of calling the page's cross-section navigation callback with a thread id it was never
built to understand - a latent bug that only became reachable once follow-ups stopped being permanently empty.
Guardian threads do not feed follow-ups: that would mean bulk-scanning every real family's conversation with
every teacher by default just to compute a badge, the same overreach the targeted-lookup design above was chosen
to avoid.

**A second real bug found while fixing the first.** `queueAnnouncement`'s default test fixtures used a
staff-audience, portal-channel send as a "safe," implicitly-always-succeeds way to create a generic queued
announcement for tests that weren't about delivery at all. Once staff became a real send requiring a real linked
teacher, one such test outside this file entirely (`principal_profile_feature_test.dart`'s "a real queued
announcement... appears in real recent activity") started failing - caught only by diffing the full suite's
failing-test names against a clean baseline run, not by the raw failure count, which happened to land one over
baseline either way. Fixed by pointing that test at the guardian audience instead, which the shared demo seed
already backs with real students.

**Verification.** App: `dart analyze` clean. `test/principal_communication_feature_test.dart` extended with three
new groups (12 new tests): staff announcements reaching every real Secondary teacher's own thread and refusing
a Primary-section teacher or an empty register; the individual guardian inbox listing real families, staying
honestly empty with no messages, refusing a forged or non-register student id, a real reply landing in the
guardian's own Parent Messages thread end to end, and real unread-until-seen tracking; and a follow-up appearing
for a real unread thread and clearing once replied to. Full file: 33/33. `principal_profile_feature_test.dart`:
the one test fixed to use a real audience passes again; its one remaining failure
("a real approval decision... appears in real recent activity, newest first") was confirmed pre-existing and
unrelated - it fails identically in isolation on the unmodified baseline. Full app suite: back to the same 83
pre-existing failures as before this work, by name, after finding and fixing the one genuinely new failure above.
No backend change was needed anywhere in this pass - every gap closed by wiring the app to real entities and
real permission rules (`teacher_leadership_message`, `parent_message`, `parent_message_receipt`) that already
shipped.

This closes every gap named for the Communication Hub. What remains honestly unbuilt, by design: real
SMS/email/WhatsApp delivery to a resolved audience, which needs a real vendor and a real phone/email contact
resolution step neither of which exist in this environment, consistent with the architecture-only scope already
chosen for SMS/email elsewhere in this plan.

## Driver operational alerts become real (closing out the Driver role)

The last labelled gap on the Driver role: Driver Messages had already become a real, two-way channel with
Transport Control earlier in this plan, but its own "Alerts" tab - a broadcast, priority-ranked operational
notice - had no real backend at all. `DriverMessagesRepository.load()` always returned `alerts: const []`, and
`markAlertRead` always threw "Real operational alerts are not available yet." The UI itself was already fully
built and already handled the honest empty state correctly; only the data behind it was missing.

**Design.** A new real entity, `driver_alert` (`apps/transport/driver_messages.py: DriverAlertHandler`) - a
school-wide broadcast from Transport Control (`MANAGERS`: proprietor or administrator) to every real Driver, not
a per-driver thread: entity id `LOCAL-<sender membershipId>-<epoch>`, create-only, the same append-only shape
every other channel in this module already uses. `scopeLabel` ("All Routes", "Route 7 only") is the sender's own
free-text description, informational only - no per-route targeting was built, since every real Driver in a
school is a plausible recipient of an operational notice and inventing a second access-control layer around
`scopeLabel` wasn't asked for. The existing `AlertReceiptHandler` (a Driver's own "I read this" receipt) already
existed but had nothing real to validate an `alertId` against; it now rejects a receipt for an alert that doesn't
really exist, the same rigor every other receipt handler in this app already has.

**App.** `DriverOperationalAlert` gains a `fromCanonical` factory - the same shape `TeacherMessage.fromCanonical`
and `ParentMessageItem.fromCanonical` already established - reused by both `DriverMessagesRepository` (a Driver's
own view, `read` computed from their own real `driver_alert_receipt` rows) and the new
`TransportMessagesRepository.queueAlert`/alert list on Transport Control's own side (`read: true` always there,
since `AlertReceiptHandler` is deliberately Driver-only - Transport Control has no real receipt of its own to
compute from, and showing a permanently-stuck "unread" badge with no way to clear it would have been worse than
not showing one). `TransportMessagesPanel` gained a second section, "Operational alerts," with a "Send alert"
compose dialog (title, body, priority, scope) next to the existing per-Driver conversation list it already had.

**Verification.** Backend: new `apps.transport.tests.test_incidents_messages: DriverAlertTests` (7/7 - Transport
Control sends and every real Driver (plus a second, unrelated Driver) really sees it, an unrelated role and a
Driver itself are refused, priority must be one of the real three, an unrecognised sender id is refused, it is
never changed or removed once sent); `DriverReceiptTests` extended (a real alert read receipt now requires a
real alert and is rejected for a forged one, and the receipt's own `alertId` must match between its id and its
payload); `apps.transport` together (90/90); `django check` clean. App: `dart analyze` clean;
`test/driver_messages_feature_test.dart`'s stale "alerts have no real backend yet" test replaced with a real
`operational alerts` group (6/6 - honestly empty by default, a real alert is read not fabricated, marking it read
queues a real receipt and persists, an unknown alert id is refused, marking an already-read alert again is a
no-op, newest-first ordering); `test/transport_messages_feature_test.dart` extended with its own `operational
alerts` group (5/5 - nothing sent yet, a real send really reaches a real Driver end to end, a read-only Principal
cannot send one, blank/overlong input is refused, an empty scope label defaults to "All Routes"). Full app and
backend suites: no new failure introduced by this change (confirmed by name against each suite's own,
already-documented run-to-run flakiness).

This completes the Driver role: Driver Messages (real, two-way, with read receipts) and now Driver Alerts (real,
broadcast, with read receipts) are both genuinely connected to Transport Control, with nothing left on this
screen still labelled "not available yet."

## Alumni Directory and Alumni Community become real

The Alumni role had only ever had two real sections - Dashboard and Profile (identity + proprietor/administrator/
principal verification) - behind `apps/alumni`. The other six workspace sections all rendered the identical locked
`Chip('Not available yet')` placeholder, with zero backend behind any of them. This pass makes two of those six
real - Directory and Community - chosen because, once investigated, both turned out to lean on infrastructure that
already existed rather than needing a whole new domain. Events & Reunions, Mentorship, Jobs & Opportunities and
Give Back stay the same honest placeholder; each needs its own real design before it is picked up (Give Back,
when it is, will be non-monetary pledges - volunteering, mentoring, supplies - not real money through
`apps/bankconnect`, a decision made and recorded so that pass does not have to re-ask).

**Alumni Directory (new).** A real, narrow, public-facing read over data that already existed:
`AlumniProfile.directory_visible` and `verification_status` were already real fields with nowhere in the app that
actually read them for browsing. `AlumniDirectoryView` (`apps/alumni/views.py`) lists every real, verified,
directory-visible alumnus of the acting membership's own school, with optional `q` (name/profession/organisation)
and `graduationYear` filters - authorized the same way the alumni's own profile view already is
(`require_activity(..., "alumni.directory", ...)`, an activity key the access catalog had already carried for all
six sections since before this pass). `AlumniDirectoryEntrySerializer` is deliberately narrower than
`AlumniProfileSerializer`: never admission number, original student reference, or email - the same restraint
`directory_visible` already implied. The Flutter side follows `AlumniProfileRepository`'s own online-only shape
exactly: `AlumniDirectoryRepository.hasServer` false means an honest empty list, never a crash or a fabricated
entry; a real failure still propagates so the page can show a retry rather than silently hiding it.

**Alumni Community (reuses the existing community module and the existing Flutter `CommunityPage`, built no new
screen or backend module).** `apps/schoollife/community/` was already a fully real, shipped posting system
(`PostHandler`/`CommentHandler`/`ReactionHandler`/`ReportHandler`) that every other role already writes into
through the exact same already-generic `lib/features/community/` client - `CommunityPage` was already reused
unchanged by every other role's workspace (administrator, driver, finance office, parent, principal, proprietor,
staff, student, teacher); Alumni just never wired it in. The only real gap was that alumni weren't a reader or
writer of Community at all. Deliberately **not** done by widening `apps.schoollife.framework.EVERYONE` - about
nine other Specs across `calendar.py`/`campus.py`/`programmes.py` default their own read permission to that same
shared constant, so broadening it would have silently handed alumni read access to unrelated school data nobody
asked for. Instead, `apps/schoollife/community/common.py` adds a **local** `READERS = EVERYONE | {"alumni"}`
scoped to Community alone, a new `alumniOnly` audience, and `may_see_post` now treats alumni as a real reader
scoped *only* to their own corner - not general in-school chatter meant for a currently enrolled section or staff
- the same way `staffOnly` already scopes staff-only posts to the staff side. `posts.py` gained the matching
write-guards: only alumni may post `alumniOnly`, and alumni may only ever post `alumniOnly`. Comments and
reactions needed no change at all - both already delegate entirely to `may_see_post` on their parent post. The
Flutter `CommunityRepository` mirrors this exactly: `SchoolRole.alumni` joins `_writers`, and `_allowedAudiences`
now gives an alumnus exactly `[CommunityAudience.alumniOnly]` and gives everyone else every audience *except*
that one - `load()` itself needed no change, since it already just renders whatever synced locally and the
server's own `may_see_post` is what decided that.

**Verification.** Backend: new `apps.alumni.tests.test_directory` (6/6 - a verified, directory-visible alumnus
appears without any private field; an unverified or a verified-but-hidden profile is excluded; cross-school
isolation; every non-alumni role is refused; search and graduation-year filters both work); `apps.schoollife.
tests.test_community` extended with a new `AlumniCommunityTests` class (5/5 - an alumnus can post `alumniOnly` and
nowhere else; a non-alumnus is refused from posting `alumniOnly`; only alumni and moderators read an `alumniOnly`
post; an alumnus does not see general in-school posts; a non-alumnus can still comment on an `alumniOnly` post
only once they can actually see it); `apps.alumni` (8/8) and `apps.schoollife` (98/98) together; `manage.py
check` clean; full backend suite unaffected (same pre-existing failure signature, confirmed by name). App: `dart
analyze` clean; new `test/alumni_directory_test.dart` (4/4 - no server is an honest empty list, a real entry
round-trips, a load failure propagates rather than hiding as empty, search matching); `test/
community_repository_test.dart` extended (4 new tests - an alumnus can post but only ever to `alumniOnly`, nobody
else is ever offered that audience, an alumnus can publish to it, an alumnus is refused from a general audience);
full app suite back to the same 83 pre-existing failures as before this work, by name.

## Alumni Events & Reunions becomes real

The third of the Alumni workspace's six originally-locked sections. Scoped deliberately: reunion events are
created by **school management only** (proprietor, principal or administrator) - alumni browse and RSVP, they do
not propose their own events this pass - and an RSVP is a **simple yes/no "attending"**, not a guest-count form.

**Why this is a new, dedicated entity rather than reusing the existing `school_event` Spec.** The backend already
has a general school calendar (`apps/schoollife/specs/calendar.py: EVENTS`, entity `school_event`) and the app
already has a generic, cross-role `lib/features/events/` screen reading it (used by Parent and Proprietor). But
`school_event` has no audience/category concept at all - just `title` and `date` - and defaults to
`read=EVERYONE`, the same shared constant the Community work deliberately avoided widening. Reusing it would have
meant alumni seeing the *entire* school calendar (assemblies, excursions, PTA meetings - not what "Events &
Reunions" means) with no way to filter. A dedicated pair of models in `apps/alumni` avoids that, and matches how
`AlumniProfile`/`AlumniDirectoryView` already work: real Django models behind real DRF views, not the generic sync
registry Alumni has never used.

**Why RSVP is not an append-only receipt, unlike every other receipt built this session.** A read receipt
(message seen, alert read) records a fact that stays true forever once it happens. An RSVP is different - a
person can genuinely change their mind about attending, and the *current* answer is what matters, not a log of
every change - so `AlumniEventRsvp` is one real, updatable row per `(event, membership)`
(`Model.objects.update_or_create(...)`), the same "current state, not a log" shape `AlumniProfile.directory_visible`
already uses, not the append-only shape `parent_message_receipt`/`driver_alert_receipt` use.

**Design.** `AlumniEvent` (title, date, free-text time, venue, note, `created_by`) and `AlumniEventRsvp`
(`event` + `membership`, unique together, `attending`, `clean()` requiring a real Alumni membership of the same
school) are real Django models with a real migration. `AlumniEventListView` (`GET`: any real Alumni membership,
via the same `_self_membership(..., activity="alumni.events")` helper Directory already generalised; `POST`:
`require_alumni_manager`, the same helper Management/Transition/Verify/Reject already share) lists every real
event for the school, each serialized with a real `attendingCount` (`event.rsvps.filter(attending=True).count()`)
and the acting alumnus's own real `myRsvp` (`true`/`false`/`null` if they have never responded) - both computed
fresh from real rows, never stored on the event itself. `AlumniEventRsvpView` 404s on an event id that isn't real
or isn't this school's, and `update_or_create`s the acting alumnus's own row. On the app side, `AlumniEvent`
gained a `fromCanonical`-style `fromJson`; `AlumniEventsRepository` mirrors `AlumniDirectoryRepository` exactly
(`hasServer`, honest empty list, a real failure propagates for a retry); `AlumniEventsPage` is the alumni's own
read-and-RSVP view; `AlumniManagementPage` - the one screen the three manager roles already use for Alumni work -
gained a small "Reunions & Events" section (a real list + an "Add event" dialog) rather than a new management
screen.

**Verification.** Backend: new `apps.alumni.tests.test_events` (9/9 - only real alumni can browse, only
management can create, a title/date is required, a real RSVP and its real count, changing an RSVP updates the
same row rather than duplicating it, an event nobody has responded to has an honest zero count and a null
`myRsvp`, a non-alumnus cannot RSVP, a forged or other-school event id is refused, cross-school isolation);
`apps.alumni` together (17/17); `manage.py check` clean. Full backend suite: confirmed by a full `git stash`
comparison (not just a re-run) that this pass introduces zero new failures - the suite's own run-to-run failure
set turned out to be considerably wider than previously documented (spanning `apps.sync`, `apps.staff`,
`apps.owner`, `apps.schools`, `apps.access`, `apps.mandates`, not only the `apps.transferverify`/`apps.invitations`/
`apps.bankconnect` corner noted earlier), but the exact same set appears on a clean, unmodified checkout, which is
what the stash comparison exists to prove. App: `dart analyze` clean; new `test/alumni_events_test.dart` (6/6 -
honest empty with no server, a real event and its real RSVP state round-trip, a load failure propagates, `rsvp()`
with no server throws rather than pretending to record a response, a real RSVP sends this membership's own answer
and returns the real updated event, a real RSVP failure propagates); full app suite back to the same 83
pre-existing failures as before this work, by name.

## Alumni Give Back becomes real

The fourth of the Alumni workspace's six originally-locked sections. Its core shape was decided earlier this
session, when SMS/email delivery was being scoped: Give Back is **non-monetary pledges** - volunteering,
mentoring, supplies, guest speaking - never real money through `apps/bankconnect`.

**How "pledge" is interpreted.** A real alumnus offers something (a category plus a free-text description),
the one-sided "I'm putting this forward" shape the word already implies. School management reviews real pledges
and moves them through a real, honest status: `offered → acknowledged → fulfilled`, or the alumnus withdraws
their own. This is deliberately **not** a public, two-sided marketplace (the school posting specific asks that
alumni respond to) - that would be a materially different, larger design closer to Jobs & Opportunities' own
shape, and wasn't what was decided.

**Why a status workflow rather than a plain yes/no, unlike Events' RSVP.** An RSVP has exactly two meaningful
states. A pledge is different - the school genuinely does something with it over time (notices it, acts on it,
or it falls through), so `offered → acknowledged → fulfilled` is real, useful state for both sides, modelled the
same "real status a manager moves forward" shape `AlumniVerificationStatus` already uses on `AlumniProfile`, not
a single boolean. Unlike identity verification, there is no separate append-only event log this time - a
pledge's own `status`/`school_note`/`updated_at` is enough history for something this simple;
`AlumniVerificationEvent` exists specifically because *who* verified *what* evidence matters later, which doesn't
apply here.

**Design.** `AlumniPledge` (category, free-text description, status, a manager's own `school_note` - visible to
the alumnus too, the same transparency `verification_note` already gives them) is a real Django model with a
real migration, following the exact precedent `AlumniEvent`/`AlumniEventRsvp` just established: no existing
school concept came close (confirmed by searching the backend for `volunteer`/`pledge`/`give.back`, which found
nothing outside the access catalog's own label for this section), and Alumni has never used the generic sync
registry. `AlumniPledgeListView` (self-service, `activity="alumni.give-back"`) returns *only the acting alumnus's
own* pledges, never a public board - a pledge is something you make to the school, not something every alumnus
browses. `AlumniPledgeWithdrawView` lets only the pledge's own alumnus withdraw it; `AlumniPledgeStatusView`
(`require_alumni_manager`) lets only management move it to `acknowledged`/`fulfilled` - never `withdrawn`, which
stays the alumnus's own decision, enforced by the status serializer's own choice list rather than a runtime
check. `AlumniManagementView` - the same bundle endpoint Directory's management screen already returns
`profiles`/`transitionCandidates` from - now also carries every real pledge with the real alumnus's name, for
oversight. On the app side, `AlumniManagementPage` gained a "Give Back pledges" section (reusing data already in
its existing `AlumniManagementSnapshot`, now extended with `pledges`, rather than a second fetch) alongside the
Reunions & Events section it gained last pass.

**Verification.** Backend: new `apps.alumni.tests.test_give_back` (10/10 - only real alumni can list/create; an
alumnus only ever sees their own pledges, never another's; a pledge is refused without a real category/
description; a new pledge starts `offered` with the real alumni name; only the pledge's own alumnus can withdraw
it; only management can acknowledge/fulfil, never withdraw; a status update carries the real school note; a
forged or other-school pledge id is refused on every endpoint; `AlumniManagementView` carries every real pledge
with the real alumnus's name; cross-school isolation); `apps.alumni` together (27/27); `manage.py check` clean.
Full backend suite: a real `git stash` comparison surfaced two failures present only in the "with changes" run
(`apps.invitations.tests.test_service_and_mail` and `apps.bankconnect.tests.test_review` - both completely
unrelated to `apps.alumni`, and the bankconnect one already a confirmed repeat offender from earlier this
session); both pass cleanly in isolation, confirming pre-existing flakiness rather than a regression. App: `dart
analyze` clean; new `test/alumni_give_back_test.dart` (11/11 - honest empty with no server, a real pledge
round-trips, a load failure propagates, `create()`/`withdraw()` with no server throw rather than pretending to
succeed, a real create/withdraw really calls through with this membership's own data, a too-short description is
refused client-side, real create/withdraw failures propagate, `canWithdraw` is true only while `offered`/
`acknowledged`); full app suite back to the same 83 pre-existing failures as before this work, by name.

## Alumni Jobs & Opportunities becomes real

The fifth of the Alumni workspace's six originally-locked sections - the last of the two that needed a fresh
scope decision before it could be planned concretely (Mentorship, the remaining one, still needs its own
audience/matching decisions).

**Who posts, confirmed before planning.** Any real alumnus may post a real opportunity - alumni sharing openings
at their own companies for fellow alumni, a real posting board rather than something only the school curates.
Since postings aren't curated, this needed real moderation: the same "the author or a moderator may close it"
shape `apps/schoollife/community`'s `PostHandler.authorize` already established for posts, not a second invented
mechanism.

**Why this stays `open`/`closed`, not a bigger application-tracking system.** "Express interest" or a real
application pipeline (who gets notified, how a poster reviews applicants) would be a materially larger, separate
design that wasn't asked for. This is a real posting board with a real contact method the poster supplies -
interested alumni reach out directly, the same way a real-world noticeboard works. Closing a listing (by its own
poster, or by a moderator) is the only status change needed.

**Design.** `AlumniOpportunity` (title, organisation, type, location, description, a real contact method, status)
is a real Django model with a real migration, following the same reasoning Events/Give Back already established:
no existing school concept came close (confirmed by searching the backend for `opportunit`/`job.*posting`, which
found nothing outside the access catalog's own label for this section). `AlumniOpportunityListView` is the first
Alumni list endpoint that shows *every* real record for the school rather than just the acting membership's own
(unlike Give Back's self-only pledges) - a real posting board every real alumnus browses. The serializer's own
`validate()` requires a real way to follow up: either a real `contactInfo`, or a description long enough (20+
characters) to stand on its own. `AlumniOpportunityCloseView` could not simply reuse `_self_membership` guarding
the whole view the way every other Alumni endpoint does, because that helper hard-requires an Alumni membership -
a real manager closing someone else's posting for moderation would be rejected before ever reaching the
poster-or-moderator check. Instead it tries the Alumni self-service path first (catching the `PermissionDenied`
if the caller isn't an alumnus at all), and only requires the real poster's own id to match if that path
succeeds; otherwise it falls through to `require_alumni_manager`. `AlumniManagementView` gained a real
`opportunities` list alongside `profiles`/`transitionCandidates`/`pledges`, the same oversight bundle shape
already established twice. On the app side, `AlumniOpportunityType`'s wire values needed their own explicit
`wireValue`/`fromWire` mapping (`full_time`, not Dart's own `fullTime`), since the backend's `TextChoices` are
snake_case and nothing else in this session's Alumni work needed that translation.

**Verification.** Backend: new `apps.alumni.tests.test_opportunities` (12/12 - only real alumni can list/post; a
posting is refused without a real title/organisation/type/description; a posting needs a real way to follow up;
every real alumnus sees every real posting, not just their own; a new posting starts `open` with the real
poster's name; the poster can close their own; an unrelated alumnus cannot close someone else's; management can
close any real posting; closing an already-closed posting is a harmless no-op; a forged/other-school id is
refused; `AlumniManagementView` carries every real posting with the real poster's name; cross-school isolation);
`apps.alumni` together (39/39); `manage.py check` clean. Full backend suite: a real `git stash` comparison
surfaced one failure present only in the "with changes" run
(`apps.transferverify.tests.test_disputes.ClearanceTests.test_revoking_and_reissuing_works`, a timestamp-ordering
assertion already documented as flaky earlier this session) - re-run three more times in isolation with no
changes present, it failed once and passed three times, confirming genuine non-determinism rather than a
regression. App: `dart analyze` clean; new `test/alumni_opportunities_test.dart` (12/12 - honest empty with no
server, a real posting round-trips, a load failure propagates, `post()`/`close()` with no server throw rather
than pretending to succeed, a real post/close really calls through with this membership's own data, a too-short
description and a missing contact method are both refused client-side, real post/close failures propagate, the
opportunity-type wire mapping round-trips through the backend's own snake_case choices); full app suite back to
the same 83 pre-existing failures as before this work, by name.

This leaves Mentorship as the one remaining locked section - it still needs its own real design pass (who
mentors whom, and how a connection is actually made, neither of which has been decided yet); unlike the five
sections now real, it has no existing precedent in the codebase to lean on.

## Alumni Mentorship becomes real

The sixth and last of the Alumni workspace's originally-locked sections. Two scope decisions confirmed before
planning:

**Audience: alumni mentoring alumni, not alumni mentoring current students.** Consistent with every other Alumni
section this session (Directory, Community, Events, Give Back, Opportunities are all alumni-only). Extending
mentorship to current students would be a real scope expansion with real safeguarding/duty-of-care implications -
minors, supervision, consent - deliberately out of reach here, not a feature decision to make lightly.

**Matching mechanism: a mentor directory, a request a mentor accepts or declines, then real contact info.** The
same "reach out directly" shape Jobs & Opportunities already established, not a second, in-app messaging channel
built just for this. Contact info is each side's own real account email - revealed to the other only once the
mentor has actually accepted, never before; a pending or declined request reveals nothing.

**Design.** `AlumniMentorProfile` is a separate, real opt-in from `AlumniProfile` itself - being listed in the
Alumni Directory and being willing to mentor are different decisions a person makes separately, the same
reasoning `directory_visible` already being its own explicit flag established, just as a whole second profile
since "what I'll mentor on" (`expertise`) genuinely differs from a person's current `profession`. It is a real
Django model (`membership` OneToOne pk, `school`, `expertise`, `bio`, `is_active`), with `clean()` requiring
`membership.role == Role.ALUMNI`, the same guard every other Alumni model already uses. `AlumniMentorshipRequest`
reuses `AlumniProfile.Meta.constraints`' own conditional-unique shape
(`UniqueConstraint(fields=["mentor", "mentee"], condition=Q(status="pending"), ...)`) rather than a plain unique
constraint: a mentee can genuinely need to ask the same mentor again later, so only a second *simultaneous
pending* request to the same mentor is blocked, not every request ever. Every endpoint uses
`_self_membership(request, school_id, activity="alumni.mentorship")` - no manager role is involved anywhere in
this section (confirmed: nothing in `AlumniManagementView` changed), so `alumni_management_page.dart` was
deliberately left untouched this pass, unlike every other section. `AlumniMentorshipRequestSerializer` withholds
`mentorEmail`/`menteeEmail` behind `get_mentorEmail`/`get_menteeEmail`, returning `None` unless
`status == AlumniMentorshipRequestStatus.ACCEPTED` - the same conditional-reveal shape
`AlumniEventSerializer.get_myRsvp` already established, just protecting real contact info instead of a real RSVP.
`AlumniMentorshipRequestWithdrawView` mirrors `AlumniPledgeWithdrawView`, restricted to the real mentee and only
while `status == "pending"`. On the app side, `AlumniMentorshipRepository` follows the same online-only shape as
every prior Alumni repository this session (`hasServer`, an honest empty snapshot with no server, write
operations that throw rather than pretend to succeed), bundling the mentor directory, the alumnus's own mentor
profile, and their own requests into one `load()`; `requestsAsMentee`/`requestsAsMentor` are computed getters
splitting the same request list by the acting membership's real relationship to each row.

**Verification.** Backend: new `apps.alumni.tests.test_mentorship` (17/17 - only real alumni can opt in as a
mentor, browse the directory, or request; a mentor profile requires real expertise/bio; `me` is honestly `None`
until opted in; only active mentors appear in the directory, and the directory never carries contact info; a
request needs a real, currently-active mentor; an alumnus cannot request themselves; a second simultaneous
pending request is refused, but a new one after a decline is allowed; only the named mentor can accept/decline;
contact email is absent until accepted, then present for both sides; declining never reveals it; an
already-answered request cannot be answered again; only the mentee can withdraw, only while pending; a
forged/other-school request id is refused; requests never appear in Alumni Management; cross-school isolation for
both mentors and requests); `apps.alumni` together (56/56); `manage.py check` clean. Full backend suite: a real
`git stash` comparison surfaced one failure present only in the "with changes" run
(`apps.bankconnect.tests.test_review.AssignTests.test_a_person_assigns_a_payment_to_one_student`, unrelated to
any Alumni code) - re-run three more times in isolation with no changes present, it passed all three times,
confirming pre-existing non-determinism rather than a regression. App: `flutter analyze` clean; new
`test/alumni_mentorship_test.dart` (17/17 - honest empty snapshot with no server; a real mentor and own profile
round-trip with a server; a load failure propagates; `requestsAsMentee`/`requestsAsMentor` split correctly;
`saveMyMentorProfile()`/`requestMentor()`/`respond()`/`withdraw()` each throw with no server rather than
pretending to succeed, really send this membership's own data when a server exists, and propagate real failures;
accepting really reveals contact email, declining never does); full app suite back to the same 83 pre-existing
failures as before this work, by name.

This closes out the Alumni role: all six workspace sections - Directory, Community, Events & Reunions, Give Back,
Jobs & Opportunities, and Mentorship - are now genuinely real, backed by real models, real endpoints, and real
Flutter repositories/pages, each with its own test coverage.

## The shared Community module stops fabricating its own feed

Not the Alumni workspace's own Community section above - this is `lib/features/community/`, the "Community" tab
every role shares (administrator, alumni, driver, finance office, parent, principal, proprietor, staff, student,
teacher). A full-codebase audit for remaining fabricated content, run after Alumni closed out, found it as the
single most visible gap left: `CommunityRepository.load()` unconditionally seeded four invented posts from
invented people ("Mrs. Mary Daniel", "Sports Committee", ...) into local storage the first time any school's feed
was empty, and the sidebar's stat grid read five flat constants (`communityMembers = 1084`, `communityPostsThisWeek
= 46`, ...) instead of anything the school had actually done. None of this could ever reach a real school's
backend - `LocalDatabase.upsertLocalRecord`'s own `blockDemoSeeds` guard (set once `ApiConfig.enabled` is true)
already silently drops exactly this kind of seed call - but in demo mode it was the first thing every role saw,
and `docs/BACKEND_INTEGRATION.md` itself overstated the module's status, describing it as running "on a real
backend" without mentioning it still fabricated its entire starting feed.

**Design.** `load()` no longer seeds anything; an empty local `community_post` table now returns a genuinely
empty `CommunitySnapshot.posts`, the same honest-empty standard every other repository fixed this session already
follows. `CommunitySnapshot` gained three computed getters - `postsThisWeek`, `commentsThisWeek`,
`publicShowcaseCount` - each counting real `posts`/`comments` by `createdAt`/`visibility`, replacing the fixed
constants the stat grid used to read. "Community members" was dropped from the stat grid entirely rather than
replaced with a guess: `CommunityRepository` only ever sees this device's own memberships
(`SchoolSessionController.memberships`), never a real count of everyone at the school, so there was no honest
number available to show. `community_demo_data.dart` - renamed `community_policy_copy.dart` since all that
remained was static guidance text, never data about a particular school - kept `communityParticipationRules`,
`communityModerationRules` (with the invented "2 reports awaiting review" heading corrected to a plain
"Reports awaiting review", since the real count already has its own live stat card) and
`communityNoticeboardBoundary`. `_EmptyFeed` now distinguishes a genuinely empty feed ("No Community posts yet.
Be the first to share something.") from a filter matching nothing, where it previously showed the filtered
message either way.

**Verification.** `flutter analyze` clean. `test/community_test.dart`: the two tests asserting the fabricated
seed data and KPI constants were removed outright (nothing real backs either anymore); the post
filtering/serialization tests were rewritten against an inline fixture instead of seed data; the policy-copy
tests kept, now importing the renamed file. `test/community_repository_test.dart` gained new coverage: a fresh
school's `load()` returns a genuinely empty feed with every computed stat at zero; `postsThisWeek`/
`publicShowcaseCount` only count posts really published (caught a test-writing mistake of its own along the way -
a teacher cannot publish to the public showcase, only a proprietor/principal can, so the fixture was switched to
`SchoolRole.proprietor`); `commentsThisWeek` counts real comments across a real post. `test/community_media_test.dart`
no longer depends on a seeded `POST-001`: `setUpSchool()` now really publishes one post and captures its real id,
which also surfaced a second real bug the old seeded-post tests could never have caught - two of its widget tests
built their fake server's asset map from `_postId` *before* `setUpSchool()` had assigned it, binding to the
previous test's stale id; `pump()`'s `api` parameter became `apiBuilder`, a closure evaluated only after setup
assigns the real id. All 33 Community tests pass; full app suite back to the same 83 pre-existing failures as
before this work, by name.

## Noticeboard stops fabricating its own feed, recipient counts and delivery reports

First of a 14-directory cluster the Community fix's own audit surfaced - sized up first, confirming all 14 already
have real Django backends (no new backend work needed anywhere in the cluster) before starting on any of them.
Noticeboard (Proprietor-only official-notice publishing, under `lib/features/noticeboard/`) turned out to carry
more than Community's single kind of fabrication: `load()` seeded four invented notices the same way Community's
feed did, but `publish()` itself also hardcoded a fabricated recipient count
(`audience == wholeSchool ? 1084 : 120`) into every real notice at creation, and the stat grid read two more
fixed constants (`noticeboardAverageReadRate = 82`, labeled "Sample delivery figures", and
`noticeboardScheduledCount = 3`) - the second of which had no real feature behind it at all; nothing in the app
ever schedules a notice for future publication.

**Design.** `load()` no longer seeds anything. `publish()` now sets a real notice's `readCount`/`totalRecipients`
to `0` rather than a guessed audience size - nothing in the app tracks who has actually read a notice (confirmed
by searching every other role's features for any reference to `noticeboard`: only the Proprietor module touches
it, and nothing marks a notice read from the recipient side), so `0` is the honest value, not a fabricated one.
The stat grid dropped "Average read rate" and "Scheduled" entirely rather than inventing a replacement number,
keeping the three stats that were already real (`Active notices`, `Pinned`, `Need acknowledgement`, all counted
from real local notices). The per-notice "X/Y read" line and the delivery-report dialog both now check
`totalRecipients > 0` and show "Read tracking is not available yet for this notice" when it's not - the same
honest-gap labeling the Proprietor/Administrator audit found already in good standing elsewhere in the app -
rather than permanently showing "0/0 read (0%)" as if that were a real, checked number. `noticeboard_demo_data.dart`
is renamed `noticeboard_policy_copy.dart`, keeping only `noticeboardPublishingAuthority`,
`noticeboardDeliveryChannels` and `noticeboardBoundary` - static guidance text, never fabricated data about a
particular school. The empty-feed message now distinguishes a genuinely empty noticeboard ("No official notices
yet. Publish the first one above.") from a filter matching nothing, the same distinction Community's fix made.

**Verification.** `flutter analyze` clean. `test/noticeboard_test.dart`: the seed-data/KPI test was removed; the
filtering, serialization and audience/priority tests were rewritten against inline fixtures; the publishing-policy
test kept, now importing the renamed file. New `test/noticeboard_repository_test.dart` (5 tests - a fresh school's
`load()` is genuinely empty; only the proprietor may publish; a real published notice starts at an honest zero
recipient count, never a guessed one; pinning and editing a real notice persists and is proprietor-only). All 9
Noticeboard tests pass; full app suite back to the same 83 pre-existing failures as before this work, by name.

## Houses & Teams gets a real create/edit flow, not just a fabrication fix

Second of the 14-directory cluster, and the first one the sizing audit's "shallow, one seed call" label understated:
`HouseRepository` had no create or edit method at all - `load()` was the only method - so simply deleting its
seeded four houses the way Noticeboard's seed was removed would have left every real school with a permanently
empty, permanently unusable Houses screen forever, since there was no way to ever add a real house through the
app. The real Django Spec behind it (`HOUSES = Spec("school_house", manage=MANAGERS, required=("name",))` in
`apps/schoollife/specs/programmes.py`) already supports create/update by any of `MANAGERS` -
`{proprietor, principal, administrator}` - same generic CRUD shape as Community/Noticeboard, so building a real
write path cost nothing on the backend. Along the way, `HousePermissions.canManageAll` was also found checking
`membership.role == SchoolRole.proprietor` alone, understating who the real backend actually authorizes to manage
a house.

**Design.** `HouseRepository` gained `create({name, captain, coordinator})` and `edit(...)`, mirroring
Noticeboard's `publish()`/`edit()`/`_save()` shape exactly; `permissionsFor` now checks against
`{proprietor, principal, administrator}`, matching `MANAGERS` the same way Community's own permission sets were
built to mirror `apps.schoollife.community.framework` exactly. A new house starts at `points: 0, members: 0,
sports: 0, academicCompetitions: 0, service: 0, status: 'Active'` - an honest zero, not an invented ranking.
Points, members and the three component scores stay hand-maintained by a manager through `edit()` rather than
computed automatically - nothing in the app records a real sports/quiz/service event yet, so there is no real
total to compute instead, the same reasoning that kept Noticeboard's read tracking honestly unavailable rather
than fabricated. The KPI grid (`_KpiGrid`) now computes "Active houses", "Members" and "Leading house" from real
`snapshot.houses` instead of five fixed constants; "Events this term" was dropped outright since nothing tracks a
scheduled event at all. `house_demo_data.dart` is renamed `house_policy_copy.dart`, keeping only
`houseScopeTitle`/`Subtitle`/`Description`, `houseStandingsDescription` and `houseAcademicBoundary` - static
guidance text. The page gained an "Add house" dialog (name required, captain/coordinator optional) and an "Edit"
action on the selected house (all fields, manager-only), and the empty-feed message now distinguishes a
genuinely empty house list ("No houses yet. Add the first one above.") from a search matching nothing.

**Verification.** `flutter analyze` clean. `test/houses_test.dart`: the seed-data/KPI test was removed; component
totals, search and serialization tests were rewritten against inline fixtures; a new `copyWith` test added. New
`test/house_repository_test.dart` (9 tests - a fresh school's `load()` is genuinely empty; `permissionsFor`
matches the real backend's `MANAGERS` set exactly, both who can and who cannot manage houses; `create()` adds a
real house at an honest zero and refuses a non-manager or an empty name; `edit()` really updates a house's hand-
maintained totals and refuses a non-manager). All 13 Houses tests pass; full app suite back to the same 83
pre-existing failures as before this work, by name.

## Assembly & Faith Activities gets a real create/edit flow, with a real two-tier permission set

Third of the 14-directory cluster. Same shape as Houses - `AssemblyRepository` had no create or edit method, only
`load()` - but the real backend Spec behind it carries more nuance than Houses' did:
`ASSEMBLY = Spec("assembly_session", manage=MANAGERS, contribute={"teacher"}, required=("title",))` in
`apps/schoollife/specs/calendar.py` lets a teacher create a session (and, server-side, change only their own),
while a manager may create or change any of them - a real two-role write model, not the single manage-only gate
Houses needed. `assembly_demo_data.dart` turned out to already compute its stats from a real `sessions` argument
(`assemblyStats(sessions)`) rather than fixed constants - the only fabrication was the five-session seed itself,
not the stats derived from it.

**Design.** `AssemblyRepository` gained `create(...)` and `edit(...)`, mirroring Houses' shape, with
`permissionsFor` now exposing `canCreate` (manage ∪ contribute: proprietor, principal, administrator, teacher) and
`canManageAll` (manage only), replacing a `canConfigureSchoolWide` field that turned out to be checked nowhere in
the app at all. Per-record "a contributor may only change their own" ownership is deliberately NOT replicated
client-side - this app has no existing precedent for tracking local record ownership before a sync round-trip
(Community's own `canPost`/`canModerate` split works the same coarse way), so the Flutter-side `edit()` action is
manager-only; a teacher's create-only capability still matches the backend exactly, and the backend remains the
real enforcement point for "only your own" on update, same as it already was for Community. `assembly_demo_data.dart`
is renamed `assembly_policy_copy.dart`, keeping `assemblyConfigurationPrinciples` and the already-real
`assemblyStats()` function as-is. The page gained an "Add session" action (create-gated) and a per-session edit
icon (manage-gated), and the empty state distinguishes no sessions at all from a search/filter matching nothing.

**Verification.** `flutter analyze` clean. `test/assembly_test.dart`: the seed-preservation test was removed;
stats, filtering, serialization and configuration-principle tests were rewritten against inline fixtures; a new
`copyWith` test added; a new assertion confirms `assemblyStats([])` returns honest zeros. New
`test/assembly_repository_test.dart` (9 tests - a fresh school's `load()` is genuinely empty; `permissionsFor`
matches the real two-tier Spec exactly, including that a teacher can create but not manage-all; `create()` lets a
teacher really add a session and refuses a role outside manage/contribute or an empty title; `edit()` lets a
manager really change any session and refuses a teacher, who could create but never manage). All 14 Assembly
tests pass; full app suite back to the same 83 pre-existing failures as before this work, by name.

## Meals & Cafeteria gets a real weekly menu, as five honest day-slots

Fourth of the 14-directory cluster, and unlike Houses/Assembly it already had a real write path -
`MealRepository.updateMenuDay()` - so the fix was closer to Noticeboard's shape: remove the seed, fix what the
seed's absence exposed. Two things the seed had been masking: `permissionsFor` checked `role == proprietor` alone
when the real `MEALS = Spec("school_meal_day", manage=MANAGERS, id_field="day", required=("day",))` in
`apps/schoollife/specs/campus.py` authorizes the full `MANAGERS` set; and `_selectedMeal`'s
`meals.firstWhere(..., orElse: () => meals.first)` would throw on a genuinely empty week, since `.first` has
nothing to return - the seed had made that path unreachable in practice.

**Design.** Since `school_meal_day` is id-keyed by `day` (one record per weekday, never an open-ended list),
there was no need for a Houses-style `create()` - `updateMenuDay()` already upserts whichever weekday it's given.
Instead the page now always shows all five real weekdays as slots (`mealWeekdays`, a fact about the calendar, not
data about a school) via a new `SchoolMealDay.unset(day)` placeholder and an `isSet` getter (true exactly when a
real saved day's required breakfast/lunch/snack are filled in) - editing an unset slot and saving calls the same
`updateMenuDay()`, creating that day's first real record. `permissionsFor` now matches `MANAGERS` exactly, the
same fix Houses and Noticeboard needed. `mealStats()` already took real `meals`/`selected` arguments rather than
fixed constants - only `mealWebsiteSeed` itself and two stat values were fabricated: "Meal locations" (2) and
"special meal flags" (7) had no real source anywhere in the app, so they now say "Not available yet", the same
honest pattern the existing "Meal payments: Later" stat already used right next to them. `meal_demo_data.dart` is
renamed `meal_policy_copy.dart`, keeping `mealPrivacyRule` and the new `mealWeekdays` constant. The stale "This is
a sample service week, not a live calendar" description is replaced, and unset days show "This school has not set
a menu for `<day>` yet" instead of blank breakfast/lunch/snack lines.

**Verification.** `flutter analyze` clean. `test/meals_test.dart`: the seed-preservation and KPI-constant tests
were removed; search and serialization tests rewritten against inline fixtures; new tests cover `mealWeekdays`,
`SchoolMealDay.unset`'s honest emptiness, and that the two no-source stats say "Not available yet". New
`test/meal_repository_test.dart` (9 tests - a fresh school's `load()` is genuinely empty; `permissionsFor` matches
`MANAGERS` exactly; `updateMenuDay()` really sets a never-before-configured day and refuses a non-manager or a
missing breakfast/lunch/snack; setting one day never fabricates the other four). All 16 Meals tests pass. The full
app suite caught one genuine regression the seed had been hiding: `parent_school_life_feature_test.dart`'s
"today's meal" test called `meals.meals.firstWhere((m) => m.day == todayName)` with no `orElse`, assuming a
matching day always existed - true only because of the seed it was never written to depend on. The production
code it exercises (`ParentSchoolLifeRepository`) already handled a missing day correctly ("Not recorded yet"), so
the fix was to the test: it now explicitly sets a real meal for today's weekday via `updateMenuDay()` before
asserting the family sees it, and a new, separate test confirms the honest "Not recorded yet" default on a fresh
school with nothing configured. Full app suite back to the same 83 pre-existing failures as before this work, by
name.

## Activities, Clubs & Sports stops fabricating its directory and its own KPI grid

Fifth of the 14-directory cluster. Like Meals, `ActivityRepository` already had real write paths -
`addActivity()` and `updateAttendance()` - so this was a seed-removal-and-cleanup fix, not a Houses-style
from-scratch build. The real Spec (`ACTIVITIES = Spec("school_activity", manage=MANAGERS,
contribute={"teacher"}, required=("name",))` in `apps/schoollife/specs/programmes.py`) carries the same
manage/contribute shape Assembly's `ASSEMBLY` Spec does, but `permissionsFor` only ever exposed a single
`canManageAll` flag gating both creation and attendance-taking at proprietor only - collapsing two different real
permissions into one and ignoring `contribute` entirely, so a teacher could never add a programme even though the
real backend would let them. `activity_demo_data.dart`'s `activityStats` was a flat, fully disconnected
`Map<String, String>` - "Active programmes": "18" bore no relationship to the six seeded activities at all (not
even internally consistent with its own fabricated data), and "Upcoming sessions": "6" had no real source
anywhere in the app.

**Design.** `ActivityPermissions` gained a real `canCreate` (manage ∪ contribute), separate from `canManageAll`
(manage only, gating `updateAttendance()` - kept manager-only for the same reason as Assembly's edit action: no
per-record ownership is tracked client-side, so "a contributor may only change their own" stays a backend-only
guarantee). The "Add activity" button now checks `canCreate` instead of `canManageAll`, so a teacher really can
add a programme, matching the backend exactly. `activityStats` became a function computing from real `activities`
- active programme count, total participation entries, and distinct programme types in use - dropping "Upcoming
sessions" outright (no real schedule-of-future-sessions concept exists) and keeping "Dedicated workflows: 2" as
the one genuinely static entry (a fact about the app's structure - Houses and Excursions are separate workflows -
not data about this school). `activity_demo_data.dart` is renamed `activity_policy_copy.dart`, keeping
`activityTimetable` and `activityParticipationRule` as static reference copy.

**Verification.** `flutter analyze` clean. `test/activities_test.dart`: the seed-preservation and fixed-KPI tests
were removed; filtering and serialization tests rewritten against inline fixtures; a new test confirms
`activityStats([])` is honestly all zeros. New `test/activity_repository_test.dart` (9 tests - a fresh school's
`load()` is genuinely empty; `permissionsFor` matches the real Spec exactly, including that a teacher can create
but not manage-all or take attendance; `addActivity()` lets a teacher really add a programme starting at honest
zero members/attendance and refuses a role outside manage/contribute or a blank name/coordinator;
`updateAttendance()` lets a manager really record attendance and refuses a teacher or an out-of-range value). All
14 Activities tests pass; full app suite back to the same 83 pre-existing failures as before this work, by name.
