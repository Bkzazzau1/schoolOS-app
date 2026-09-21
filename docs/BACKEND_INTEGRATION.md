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

Tests: `test/core/` (45 tests) cover each layer with a fake server and in-memory storage.

## Fixed on the way

The app did not compile: two identical `TransportActionResult` classes were imported together by the transport route and
rider-assignment repositories. The unused import was removed.

## Not done yet (next)

1. **Run the sync engine.** Nothing calls `services.syncEngine.syncActiveSchool()` yet. It should run after sign-in, when
   the app opens, on pull-to-refresh, after a change is queued, and when the connection returns. The Sync Center screen
   should show its summary (`pulled`, offline, needs sign-in).
2. **Signed-out handling.** If the sign-in expires (`needsSignIn`), send the person to the login screen and keep their work.
   On start-up, a saved school with no saved sign-in should open the login screen.
3. **Access** (`access/me/`, hiding screens, the blocking flow) and the **notifications inbox**.
4. Everything in `schoolOS_backend/docs/APP_CHANGES.md` sections B to H, feature by feature.

## Known problems that are not from this work

- 40 Teacher-module tests fail on wrong expected figures, and `staff_proposals_test.dart` fails one test
  ("a proposal must name a valid role") because the app's role list now includes `driver`.
- **`driver` is an app role the backend does not have.** A driver signing in would be skipped by the app (unknown role
  is ignored) and the backend refuses `driver` as a staff role. Decide whether the backend gets a `driver` role.
