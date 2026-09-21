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
