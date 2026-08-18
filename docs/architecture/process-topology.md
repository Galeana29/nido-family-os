# Process Topology

## Main iOS app
Owns schema migration, complete store maintenance, broad plan persistence, AttentionManager reconciliation and cloud sync coordination.

## Widget / App Intent extension
May read a compatible App Group projection/store, append narrowly scoped idempotent commands/events where supported, and use shared pure validation/engine code. It must not own schema migration, broad background replanning loops or independent notification policy.

After an extension write, record a dirty/re-resolution signal. The main app performs authoritative maintenance when active; time-sensitive intent output may compute a deterministic local projection using the same engine version.

## Apple Watch
Owns UX/commands, not policy.

## Shared storage
Storage remains behind repository protocols. If SwiftData is used with App Group access, the main app owns migrations, consistent with Apple's multi-process guidance.

## Attention
Use a rolling near-term horizon rather than scheduling the whole future calendar.
