# SchoolOS App

SchoolOS App is the native, offline-first client for the SchoolOS platform.

## Targets

One Flutter codebase targets:

- Android phones
- Android tablets
- Windows desktop

The UI adapts to the available screen size and input mode. Phone, tablet, and desktop share business logic but may use different navigation and workspace layouts.

## Core product rules

1. **One SchoolOS app** — schools do not get separate codebases.
2. **Person-first accounts** — one account can belong to one or many schools.
3. **Membership-scoped roles** — a person may be a teacher in one school, a parent in another, and a proprietor in another.
4. **Strict tenant isolation** — cached and synchronized data is always scoped to the active school membership.
5. **Offline-first daily operations** — supported workflows continue without internet and synchronize later.
6. **Edge AI is a first-class capability** — lightweight on-device AI can work offline; cloud AI handles heavier tasks when connectivity is available.
7. **Cloud remains authoritative** — the SchoolOS Django/DRF backend is the source of truth for server-managed records, permissions, security policy, and conflict resolution.

## Repository relationship

- `Bkzazzau1/schoolOS` — SchoolOS cloud platform, web application, backend, cloud AI, infrastructure.
- `Bkzazzau1/schoolOS-app` — Flutter Android/Windows app, offline engine, sync client, device integrations, and edge AI runtime.

## Current foundation

Implemented now:

- Flutter package foundation
- Material 3 application root
- Adaptive phone/tablet/desktop breakpoints
- Responsive login screen
- Person-to-school membership domain model
- Multi-school selection screen
- Adaptive application workspace
- Phone bottom navigation
- Tablet/desktop navigation rail
- Visible sync and edge-AI status placeholders
- Initial widget smoke test

Authentication currently uses an explicitly marked foundation/demo flow. Real credentials and school memberships will come from the SchoolOS API in the authentication milestone.

## Initial architecture

```text
lib/
├── app/
│   └── app.dart
├── core/
│   ├── auth/
│   ├── database/
│   ├── network/
│   ├── routing/
│   ├── security/
│   ├── sync/
│   └── tenancy/
├── features/
│   ├── authentication/
│   ├── school_switcher/
│   ├── dashboard/
│   ├── attendance/
│   ├── academics/
│   ├── lesson_plans/
│   ├── students/
│   ├── finance/
│   └── messaging/
├── edge_ai/
│   ├── inference/
│   ├── models/
│   ├── vision/
│   ├── nlp/
│   └── model_manager/
├── shared/
│   ├── layout/
│   ├── models/
│   ├── widgets/
│   └── utils/
└── main.dart
```

## One-time local platform bootstrap

This repository was initialized through GitHub source commits. Generate Flutter's native Android and Windows runner files once from a machine with Flutter installed:

```powershell
git clone https://github.com/Bkzazzau1/schoolOS-app.git
cd schoolOS-app
flutter create --platforms=android,windows --org ng.schoolos .
flutter pub get
flutter analyze
flutter test
```

After that, commit the generated `android/`, `windows/`, `.metadata`, and `pubspec.lock` files so every developer receives the same native project structure.

To run on Windows:

```powershell
flutter run -d windows
```

To inspect Android devices/emulators:

```powershell
flutter devices
```

Then run using the relevant device id:

```powershell
flutter run -d <device-id>
```

## Offline model

The application will keep an encrypted local working set containing only data the signed-in user is authorized to use on that device. Mutations are written locally first where the workflow allows it, queued in an outbox, and synchronized with SchoolOS Cloud when connectivity is available.

```text
User action
   ↓
Local database transaction
   ↓
Outbox / pending sync
   ↓
Network becomes available
   ↓
SchoolOS Sync API
   ↓
Conflict/version validation
   ↓
Cloud acknowledgement
```

The local data boundary must always include the active school/tenant membership so data from two schools cannot be mixed on the device.

## Edge AI model

Edge AI is used where low latency, privacy, or offline operation matters. Examples include:

- document/image quality validation
- lightweight OCR and classification
- local data validation
- offline lesson-plan assistance using downloaded curriculum context
- device-capability-aware model execution

Heavy lesson-plan generation, long-form reasoning, and school-wide analytics can use the SchoolOS cloud AI engine when online.

## Next implementation milestones

1. Generate and commit Android + Windows native runners.
2. Replace foundation authentication with the real SchoolOS API/session layer.
3. Persist the active person, memberships, and selected school securely.
4. Add encrypted local persistence and the synchronization outbox.
5. Implement the first true offline workflow: teacher attendance.
6. Add network-state-aware background synchronization.
7. Define the edge AI runtime boundary and model manager.
8. Build lesson-plan generation with offline draft + cloud enhancement modes.
