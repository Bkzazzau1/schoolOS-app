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
5. **Role isolation** — visible modules and actions are determined by the active school membership, not by a global user role.
6. **Offline-first daily operations** — supported workflows save locally first and synchronize later.
7. **Edge AI is first-class** — lightweight on-device AI can work offline; cloud AI handles heavier tasks when connectivity is available.
8. **Cloud remains authoritative** — the Django/DRF backend owns server permissions, canonical records, versioning, and conflict decisions.

## Repository relationship

- `Bkzazzau1/schoolOS` — web application, Django/DRF backend, cloud AI and infrastructure.
- `Bkzazzau1/schoolOS-app` — Flutter Android/Windows client, offline engine, device integrations and edge AI.

## Current implementation

Implemented:

### App and tenancy

- Flutter package foundation
- adaptive phone/tablet/desktop layout
- person-to-school membership model
- secure persistence of the full authorized school-membership list
- secure active-school restoration after app restart
- in-app school switching without signing out
- validation that a user cannot switch into a membership outside the authenticated session
- membership-scoped role/capability filtering
- teacher and parent memberships can expose different modules for the same person

### Offline storage and synchronization

- platform secure key storage
- AES-256-GCM encryption for sensitive cached payloads
- SQLite local database for Android and Windows
- explicit tenant columns on local records
- tenant + membership scoping on sync mutations
- durable sync outbox
- mutation coalescing for repeated offline edits
- retry/error/conflict state model
- transport-independent sync engine
- server-version persistence after successful sync
- real pending-sync counter in the app shell

### Offline attendance

- first real offline workflow: **teacher attendance**
- cached class roster
- saved attendance restoration
- Present / Absent / Late / Excused states
- local-first encrypted save
- automatic outbox mutation creation
- pending-sync counter refresh after save

The current class roster is clearly marked foundation/demo data until the authorized working-set download API is connected.

### Lesson-plan assistant

- adaptive lesson-plan UI for phone, tablet and Windows
- class, subject, topic, term, week and lesson-duration context
- optional learning objectives and available resources
- guaranteed offline lesson-plan draft generation
- Edge-AI enhancement boundary
- cloud-AI enhancement boundary
- explicit output mode: offline / Edge AI / cloud enhanced
- safe fallback when Edge or cloud AI is unavailable
- encrypted local lesson-plan persistence
- separate **Save on device** and **Save & sync** flows
- lesson plans selected for synchronization use the same tenant-safe outbox as attendance

A teacher is never blocked from producing a basic lesson plan because internet or an AI model is unavailable.

### Edge AI model lifecycle

- versioned model manifest
- capability metadata such as lesson-plan text, OCR, document quality and vision
- ONNX/TFLite model-format metadata
- Android/Windows compatibility metadata
- minimum-RAM metadata
- file-size verification
- streaming SHA-256 integrity verification
- safe `.part` installation before final model activation
- sanitized model storage paths
- re-verification before an installed model is reported as ready
- model lifecycle separated from feature inference

No Edge AI model is currently bundled or falsely reported as active. The app is ready for a verified runtime/model to be connected later.

### Quality

- GitHub Actions CI
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- CI concurrency cancels superseded runs on the same branch
- tests cover membership role isolation, attendance domain behavior, offline lesson-plan fallback and Edge model metadata

Current validated head passed both analysis and tests before this documentation update.

## Main source structure

```text
lib/
├── app/
│   ├── app.dart
│   └── app_services.dart
├── core/
│   ├── auth/
│   │   └── app_capability.dart
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
│   ├── attendance/
│   └── lesson_plans/
├── edge_ai/
│   ├── inference/
│   ├── model_manager/
│   └── models/
└── shared/
```

## Offline write path

```text
User action
    ↓
Active membership + tenant validation
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

The local database still uses explicit tenant columns for query isolation. Encryption complements tenant isolation; it does not replace backend authorization checks.

## Lesson-plan generation path

```text
Lesson context
    ↓
Always-available offline generator
    ↓
Usable local draft
    ↓
Optional verified Edge AI enhancement
    ↓
Optional cloud enhancement
    ↓
Save locally OR save + sync
```

Edge and cloud AI are enhancement layers, not availability dependencies.

## One-time native platform generation

The repository currently contains the Flutter/Dart application source. If Android and Windows runners are not yet in your local clone, generate them once with Flutter:

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

1. build a user-visible Sync Center for pending, failed and conflicting changes;
2. connect real SchoolOS authentication and membership APIs;
3. define the Django sync endpoint and implement the app's concrete `SyncTransport`;
4. add connectivity-aware/background synchronization;
5. download authorized school/class/student working sets for offline use;
6. add conflict-review and resolution actions;
7. connect a verified Android/Windows Edge inference runtime;
8. select and validate the first local lesson-plan model;
9. connect cloud lesson-plan enhancement;
10. expand offline workflows to scores, lesson records and messaging.
