# Event Ledger

## Principle

**Never overwrite the plan with reality.**

A routine occurrence represents what the system intended.
A logged event represents what actually happened.

## Example

```text
Planned occurrence
Nap #1
10:15
45 min

Logged reality
NapStarted 10:43
NapEnded   11:27
```

This lets NIDO:

- explain schedule shifts;
- calculate variance;
- learn descriptive patterns;
- reconstruct history;
- audit caregiver actions;
- resolve multi-device synchronization.

## Event types

Initial event taxonomy:

```text
childWoke
mealStarted
mealEnded
mealRated
napStarted
napEnded
breastfeedStarted
breastfeedEnded
routineStarted
routineCompleted
routineSkipped
routineRescheduled
modeChanged
weightRecorded
healthNoteRecorded
calendarConflictAcknowledged
```

## Current state derived from ledger

If latest sleep event is:

```text
napStarted(10:43)
```

with no corresponding `napEnded`, child state is sleeping.

Do not store a second independent `isSleeping` truth unless used as a cache with strict derivation semantics.

## Idempotency

Every command should produce stable identifiers where possible.

System-surface actions (Watch, widget, Siri) can be retried. Duplicate command delivery must not create duplicate logical sessions.

## Logical sessions

Long-running activities have a `logicalSessionID`.

Example:

```text
NapStarted session=A
NapEnded   session=A
```

## Event corrections

Users need to correct mistakes.

Prefer correction records / explicit update metadata over silent historical mutation for events that already synced to another caregiver.

## Why an event ledger

It creates a durable backbone for:

- Routine Engine inputs;
- insights;
- multi-caregiver sync;
- pediatrician summaries;
- future import/export.
