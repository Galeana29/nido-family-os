# Resolution Algorithm

Normative for `NidoRoutineEngine`.

## Core invariant
Among valid plans, prefer the plan that creates the least cognitive change from the plan already shown to the caregiver.

## Evaluation order
1. Validate IDs/time zone/Operational Day.
2. Apply P0 safety/locked-care constraints.
3. Materialize exact external commitments.
4. Resolve dependency graph; cycles are invalid.
5. Generate candidate windows.
6. Place P1.
7. Place P2.
8. Fit P3.
9. Keep P4 only if compatible.
10. Apply AdjustmentPolicies.
11. Compare with previous plan.
12. Apply hysteresis/materiality.
13. Validate invariants.
14. Emit plan + structured AdjustmentReasons.

## Placement vs adjustment
Placement rules: Exact, Anchor, Window, Relative, Dependent.
Adjustment policies: duration-responsive, external conflict, day mode, manual override, care constraint.

## Hysteresis
V0 default materiality threshold is 5 minutes. Retain a previous displayed preferred time for sub-threshold movement only when it remains inside current hard guardrails. Never keep an invalid prior time merely to avoid jitter.

## Lifecycle
`upcoming → ready → active → completed`; skipped/cancelled are terminal alternatives. `adjusted` is not a lifecycle state.

## Infeasibility
Authority order: P0 > explicit manual override unless P0 violation > exact external P1 > P1 anchor > P2 > P3 > P4. Same-rank hard conflicts without a declared tiebreak emit an explicit conflict for caregiver resolution.

## Determinism
No `Date()` inside engine logic, no randomness, no locale parsing, no AI calls. Same normalized inputs + policy version => same output.
