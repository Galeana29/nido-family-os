# Safety & Health Boundaries

## Product classification philosophy

NIDO is a routine coordination system.

It is not a clinician.

## Guidance classes

Every contextual response belongs to one of four classes.

### 1. Routine guidance

Examples:

- what step comes next;
- how to execute configured wind-down;
- whether an optional activity was dropped.

NIDO may answer directly.

### 2. Care-plan guidance

Based on a saved instruction or approved program.

NIDO may present the instruction and its source.

Example:

> “Today’s program says to attempt this nap without a nursing session first.”

### 3. Health guidance

Potential symptoms or health concerns.

NIDO should be conservative and route to appropriate professional resources rather than generate individualized medical decisions.

### 4. Emergency

If an emergency is identified by explicit deterministic criteria or user action, NIDO should not continue normal routine coaching.

## Locked professional instructions

A clinician-authored instruction can be marked locked.

Automation can:

- schedule around it;
- display it;
- remind it;
- record adherence.

Automation cannot silently alter the substance.

## Gradual programs

Behavioral transitions must have explicit stage rules.

The engine does not infer escalation from apparent correlations.

Example fields:

```text
stage
hold criteria
advance criteria
pause conditions
fallback
source
```

## Sick Mode

Sick Mode should:

- pause progressive behavior-change programs;
- suppress development optimization;
- reduce notification pressure;
- preserve health/care instructions.

## Insights

Allowed:

> “On days with fewer unplanned nursing sessions, meal ratings were also higher.”

Not allowed solely from observational logs:

> “Reducing nursing caused appetite to improve.”

## Safety copy

Use factual language.

Avoid panic.

Avoid false reassurance.
