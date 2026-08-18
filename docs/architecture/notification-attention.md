# Notification & Attention Architecture

Attention is centrally budgeted; features do not schedule independently.

Levels: L0 in-app, L1 glanceable/widget, L2 normal local notification, L3 Watch haptic/action, L4 explicit alarm.

Use a bounded rolling horizon and reconcile after material plan changes; do not pre-schedule weeks of routine reminders. Infrastructure may impose conservative caps, but domain must not encode undocumented platform limits as product truth.

Each attention item has a stable logical key derived from occurrence + purpose; re-resolution replaces/cancels by key rather than stacking duplicates.

AlarmKit is reserved for explicitly important/user-authorized alarms/timers.
