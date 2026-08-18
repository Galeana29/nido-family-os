# Sync & Collaboration Architecture

## Goals

- Core operation offline.
- Immediate local writes.
- Eventual synchronization.
- Architecture prepared for multiple caregivers.
- Domain remains independent from CloudKit.

## Layers

```text
Domain
  ↓
Repository protocols
  ↓
Local persistence
  ↓
Outbox
  ↓
Sync adapter
  ↓
CloudKit / CKSyncEngine
```

## Local-first mutation flow

```text
User action
→ domain command
→ validate
→ save locally
→ UI updates
→ Routine Engine re-resolves
→ mark change pending sync
→ asynchronous cloud sync
```

The UI never waits for cloud success before acknowledging a local routine event.

## Repository contracts

Examples:

```swift
protocol EventRepository {
    func save(_ event: LoggedEvent) async throws
    func events(for person: PersonID, range: DateInterval) async throws -> [LoggedEvent]
}

protocol RoutineRepository { ... }
protocol HouseholdRepository { ... }
```

Implementations can evolve independently.

## Household sharing

A household is the natural collaboration boundary.

Potential CloudKit model:

```text
Household root record
  ├── Persons
  ├── Routine templates
  ├── Care plans
  ├── Logged events
  └── Preferences
```

The shared household must not make all personal caregiver data automatically visible. Model privacy scopes explicitly.

## Outbox

Every sync-eligible local mutation gets a dirty/pending representation.

The sync engine processes pending changes asynchronously.

## Conflicts

Routine events can be concurrently logged by different caregivers.

Required metadata:

```text
createdAt
modifiedAt
createdBy
logicalSessionID
revision
```

## Duplicate-session reconciliation

Example:

Majo logs nap start 10:43.
Julio logs nap start 10:45.

If:

```text
same child
same activity type
near-identical time
sessions overlap
```

reconciliation can suggest one logical session.

Do not silently merge large discrepancies.

## Primary-caregiver V1 simplification

Architecture supports sharing, but first product testing may designate one device as primary while sync stabilizes.

This reduces launch risk without corrupting the underlying model.
