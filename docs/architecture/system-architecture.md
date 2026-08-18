# System Architecture

NIDO is local-first and event-driven. Every surface consumes one canonical `ResolvedDayPlan`; no UI independently calculates schedule policy.

Experience → Domain ← Routine Engine. Infrastructure implements repository/service protocols. Domain/engine do not import SwiftUI, CloudKit, WidgetKit or persistence frameworks.

Command flow: surface action → typed command → validation → local event semantics → engine resolution → resolved projection → UI/attention projection → async sync queue.

See `process-topology.md` for process ownership and `time-semantics.md` for Operational Day semantics.

Storage is behind repository contracts. ADR 0011 requires a two-device spike before choosing SwiftData-local+CKSyncEngine versus GRDB/SQLite+CKSyncEngine for shared-household production architecture.

Offline guarantee: Today, logging, resolution and already-scheduled local attention work without network.
