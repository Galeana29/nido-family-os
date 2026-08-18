# AGENTS.md — How to work on NIDO

NIDO is a family routine operating system. The product exists to reduce caregiver mental load.

## Non-negotiable architectural rules

1. Routine scheduling is deterministic and lives in `NidoRoutineEngine`.
2. UI must never independently calculate schedule timing.
3. Planned routine occurrences and actual logged events are separate concepts.
4. Every automatic adjustment needs a machine-readable `AdjustmentReason` and a human-readable explanation.
5. Health or professional instructions can be locked and may not be silently overridden.
6. AI may produce candidate actions, summaries and explanations. AI may not directly mutate the event ledger or make clinical decisions.
7. The app must work offline for core functions.
8. The notification system is centralized. Features do not independently schedule attention.
9. Avoid tracking that does not change a decision.
10. No streaks, guilt, failure language or punitive gamification.

## Product loop

`PLAN → NOW → DO → OBSERVE → LOG → RECALCULATE → NEXT`

## Before changing routine behavior

Read:

- `docs/architecture/routine-engine.md`
- `docs/architecture/domain-model.md`
- `docs/architecture/event-ledger.md`
- `docs/safety/safety-health-boundaries.md`

Add scenario tests for any scheduling behavior.

## Before adding a notification

Read `docs/architecture/notification-attention.md`.

Ask: would the product still work if this notification did not exist? If yes, prefer in-app or widget visibility.

## Before adding AI

Read `docs/architecture/intelligence.md`.

All AI output must pass through typed candidate-action validation before persistence.

## Before changing visual language

Read:

- `docs/design/design-system.md`
- `docs/design/content-style.md`
- `docs/design/interaction-spec.md`

## Definition of done

A change is not done until:

- domain behavior is covered by tests where applicable;
- accessibility states exist;
- failure/offline paths are considered;
- design and engineering terminology match;
- documentation is updated for architecture-level changes.
