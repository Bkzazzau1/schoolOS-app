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

## Initial architecture

```text
lib/
├── app/
│   ├── app.dart
│   └── bootstrap.dart
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
│   ├── models/
│   ├── widgets/
│   └── utils/
└── main.dart
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

## Edge AI model

Edge AI is used where low latency, privacy, or offline operation matters. Examples include document quality checks, lightweight OCR/classification, local validation, and offline lesson-plan assistance using downloaded school/curriculum context. Heavy generation and school-wide analytics can use the cloud AI engine when online.

## Repository relationship

- `Bkzazzau1/schoolOS` — SchoolOS cloud platform, web application, backend, cloud AI, infrastructure.
- `Bkzazzau1/schoolOS-app` — Flutter Android/Windows app, offline engine, sync client, device integrations, and edge AI runtime.

## Current phase

Foundation. The first milestones are:

1. Flutter project bootstrap for Android + Windows.
2. Adaptive application shell for phone/tablet/desktop.
3. Authentication and school membership selection.
4. Encrypted local persistence and sync outbox.
5. First offline workflow: teacher attendance.
6. Edge AI runtime boundary and lesson-plan assistant foundation.
