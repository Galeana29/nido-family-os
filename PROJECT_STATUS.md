# NIDO Project Status

Current phase: **Executable engine proof**. Conceptual architecture is frozen while Swift implementation validates/disproves it.

Product loop: `PLAN → NOW → DO → OBSERVE → LOG → RECALCULATE → NEXT`.

## Milestone: canonical imperfect day — achieved

`examples/sample-day.json` is loaded by the test suite and resolved end to end by `RoutineEngine.resolve(_:)`.
The reviewed engine output is locked as `examples/sample-day.snapshot.txt`. Expected times are produced by
the engine and approved in review; they are never handwritten into a fixture or a test.

What the resolver covers today: all five placement rules (exact, anchor, window, relative, dependent),
dependency graph with cycle detection, priority placement P0→P4, external commitments, duration-responsive
adjustment, manual override, simplified day, hysteresis, and conflict reporting instead of silent dropping.

## Not yet built

- command layer: events are still constructible directly, so `LoggedEvent.hasConsistentPayload` guards the
  type/payload hole until commands are the only construction path;
- persistence of any kind;
- randomized/property scenario coverage;
- any user interface.

## Next

1. engine invariants and seeded property tests, including resolution across a DST change;
2. commands + event ledger (`DO → LOG → RECALCULATE` for real);
3. two-device persistence/sync spike to decide ADR 0011;
4. NidoApp with Today rendered from `ResolvedDayPlan`;
5. real logging, local persistence, notifications and calendar;
6. seven-day family alpha.

Watch, Siri, Live Activities and AI stay deferred until the engine is trustworthy and visible.
