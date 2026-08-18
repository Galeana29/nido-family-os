import Foundation

public struct CommandID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public enum ActivityKind: String, Sendable, Codable, Hashable {
    case sleep, meal, nursing
}

public enum CommandError: Error, Equatable {
    /// Ending something the ledger has no record of starting.
    case noActiveSession(ActivityKind)
    /// Starting something that is already running. Two taps on Watch must not open two naps.
    case alreadyActive(ActivityKind)
    case endBeforeStart
    /// Logged further into the future than the tolerance allows. Correcting the past is normal;
    /// recording the future is not.
    case futureTimestamp
    case unknownEvent(EventID)
}

extension EventType {
    var activityKind: ActivityKind? {
        switch self {
        case .napStarted, .napEnded, .nightSleepStarted, .nightSleepEnded: return .sleep
        case .mealStarted, .mealEnded: return .meal
        case .breastfeedStarted, .breastfeedEnded: return .nursing
        default: return nil
        }
    }

    var opensSession: Bool {
        switch self {
        case .napStarted, .nightSleepStarted, .mealStarted, .breastfeedStarted: return true
        default: return false
        }
    }

    var closesSession: Bool {
        switch self {
        case .napEnded, .nightSleepEnded, .mealEnded, .breastfeedEnded: return true
        default: return false
        }
    }
}

struct SessionKey: Hashable {
    let kind: ActivityKind
    let ruleID: RuleID?
}

/// The append-oriented record of what actually happened.
///
/// Events are never edited in place and never deleted outright: a correction appends a new revision
/// that supersedes the old one, and a deletion appends a tombstone. History survives so two devices
/// can reconcile and so a caregiver can see what the app told them at the time.
public struct EventLedger: Sendable, Equatable {
    public private(set) var events: [LoggedEvent]

    public init(events: [LoggedEvent] = []) {
        self.events = events
    }

    /// What actually holds now: corrections applied, tombstoned events removed.
    public var effectiveEvents: [LoggedEvent] {
        let superseded = Set(events.compactMap(\.supersedes))
        return events
            .filter { $0.deletedAt == nil && !superseded.contains($0.id) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    public func event(id: EventID) -> LoggedEvent? {
        events.first { $0.id == id }
    }

    /// The session currently open for an activity, if any.
    public func openSession(kind: ActivityKind, ruleID: RuleID?) -> (session: SessionID, startedAt: Date)? {
        var open: [SessionKey: (SessionID, Date)] = [:]
        for event in effectiveEvents {
            guard let eventKind = event.type.activityKind else { continue }
            let key = SessionKey(kind: eventKind, ruleID: event.ruleID)
            if event.type.opensSession, let session = event.logicalSessionID {
                open[key] = (session, event.startedAt)
            } else if event.type.closesSession {
                open[key] = nil
            }
        }
        return open[SessionKey(kind: kind, ruleID: ruleID)]
    }

    /// How far ahead of `now` a command may claim something happened.
    public static let futureTolerance: TimeInterval = 5 * 60

    /// Applies a command, or returns what it already produced.
    ///
    /// Idempotency is by `commandID`, not by content: a Watch tap retried after a dropped connection
    /// must not create a second nap, while two genuinely separate naps must both be recorded.
    @discardableResult
    public mutating func apply(_ command: any LoggedEventCommand, now: Date) throws -> [LoggedEvent] {
        let alreadyApplied = events.filter { $0.commandID == command.commandID }
        if !alreadyApplied.isEmpty { return alreadyApplied }

        guard command.occurredAt <= now.addingTimeInterval(Self.futureTolerance) else {
            throw CommandError.futureTimestamp
        }

        let produced = try command.events(in: self, now: now)
        events.append(contentsOf: produced)
        return produced
    }
}
