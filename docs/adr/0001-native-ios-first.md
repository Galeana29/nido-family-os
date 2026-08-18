# ADR 0001 — Native iOS first

## Status
Accepted

## Decision
Build NIDO v1 natively in Swift/SwiftUI.

## Context
The product depends deeply on iOS system surfaces: EventKit, AlarmKit, ActivityKit, WidgetKit, App Intents, Speech, Watch and local-first persistence.

## Consequence
Android is deferred. Product quality and system integration are prioritized over cross-platform code reuse.
