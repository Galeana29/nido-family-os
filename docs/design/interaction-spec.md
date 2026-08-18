# Interaction Specification

Common actions aim for ≤2 taps.

User events are logged, then engine re-resolves. UI changes future items only when the new valid candidate is material; otherwise retain the prior displayed plan.

Meal: Finish → quantity descriptor saves immediately; detail optional.
Nap: Asleep logs start; Woke up logs end. Time is injected from event input.
Manual delay: +10/+20/choose/not doing this; override becomes explicit engine input and is not corrected back unless P0 violation.
Quick Log: Sleep/Meal/Nursing-Milk/Diaper/Water/Weight/Note.
Voice later uses deterministic temporal ambiguity classes, not numeric confidence.
Simplified Day is explicit user choice, never inferred from uncompleted items.
