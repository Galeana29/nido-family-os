# AGENTS.md

Product invariant: reduce caregiver mental load; do not digitize it.

Loop: PLAN → NOW → DO → OBSERVE → LOG → RECALCULATE → NEXT.

Engineering invariants: Domain/engine do not import SwiftUI. UI does not calculate schedules. Engine must not call Date(); current time is injected. Same normalized inputs + policy version => same output. adjusted is not OccurrenceStatus. Event IDs are stable and sync-ready metadata exists from v0. AI emits CandidateActions only. Numeric explanations come from structured engine output. New conceptual documentation is frozen until canonical scenario tests are green except docs required to unblock code.

`docs/vocabulary.md` is authoritative.
