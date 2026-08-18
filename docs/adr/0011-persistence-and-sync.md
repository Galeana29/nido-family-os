# ADR 0011 — Persistence and sync path

**Status: Proposed / spike required**

NIDO needs offline-first writes and eventually a shared household. SwiftData managed CloudKit and custom CKSyncEngine are not assumed to be one automatic stack.

Apple currently exposes SwiftData managed CloudKit modes automatic/private/none. CKSyncEngine can target private and shared CKDatabase instances with separate engines.

Candidates: A managed SwiftData CloudKit; B SwiftData local with managed sync disabled + custom CKSyncEngine; C GRDB/SQLite + custom CKSyncEngine.

Decision: do not lock B/C from docs alone. Run a two-device spike with stable IDs, private/shared topology, A→B nap propagation, concurrent edit, tombstone propagation, account behavior and extension/App Group access. The spike chooses the store. Domain/repository contracts remain storage-agnostic.

Regardless of store, V0 includes stable UUID, logicalSessionID, revision, created/modified/author metadata and deletedAt tombstone.
