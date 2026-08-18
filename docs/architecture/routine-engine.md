# Routine Engine

Mission: Care Plan + template + external commitments + actual events + current time + mode + previous plan → Resolved Day Plan.

`resolution-algorithm.md` is normative.

Placement rules: Exact, Anchor, Window, Relative, Dependent. Adjustment policies are orthogonal: duration-responsive, conflict, mode, manual override, care constraint.

Priority: P0 safety/locked care; P1 anchor/external; P2 important; P3 flexible; P4 optional.

Lifecycle: upcoming/ready/active/completed/skipped/cancelled. Adjustment is represented by reasons, not lifecycle.

Canonical regression: Nap1 ends 11:31; +195/+210/+225 => 14:46 / 15:01 / 15:16. The prior handwritten 14:45 was invalid and is covered by executable tests.

Stability: retain a still-valid prior plan for immaterial change. Manual override is authoritative except P0 violation. Engine never reads `Date()` for now; time is injected.
