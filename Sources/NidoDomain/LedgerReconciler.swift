import Foundation

/// Two caregivers logged what looks like the same nap. The system may say so; it may not decide.
public struct DuplicateSessionProposal: Sendable, Equatable, Hashable {
    public let kind: ActivityKind
    /// The earlier session — the first record of that piece of reality.
    public let kept: SessionID
    public let duplicate: SessionID
    public let startDifferenceMinutes: Int
}

/// Both devices corrected the same event before seeing each other's correction.
public struct RevisionConflict: Sendable, Equatable, Hashable {
    public let target: EventID
    public let winner: EventID
    public let loser: EventID
}

public struct MergeReport: Sendable, Equatable {
    public let events: [LoggedEvent]
    public let added: [EventID]
    public let duplicateSessions: [DuplicateSessionProposal]
    public let revisionConflicts: [RevisionConflict]
}

/// Merges two ledgers that drifted apart while offline.
///
/// The merge is a union, not a choice: nothing is ever discarded, because a device that was in a
/// basement for two hours is not wrong. Where two records describe the same reality the reconciler
/// says so and stops. Silently collapsing them would mean deciding, on thin evidence, that one
/// caregiver's account of the afternoon did not happen.
public enum LedgerReconciler {
    /// Sessions starting further apart than this are treated as genuinely different activities.
    public static let duplicateStartTolerance: TimeInterval = 15 * 60

    public static func merge(_ local: [LoggedEvent], _ remote: [LoggedEvent]) -> MergeReport {
        var byID: [EventID: LoggedEvent] = [:]
        for event in local { byID[event.id] = event }

        var added: [EventID] = []
        for event in remote where byID[event.id] == nil {
            byID[event.id] = event
            added.append(event.id)
        }

        let union = LedgerProjection.inCanonicalOrder(Array(byID.values))
        return MergeReport(
            events: union,
            added: added.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString },
            duplicateSessions: duplicateSessions(in: union),
            revisionConflicts: revisionConflicts(in: union)
        )
    }

    // MARK: - Duplicate sessions

    struct Session {
        let id: SessionID
        let kind: ActivityKind
        let ruleID: RuleID?
        let start: Date
        var end: Date?

        var interval: DateInterval {
            DateInterval(start: start, end: max(end ?? start, start))
        }
    }

    static func sessions(in events: [LoggedEvent]) -> [Session] {
        var byID: [SessionID: Session] = [:]
        var order: [SessionID] = []

        for event in LedgerProjection.effective(events) {
            guard let session = event.logicalSessionID, let kind = event.type.activityKind else { continue }
            if event.type.opensSession {
                if byID[session] == nil { order.append(session) }
                byID[session] = Session(id: session, kind: kind, ruleID: event.ruleID, start: event.startedAt, end: byID[session]?.end)
            } else if event.type.closesSession {
                byID[session]?.end = event.startedAt
            }
        }
        return order.compactMap { byID[$0] }
    }

    static func duplicateSessions(in events: [LoggedEvent]) -> [DuplicateSessionProposal] {
        let candidates = sessions(in: events).sorted { lhs, rhs in
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
        }

        var proposals: [DuplicateSessionProposal] = []
        for outer in candidates.indices {
            for inner in candidates.indices where inner > outer {
                let first = candidates[outer]
                let second = candidates[inner]
                guard first.kind == second.kind, first.ruleID == second.ruleID else { continue }

                let difference = abs(second.start.timeIntervalSince(first.start))
                guard difference <= duplicateStartTolerance else { continue }
                guard first.interval.intersects(second.interval) || difference == 0 else { continue }

                proposals.append(DuplicateSessionProposal(
                    kind: first.kind,
                    kept: first.id,
                    duplicate: second.id,
                    startDifferenceMinutes: Int(difference / 60)
                ))
            }
        }
        return proposals
    }

    // MARK: - Revision conflicts

    static func revisionConflicts(in events: [LoggedEvent]) -> [RevisionConflict] {
        var byTarget: [EventID: [LoggedEvent]] = [:]
        for event in events {
            guard let target = event.supersedes else { continue }
            byTarget[target, default: []].append(event)
        }

        var conflicts: [RevisionConflict] = []
        for (target, revisions) in byTarget where revisions.count > 1 {
            guard let winner = revisions.max(by: LedgerProjection.isOutranked) else { continue }
            for revision in revisions where revision.id != winner.id {
                conflicts.append(RevisionConflict(target: target, winner: winner.id, loser: revision.id))
            }
        }
        return conflicts.sorted { lhs, rhs in
            if lhs.target != rhs.target { return lhs.target.rawValue.uuidString < rhs.target.rawValue.uuidString }
            return lhs.loser.rawValue.uuidString < rhs.loser.rawValue.uuidString
        }
    }
}
