import Foundation

/// Turns the full append-only ledger into "what actually holds now".
///
/// One implementation, used by the ledger, the resolver and the reconciler alike. If these three
/// disagreed about which revision is current, two caregivers would see two different days.
public enum LedgerProjection {
    /// Deterministic order: when time in the day ties, fall back to recording order and then to a
    /// stable identifier, so the same set of events always projects to the same sequence.
    public static func inCanonicalOrder(_ events: [LoggedEvent]) -> [LoggedEvent] {
        events.sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
        }
    }

    /// The current revision of everything that still stands: corrections applied, tombstones and
    /// superseded revisions dropped, concurrent corrections resolved to a single winner.
    public static func effective(_ events: [LoggedEvent]) -> [LoggedEvent] {
        let discarded = supersededIDs(events).union(losersOfConcurrentCorrections(events))
        return inCanonicalOrder(events.filter { $0.deletedAt == nil && !discarded.contains($0.id) })
    }

    static func supersededIDs(_ events: [LoggedEvent]) -> Set<EventID> {
        Set(events.compactMap(\.supersedes))
    }

    /// Two devices can correct the same event before either has seen the other's correction. Both
    /// revisions are real and both are kept, but exactly one may describe the present.
    static func losersOfConcurrentCorrections(_ events: [LoggedEvent]) -> Set<EventID> {
        var byTarget: [EventID: [LoggedEvent]] = [:]
        for event in events {
            guard let target = event.supersedes else { continue }
            byTarget[target, default: []].append(event)
        }

        var losers: Set<EventID> = []
        for (_, revisions) in byTarget where revisions.count > 1 {
            guard let winner = revisions.max(by: isOutranked) else { continue }
            for revision in revisions where revision.id != winner.id {
                losers.insert(revision.id)
            }
        }
        return losers
    }

    /// Highest revision wins; then the later edit; then a stable identifier so both devices reach the
    /// same answer without talking to each other.
    static func isOutranked(_ lhs: LoggedEvent, _ rhs: LoggedEvent) -> Bool {
        if lhs.revision != rhs.revision { return lhs.revision < rhs.revision }
        if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt < rhs.modifiedAt }
        return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }
}
