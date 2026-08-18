# Testing Strategy

## Highest-risk component

The Routine Engine.

It needs scenario tests before UI polish.

## Unit test categories

### Timing rules

- exact event never moves;
- anchor remains within guardrails;
- window selection;
- relative spacing;
- dependent timing.

### Priority resolution

- P4 removed before P2;
- P0 is never silently displaced;
- calendar commitment outranks optional routine.

### Modes

- Sick disables program progression;
- Chaos suppresses optional activities;
- Daycare treats managed interval as external;
- Out preserves essentials.

### Manual override

- delay persists as input;
- skip is respected;
- engine does not bounce an occurrence back to the old target.

## Required scenarios

### Late first nap

```text
Nap1 actual start +30m
→ Nap2 shifts according to dependency
→ bedtime remains within anchor bounds
```

### Fixed appointment conflict

```text
Doctor overlaps outdoor + nap window
→ doctor unchanged
→ outdoor omitted/moved
→ nap adjusts
```

### Short second nap

```text
Nap2 duration << expected
→ bedtime can move earlier inside policy
```

### Sick mode

```text
active gradual program
+ sick mode
→ no automatic stage progression
```

### Chaos mode

```text
remaining P0/P1/P2/P3/P4
→ simplified plan retains essentials only
```

### Duplicate event

```text
same logical nap-end command delivered twice
→ one logical event/session outcome
```

## Full-day acceptance simulation

Fixture:

```text
07:04 wake
07:22 breakfast small
10:44 nap1 start
11:31 nap1 end
13:30 appointment
14:45 nap2 start
15:18 nap2 end
17:45 dinner good
19:10 proposed bedtime
```

Assertions:

- no impossible overlap;
- no violation of locked instruction;
- explanations exist for adjusted occurrences;
- Today/Widget/Watch consume identical resolved data;
- no duplicate notification for a moved event.

## UI tests

Focus on critical flows:

- meal in ≤2 taps;
- nap start/end;
- quick log;
- Chaos Mode;
- calendar permission denied;
- offline mode.

## Accessibility tests

- VoiceOver labels/order;
- Dynamic Type XL/AX sizes;
- dark mode;
- Reduce Motion;
- contrast;
- buttons remain reachable one-handed.
