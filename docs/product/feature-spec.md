# Feature Specification

## Today

### Problem
Caregivers should not need to inspect a schedule and decide what matters.

### Outcome
Today exposes one primary current action and only the next few relevant events.

### Requirements

- one hero Now Card;
- next 2–3 events;
- day-state sentence;
- active program;
- caregiver personal window when useful;
- conflict/exception only if actionable.

## Adaptive timeline

### Outcome
Changes in actual events produce a new resolved day without rewriting the underlying template.

### Requirements

- deterministic resolution;
- priority-aware conflict handling;
- explicit adjustment reasons;
- manual override always available;
- stable single source of truth.

## Meal tracking

### Outcome
Useful information with minimal burden.

### Required rating

```text
none / taste / small / normal / more
```

Optional behavior detail.

### Anti-requirement
No mandatory gram/calorie tracking.

## Sleep

### Requirements

- wind-down occurrence;
- nap start/end;
- active state;
- Live Activity;
- downstream replanning;
- editable timestamp.

## Gradual programs

Programs represent staged behavior/routine changes.

Examples:

- gradual daytime nursing reduction;
- future nap transition;
- bedtime routine change.

Program must support:

```text
stage
stage goal
hold criteria
advance criteria
pause
revert
source/owner
```

## Calendar conflict detection

Read external commitments with permission.

Calendar items become exact external constraints.

NIDO routines remain internal.

## Quick Log

Global entry point for:

- sleep;
- meal;
- nursing/milk;
- diaper;
- water;
- weight;
- note;
- speech.

## Chaos Mode

Explicit user-triggered simplification.

The engine resolves a Minimum Viable Day.

## Sick Mode

Explicit mode that:

- pauses progressive programs;
- reduces low-value reminders;
- allows sleep flexibility;
- preserves locked professional instructions.

## Insights

Descriptive, not diagnostic.

Example:

> “Days with fewer on-demand nursing sessions also had higher solid-food ratings this week.”

Not:

> “Reducing nursing caused better eating.”

## Pediatrician summary

Future / post-core feature.

Summarize selected date range:

- sleep;
- meal rating;
- nursing/milk;
- relevant notes;
- weight entries;
- program changes.

Export remains user-controlled.
