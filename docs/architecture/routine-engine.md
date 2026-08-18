# Routine Engine

## Mission

The Routine Engine converts:

```text
Care Plan
+ Routine Template
+ External Commitments
+ Actual Events
+ Current Time
+ Current Mode
→ Resolved Day Plan
```

It is deterministic, testable and explainable.

## Why deterministic

Caregivers must be able to understand why NIDO moved an event.

Engineering must be able to reproduce the same input and receive the same output.

Health-related constraints must not be subject to model creativity.

## Timing rule families

### Exact

Used for externally fixed commitments.

```text
Pediatrician appointment = 14:30
```

Engine does not move it.

### Anchor

A preferred time with guardrails.

```text
Bedtime
preferred = 19:30
allowed = 19:00–20:00
```

### Window

An activity should occur within a range.

```text
Nap 1
start = 10:05–10:40
preferred = 10:20
```

### Relative

Timing relative to a prior event or occurrence.

```text
Snack
minimum after breakfast = 120 min
preferred = 150 min
maximum = 180 min
```

### Dependent

Directly depends on actual state.

```text
Nap 2 depends on Nap 1 wake event
preferred offset = +3h30
allowed = +3h15...+3h45
```

## Priority model

```text
P0 = safety / locked medical
P1 = anchor / external commitment
P2 = important routine
P3 = flexible
P4 = optional
```

When the schedule compresses, lower priorities move/disappear before higher priorities.

## ResolvedDayPlan

The engine emits a single canonical plan consumed by all surfaces.

```swift
struct ResolvedDayPlan {
    let date: LocalDate
    let generatedAt: Date
    let mode: DayMode
    let occurrences: [ResolvedOccurrence]
    let summary: DayResolutionSummary
}
```

## ResolvedOccurrence

```swift
struct ResolvedOccurrence {
    let id: OccurrenceID
    let ruleID: RoutineRuleID

    let originalTiming: PlannedTiming
    let resolvedTiming: ResolvedTiming

    let priority: RoutinePriority
    let status: OccurrenceStatus

    let adjustmentReasons: [AdjustmentReason]
}
```

## AdjustmentReason

Every change must be explainable.

Examples:

```text
priorNapEndedLate(minutes: 31)
externalCommitmentConflict(eventID)
shortNap(minutes: 28)
minimumMealSpacing(minutes: 120)
chaosModeSimplification
sickModeGuardrail
careInstructionConstraint(id)
manualOverride
```

The UI can translate these into human language.

## Example

### Original plan

```text
07:00 Wake
07:20 Breakfast
10:15 Nap 1
11:00 Wake
12:00 Lunch
13:00 Outdoor
14:15 Nap 2
15:30 Wake
17:45 Dinner
19:30 Bedtime
```

### Reality

Nap 1 happens:

```text
10:44–11:31
```

Calendar includes:

```text
Doctor 13:30–14:10
```

### Resolution

```text
07:20 Breakfast   unchanged
10:44 Nap 1       actual
12:05 Lunch       +5 min
13:00 Outdoor     omitted / optional
13:30 Doctor      fixed
14:45 Nap 2       +30 min
15:50 Wake        estimated
17:45 Dinner      anchor retained
19:30 Bedtime     re-evaluate after Nap 2
```

Every changed occurrence carries reasons.

## Manual override

The caregiver is authoritative.

A user can explicitly:

- start now;
- delay;
- skip;
- move;
- mark complete.

Manual overrides become input to the next resolution.

The system should not repeatedly “correct” the caregiver back toward an old plan.

## Modes

### Normal

Full plan.

### Daycare

NIDO manages before/after daycare and treats daycare hours as externally managed.

### Out

Preserve essential feeding/sleep/health and reduce structured activities.

### Sick

Disable program progression, reduce notifications, prioritize hydration/comfort and preserve professional instructions.

### Chaos

Resolve to the Minimum Viable Day.

### Custom

Explicit user-defined temporary policy.

## Minimum Viable Day

In Chaos Mode:

1. include P0;
2. include P1;
3. retain P2 if compatible;
4. suppress P3/P4 unless explicitly selected.

The UI must not label omitted optional items as failures.

## Safety rule

The engine can reorganize a routine only inside declared policy.

It may not infer clinical guidance from logs.

Example:

If a gradual nursing-reduction program says “do not progress when intake is low,” the program state machine provides that rule. The engine does not invent it from correlation.

## Future personalization

After enough history, NIDO may estimate personalized preferred windows.

Any learned value enters as a proposal/configurable parameter, not as hidden autonomous logic.
