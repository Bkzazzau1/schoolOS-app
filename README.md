# SchoolOS App

SchoolOS App is the native, offline-first client for the SchoolOS platform.

## Targets

One Flutter codebase targets:

- Android phones
- Android tablets
- Windows desktop

Phone, tablet, and desktop share domain/business logic while using adaptive navigation and workspace layouts.

## Core product rules

1. **One SchoolOS app** — schools do not get separate codebases.
2. **Person-first accounts** — one account can belong to one or many schools.
3. **Membership-scoped roles** — the same person may be a teacher in one school, a parent in another, and a proprietor in another.
4. **Strict tenant isolation** — every cached record and sync mutation is scoped to a school tenant.
5. **Offline-first daily operations** — supported workflows save locally first and synchronize later.
6. **Edge AI is first-class** — lightweight on-device AI can work offline; cloud AI handles heavier tasks when connectivity is available.
7. **Cloud remains authoritative** — the Django/DRF backend owns server permissions, canonical records, versioning, and conflict decisions.

## Repository relationship

- `Bkzazzau1/schoolOS` — web application, Django/DRF backend, cloud AI and infrastructure.
- `Bkzazzau1/schoolOS-app` — Flutter Android/Windows client, offline engine, device integrations and edge AI.

## Current implementation

Implemented:

- Flutter package foundation
- adaptive phone/tablet/desktop layout
- person-to-school membership model
- multi-school selection foundation
- secure active-school restoration
- platform secure key storage
- AES-256-GCM encryption for sensitive cached payloads
- SQLite local database for Android and Windows
- tenant-scoped local record cache
- durable sync outbox
- mutation coalescing for repeated offline edits
- retry/error/conflict state model
- transport-independent sync engine
- server-version persistence after successful sync
- first real offline workflow: **teacher attendance**
- cached attendance roster
- saved attendance restoration
- pending-sync dashboard counter
- CI: `flutter analyze` + `flutter test`

The authentication screen still uses an explicitly marked foundation/demo flow. Real credentials and memberships will come from the SchoolOS backend.

## Main source structure

```text
lib/
├── app/
│   ├── app.dart
│   └── app_services.dart
├── core/
│   ├── database/
│   │   └── local_database.dart
│   ├── security/
│   │   └── payload_cipher.dart
│   ├── sync/
│   │   ├── sync_engine.dart
│   │   ├── sync_mutation.dart
│   │   └── sync_transport.dart
│   └── tenancy/
│       ├── school_session_controller.dart
│       └── school_session_store.dart
├── features/
│   ├── authentication/
│   ├── school_switcher/
│   ├── dashboard/
│   └── attendance/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── edge_ai/
└── shared/
```

## Offline write path

```text
Teacher action
    ↓
Tenant + membership validation
    ↓
Encrypted local SQLite record
    ↓
Sync outbox mutation
    ↓
App keeps working offline
    ↓
Connectivity available
    ↓
SyncEngine
    ↓
SchoolOS Django/DRF transport
    ↓
Accepted / conflict / rejected
```

Repeated edits of the same unsynchronized entity are coalesced into the existing pending mutation instead of filling the outbox with duplicates.

## Local security model

Sensitive cached JSON payloads are encrypted with AES-256-GCM before SQLite storage. A per-installation master key is generated and stored with `flutter_secure_storage`, not inside the database.

The local database still uses explicit tenant columns for query isolation. Encryption complements tenant isolation; it does not replace authorization checks.

## Attendance foundation

The current attendance workflow demonstrates the intended offline pattern:

1. roster is loaded from local cache;
2. teacher marks Present / Absent / Late / Excused;
3. save updates the encrypted local attendance session;
4. the same transaction is represented in the sync outbox;
5. dashboard pending count updates immediately;
6. later sync sends the mutation to the cloud transport.

The current roster is clearly marked foundation/demo data until the backend download/bootstrap API is connected.

## One-time native platform generation

If Android and Windows runners are not yet in your local clone:

```powershell
git clone https://github.com/Bkzazzau1/schoolOS-app.git
cd schoolOS-app
flutter create --platforms=android,windows --org ng.schoolos .
flutter pub get
flutter analyze
flutter test
```

Then commit generated native files:

```powershell
git add .
git commit -m "Generate Android and Windows Flutter runners"
git push
```

Run Windows:

```powershell
flutter run -d windows
```

List Android devices/emulators:

```powershell
flutter devices
```

Run Android:

```powershell
flutter run -d <device-id>
```

## Current minimum toolchain

The offline/security dependencies use Dart `>=3.10.0`. Use a current stable Flutter installation.

## Next milestones

1. connect real authentication and membership APIs;
2. define the Django sync endpoint and implement `SyncTransport`;
3. add connectivity-aware/background sync;
4. download authorized school/class/student working sets for offline use;
5. add conflict-review UI;
6. establish edge-AI model manager/runtime;
7. build hybrid lesson-plan generation: offline draft + cloud enhancement;
8. expand offline workflows to scores, lesson records and messaging.
