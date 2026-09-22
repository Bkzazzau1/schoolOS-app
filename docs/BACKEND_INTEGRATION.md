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
