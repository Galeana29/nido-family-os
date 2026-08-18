# Apple Platform Integrations

NIDO is intentionally native-first because its value extends beyond the app window.

## EventKit

Purpose:

- read external calendar commitments;
- detect conflicts with routine windows;
- optionally create explicitly requested external calendar events.

NIDO routine occurrences are not mirrored wholesale into Calendar.

## UserNotifications

Used for normal local reminders.

All scheduling passes through `AttentionManager`.

Features do not independently request notifications.

## AlarmKit

Use only for events that the user explicitly promotes to alarm-level attention or for genuinely critical configured routines.

Never use AlarmKit merely to maximize engagement.

## ActivityKit

Primary v1 use:

- active nap;
- selected running timers such as meal preparation.

A Live Activity exists when an activity is truly in progress—not as an all-day dashboard.

## WidgetKit

Widget jobs:

- now;
- next;
- selected quick action;
- Watch complications.

Widgets should be glanceable.

## App Intents

Initial intents:

- `LogNapStartIntent`
- `LogNapEndIntent`
- `LogMealIntent`
- `LogBreastfeedIntent`
- `AskWhatsNextIntent`
- `EnableChaosModeIntent`

All intents call domain commands. They do not bypass validation.

## Speech

Speech handles transcription only.

Transcribed language is interpreted into typed candidate actions before persistence.

## Foundation Models

Suitable for:

- phrase → structured candidate intent;
- summaries;
- explanation drafting;
- descriptive insights.

Not suitable as authority for:

- schedule calculations;
- medication/dosing;
- clinical diagnosis;
- autonomous changes to a care plan.

## Apple Watch

Watch is intentionally narrow:

1. Now.
2. Quick Log.
3. Active timer/nap.

Do not port the entire iPhone navigation hierarchy to Watch.
