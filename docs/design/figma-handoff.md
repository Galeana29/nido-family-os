# Figma Handoff Specification

## File structure

Recommended Figma pages:

```text
00 Cover
01 Foundations
02 Components
03 Today
04 Plan
05 Logging
06 Programs
07 Insights
08 Onboarding
09 Watch
10 Widgets + Live Activities
11 Prototypes
12 Archive
```

## Variables

Create variables instead of duplicated raw values.

Collections:

```text
Color
Spacing
Radius
Typography
Motion
```

Modes:

```text
Light
Dark
```

## Shared language

Component state names must match engineering/domain vocabulary whenever possible.

Example:

```text
NowCard / Upcoming
NowCard / Ready
NowCard / Active
NowCard / Completed
NowCard / Adjusted
```

## First 12 master screens

Design these before broad feature expansion:

1. Onboarding — welcome.
2. Today — normal day.
3. Today — schedule shifted.
4. Now Card — meal.
5. Meal completion sheet.
6. Nap wind-down.
7. Active nap.
8. Nap ended + day recalculated.
9. Quick Log.
10. Plan timeline.
11. Active program — gradual routine transition.
12. Weekly Insights.

## Required states for each screen

At minimum:

- default;
- empty;
- loading where relevant;
- offline where relevant;
- error where relevant;
- Dynamic Type enlarged;
- dark mode.

## Prototype scenario

Create one clickable “imperfect day” prototype:

```text
07:04 wake
07:22 breakfast — eats little
10:44 nap 1 — starts late
11:31 wake
13:30 external appointment
14:45 nap 2
15:18 wake — short nap
17:45 dinner — eats well
19:10 bedtime suggestion shifts earlier
```

Designer should show visually how the schedule reflows after each reality event.

## Handoff annotations

Every non-obvious interaction should identify:

- domain command;
- resulting state;
- source of schedule adjustment;
- whether notification rescheduling occurs;
- whether confirmation is required.

Example annotation:

```text
Tap “Woke up”
→ EndNapCommand
→ LoggedEvent.napEnded
→ RoutineEngine.resolve()
→ ResolvedDayPlan updated
→ Live Activity ends
→ future attention rescheduled
```

## Accessibility review

Each master screen needs:

- VoiceOver order;
- Dynamic Type behavior;
- contrast verification;
- Reduce Motion alternative;
- no state communicated only through color.
