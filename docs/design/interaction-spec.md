# Interaction Specification

## Core rule

Every common interaction should aim for **≤2 taps**.

## Today → start event

1. User taps primary CTA on Now Card.
2. Domain command marks occurrence active and logs start if applicable.
3. Card becomes Active state without navigation.

## Meal completion

1. Tap `Finish`.
2. Bottom sheet appears.
3. Select one:
   - none;
   - taste;
   - small;
   - normal;
   - more.
4. Selection saves immediately.
5. Optional “Add detail” remains secondary.

No mandatory food-by-food logging.

## Nap start

From wind-down card:

1. Tap `Asleep`.
2. Record `NapStarted` at current time.
3. Start Live Activity.
4. Re-resolve day only if start variance materially changes future plan.

Long-press/secondary menu can edit the timestamp.

## Nap end

Primary action:

> Woke up

Results:

1. record end;
2. end Live Activity;
3. resolve day;
4. animate changed future occurrences;
5. present concise explanation only when material.

## Recalculation animation

The active event collapses.
Future timeline items move smoothly.
Adjusted items may briefly show a subtle `Adjusted` indicator.

Do not create a modal simply to announce recalculation.

## Delay

Secondary action menu:

```text
+10 min
+20 min
Choose time
Skip
```

Delay becomes explicit input to the engine.

## Quick Log

Global control opens a compact sheet:

```text
Sleep
Meal
Nursing / milk
Diaper
Water
Weight
Note
Speak
```

Selecting a common type should present the smallest possible follow-up.

## Voice

Hold/tap microphone.

Example:

> “She woke up ten minutes ago.”

NIDO displays:

> Nap ended at 11:31 — correct?

Confirm / Edit.

High-confidence reversible actions may later support configurable auto-confirmation.

## Chaos Mode

User activates:

> Today got chaotic

Preview:

> I can simplify the rest of today to dinner, bedtime routine and sleep.

User confirms.

Do not silently enter Chaos Mode based on missed activities.

## Haptics

Use sparingly:

- successful quick log;
- Watch action confirmation;
- meaningful timer completion.

No celebratory haptic for normal parenting tasks.
