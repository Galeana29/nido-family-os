# Domain Model

NIDO represents intent, resolved projection and reality separately.

## Persisted intent
Household, Person, CarePlan/CareInstruction, RoutineTemplate/RoutineRule.

## DailyOccurrence vs ResolvedOccurrence
`DailyOccurrence` is persisted/materialized identity for a rule on an Operational Day. `ResolvedOccurrence` is an engine output projection carrying both `originalTiming` and `resolvedTiming` plus structured adjustment reasons, so every adjustment is explainable against the intended plan. It is not an independent source of truth and must be reproducible from inputs/policy version.

## Lifecycle
Use only `docs/vocabulary.md`: upcoming, ready, active, completed, skipped, cancelled. `adjusted` is not lifecycle.

## LoggedEvent v0 schema
Stable id, household/person, optional logicalSessionID, type, timestamps, source, createdBy, createdAt, modifiedAt, revision, deletedAt tombstone. Sync-readiness exists before cloud shipping.

## Event taxonomy
Includes child wake, meal start/end/rating, nap/night sleep start/end, night wake, nursing/milk, diaper, water, routine state, mode, weight, health note, calendar conflict acknowledgement and explicit correction.

## Event payloads
`LoggedEvent.payload` carries typed per-event detail (`EventPayload`). Detail is optional by design: logging speed wins and payloads never become mandatory.

- **mealRated** — rating per `vocabulary.md` quantity scale, foods[], behaviors[] (closedMouth / threwFood / distracted / tired / askedForMilk / other), optional note.
- **sleep** — sleepType (night / nap1 / nap2 / other), assistance (none / cuddle / breastfeed / other).
- **breastfeed** — context (wake / nap / bedtime / comfort / other) and a `planned` flag. `planned` distinguishes structured vs on-demand feeding patterns without requiring volume measurement.
- **weight / healthNote** — the measured or entered value.

## Priority
P0 safety/locked care; P1 anchor/external commitment; P2 important; P3 flexible; P4 optional. A medical appointment is normally P1; a locked clinical instruction may be P0.
