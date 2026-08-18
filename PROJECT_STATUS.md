# NIDO Project Status

## Current phase

**Architecture / product definition**

The product architecture, core UX philosophy, deterministic Routine Engine, data model, system integrations and safety boundaries have been defined.

## Current objective

Build the first executable iOS skeleton and prove the core loop:

`PLAN → NOW → DO → LOG → RECALCULATE → NEXT`

## First implementation milestone

A simulated full day where:

- child wakes;
- breakfast is logged;
- first nap starts late;
- the day recalculates;
- an external appointment creates a conflict;
- second nap is short;
- bedtime adjusts inside guardrails;
- all surfaces read one `ResolvedDayPlan`.

## Next engineering steps

1. Create Xcode workspace and Swift packages.
2. Implement core domain entities.
3. Implement Routine Engine v0 with exact, anchor, window, relative and dependent timing rules.
4. Add scenario test harness.
5. Build Today screen against fixture data.
6. Add event ledger + local persistence.
7. Connect actual event logging to re-resolution.
8. Add notification attention manager.
9. Add calendar read bridge.
10. Add Widget / Live Activity / Watch incrementally.

## Deferred

- medical diagnostics;
- growth percentile interpretation;
- Android;
- social/community;
- marketplace;
- ML-based scheduling prediction;
- fully autonomous AI planning.
