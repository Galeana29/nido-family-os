# Domain Model

NIDO represents intent, resolved projection and reality separately.

## Persisted intent
Household, Person, CarePlan/CareInstruction, RoutineTemplate/RoutineRule.

## DailyOccurrence vs ResolvedOccurrence
`DailyOccurrence` is persisted/materialized identity for a rule on an Operational Day. `ResolvedOccurrence` is an engine output projection containing the timing currently resolved plus structured adjustment reasons. It is not an independent source of truth and must be reproducible from inputs/policy version.

## Lifecycle
Use only `docs/vocabulary.md`: upcoming, ready, active, completed, skipped, cancelled. `adjusted` is not lifecycle.

## LoggedEvent v0 schema
Stable id, household/person, optional logicalSessionID, type, timestamps, source, createdBy, createdAt, modifiedAt, revision, deletedAt tombstone. Sync-readiness exists before cloud shipping.

## Event taxonomy
Includes child wake, meal start/end/rating, nap/night sleep start/end, night wake, nursing/milk, diaper, water, routine state, mode, weight, health note, calendar conflict acknowledgement and explicit correction.

## Priority
P0 safety/locked care; P1 anchor/external commitment; P2 important; P3 flexible; P4 optional. A medical appointment is normally P1; a locked clinical instruction may be P0.
