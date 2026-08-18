# System Architecture

## Architectural objective

NIDO is a local-first, event-driven family routine system whose central output is one `ResolvedDayPlan` shared by every interface surface.

## High-level architecture

```text
┌────────────────────────────────────────────┐
│                Experience                  │
│ Today · Plan · Insights · Watch · Widgets │
└────────────────────┬───────────────────────┘
                     │ commands / projections
                     ▼
┌────────────────────────────────────────────┐
│                 Domain                     │
│ Household · Person · CarePlan · Routine   │
│ Occurrence · LoggedEvent · Program         │
└────────────────────┬───────────────────────┘
                     │
                     ▼
┌────────────────────────────────────────────┐
│             Routine Engine                 │
│ deterministic schedule resolution         │
│ priorities · dependencies · guardrails    │
└────────────────────┬───────────────────────┘
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
┌─────────────────┐   ┌─────────────────────┐
│ Local Storage   │   │ Apple Services      │
│ event ledger    │   │ Calendar            │
│ templates       │   │ Notifications       │
│ resolved cache  │   │ AlarmKit            │
└────────┬────────┘   │ ActivityKit         │
         │            │ Widget/App Intents  │
         ▼            └─────────────────────┘
┌─────────────────┐
│ Sync Adapter    │
│ CloudKit        │
│ CKSyncEngine    │
└─────────────────┘
```

## Layer responsibilities

### Experience

Shows projections of domain state.

Must not contain scheduling decisions.

### Domain

Owns vocabulary and invariants.

No dependency on SwiftUI.

### Routine Engine

Pure deterministic resolution as far as practical.

Input → output should be reproducible in tests.

### Persistence

Local-first repository implementations.

### Apple services

Adapters around Apple frameworks.

### Intelligence

Optional interpretation/explanation layer. Never authoritative for core schedule or clinical logic.

## Single source of truth

The answer to:

> What happens next?

comes from one object:

```text
ResolvedDayPlan
```

The following must not independently calculate routine state:

- Today;
- Watch;
- widgets;
- notifications;
- Live Activities.

## Typical event flow

User taps **Woke up** from a nap.

```text
NapEndButton
  ↓
EndNapCommand
  ↓
Domain validation
  ↓
LoggedEventRepository.save
  ↓
Local persistence
  ↓
RoutineEngine.resolve
  ↓
ResolvedDayPlanRepository.update
  ↓
Today projection updates
  ↓
ActivityKit ends nap activity
  ↓
AttentionManager reschedules relevant reminders
  ↓
Cloud outbox queues event
```

## Offline guarantees

Without network connectivity, the following must work:

- view current plan;
- start/end meals;
- start/end naps;
- quick log;
- routine resolution;
- program logic;
- local notifications already scheduled;
- local insights from existing data.

## Dependency direction

```text
Features → Domain ← Routine Engine
Features → Service protocols
Infrastructure → Domain protocols
```

Domain never imports infrastructure.

## Project modules

See `docs/engineering/ios-project-structure.md`.
