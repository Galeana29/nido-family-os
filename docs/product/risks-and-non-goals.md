# Risks & Non-goals

## Risk — Over-automation

NIDO could become a controlling schedule robot.

Mitigation:

- flexible windows;
- explicit user override;
- neutral language;
- explainable changes.

## Risk — Tracking burden

Too much logging makes NIDO another chore.

Mitigation:

- approximate meal ratings;
- Quick Log;
- voice;
- optional detail;
- track only decision-relevant events.

## Risk — Notification fatigue

Mitigation:

- centralized AttentionManager;
- attention budget;
- low-priority items stay in app/widget;
- AlarmKit is explicit.

## Risk — Clinical overreach

Mitigation:

- deterministic safety boundaries;
- locked professional instructions;
- no diagnosis;
- AI cannot alter care plans.

## Risk — Sync complexity

Mitigation:

- local-first;
- repository abstraction;
- event IDs/logical sessions;
- primary-device rollout possible.

## Risk — Scheduling complexity before product validation

Mitigation:

V1 uses explicit rules and fixtures before learned prediction.

## Non-goals for V1

- Android;
- social network;
- community advice;
- recipe marketplace;
- clinical diagnosis;
- dosing engine;
- growth diagnosis;
- photo journal;
- full daycare management;
- ML-based autonomous schedule prediction;
- generative AI chat as the primary interface.
