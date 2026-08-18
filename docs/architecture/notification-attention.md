# Attention Architecture

## Problem

A family routine app can become more stressful than the routine if it sends a notification for every item.

## Principle

**Attention is a scarce resource.**

All notification decisions go through one service:

```text
AttentionManager
```

## Attention levels

### L0 — In-app only

Examples:

- play idea;
- optional reading;
- routine detail.

### L1 — Ambient / widget

Visible without interruption.

### L2 — Gentle local notification

Example:

> Snack in 10 minutes.

### L3 — Action notification / Watch haptic

Example:

> Start nap wind-down.

Can contain explicit actions such as:

- Start
- +10 min

### L4 — Alarm

Only explicit/high-value scenarios.

Examples:

- medication configured by caregiver;
- must-leave-for-appointment alarm;
- user-promoted reminder.

## Attention budget

Initial product defaults should cap low-value interruptions.

Example policy:

```text
gentle notifications: ≤ 6/day
action notifications: ≤ 4/day
alarm: explicit user intent only
```

Numbers are product hypotheses, not permanent constants.

## Dedupe

When a day re-resolves:

1. cancel invalid future notifications;
2. preserve current active event;
3. calculate next attention moments;
4. deduplicate notifications referring to the same logical occurrence;
5. reschedule.

## Behavioral learning

If a caregiver repeatedly dismisses a low-priority category, NIDO may propose:

> “You usually don’t need reminders for outdoor time. Turn these off?”

It must not silently suppress medical/locked instructions.

## Anti-patterns

Never:

- notify that a non-critical event is “late” in guilt language;
- send a reminder merely to increase engagement;
- escalate to alarms automatically because notifications are ignored;
- notify for optional activities during Chaos Mode.
