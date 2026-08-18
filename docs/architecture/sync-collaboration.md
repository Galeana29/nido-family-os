# Sync & Collaboration

Offline operation, immediate local writes, eventual sync and stable identity from v0.

## Schema readiness
All sync-eligible records use stable UUIDs. Logged events include logicalSessionID, revision, author/timestamp metadata and tombstones before cloud shipping.

## Storage decision
See ADR 0011. Do not assume SwiftData managed CloudKit sync and custom CKSyncEngine/outbox compose automatically.

Candidate flow after spike: Domain → Repository → local store → outbox/history → CKSyncEngine adapter → private/shared CKDatabase.

Household is the share boundary; caregiver-private data must be modeled outside shared aggregates where necessary. Near-identical overlapping sessions may be proposed as duplicates deterministically, but large discrepancies are never silently merged.
