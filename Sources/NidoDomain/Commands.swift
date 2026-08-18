import Foundation

/// The only supported way to record something that happened.
///
/// `LoggedEvent`'s initialiser is internal on purpose: a feature, a widget or a Siri intent cannot
/// hand-assemble an event with a mismatched payload or an unpaired session. It states its intent as a
/// command, the domain validates it, and the ledger decides what gets written.
public protocol LoggedEventCommand: Sendable {
    var commandID: CommandID { get }
    var householdID: HouseholdID { get }
    var personID: PersonID? { get }
    var occurredAt: Date { get }
    var source: EventSource { get }
    var createdBy: PersonID? { get }
    func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent]
}

extension LoggedEventCommand {
    func makeEvent(
        type: EventType,
        at startedAt: Date,
        now: Date,
        session: SessionID? = nil,
        payload: EventPayload = .none,
        ruleID: RuleID? = nil,
        revision: Int = 1,
        supersedes: EventID? = nil
    ) -> LoggedEvent {
        LoggedEvent(
            householdID: householdID,
            personID: personID,
            logicalSessionID: session,
            type: type,
            startedAt: startedAt,
            source: source,
            createdBy: createdBy,
            createdAt: now,
            modifiedAt: now,
            revision: revision,
            payload: payload,
            ruleID: ruleID,
            commandID: commandID,
            supersedes: supersedes
        )
    }
}

// MARK: - Sleep

public struct StartSleepCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?
    public let sleepType: SleepType
    public let assistance: SleepAssistance?

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil, sleepType: SleepType = .other, assistance: SleepAssistance? = nil) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
        self.sleepType = sleepType
        self.assistance = assistance
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        guard ledger.openSession(kind: .sleep, ruleID: ruleID) == nil else {
            throw CommandError.alreadyActive(.sleep)
        }
        let type: EventType = sleepType == .night ? .nightSleepStarted : .napStarted
        return [makeEvent(type: type, at: occurredAt, now: now, session: SessionID(), payload: .sleep(type: sleepType, assistance: assistance), ruleID: ruleID)]
    }
}

public struct EndSleepCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?
    public let sleepType: SleepType

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil, sleepType: SleepType = .other) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
        self.sleepType = sleepType
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        guard let open = ledger.openSession(kind: .sleep, ruleID: ruleID) else {
            throw CommandError.noActiveSession(.sleep)
        }
        guard occurredAt >= open.startedAt else { throw CommandError.endBeforeStart }
        let type: EventType = sleepType == .night ? .nightSleepEnded : .napEnded
        return [makeEvent(type: type, at: occurredAt, now: now, session: open.session, payload: .sleep(type: sleepType, assistance: nil), ruleID: ruleID)]
    }
}

/// A wake is instantaneous: it opens and closes its own occurrence.
public struct RecordWakeCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        [makeEvent(type: .childWoke, at: occurredAt, now: now, ruleID: ruleID)]
    }
}

// MARK: - Feeding

public struct StartMealCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        guard ledger.openSession(kind: .meal, ruleID: ruleID) == nil else {
            throw CommandError.alreadyActive(.meal)
        }
        return [makeEvent(type: .mealStarted, at: occurredAt, now: now, session: SessionID(), ruleID: ruleID)]
    }
}

public struct EndMealCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        guard let open = ledger.openSession(kind: .meal, ruleID: ruleID) else {
            throw CommandError.noActiveSession(.meal)
        }
        guard occurredAt >= open.startedAt else { throw CommandError.endBeforeStart }
        return [makeEvent(type: .mealEnded, at: occurredAt, now: now, session: open.session, ruleID: ruleID)]
    }
}

/// Rating does not require a logged start. Asking a caregiver to open a meal before they are allowed
/// to say how it went would be exactly the kind of bookkeeping this product refuses to create.
public struct RateMealCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?
    public let rating: MealRating
    public let foods: [String]
    public let behaviors: [MealBehavior]
    public let notes: String?

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil, rating: MealRating, foods: [String] = [], behaviors: [MealBehavior] = [], notes: String? = nil) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
        self.rating = rating
        self.foods = foods
        self.behaviors = behaviors
        self.notes = notes
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        [makeEvent(type: .mealRated, at: occurredAt, now: now, payload: .mealRated(rating: rating, foods: foods, behaviors: behaviors, notes: notes), ruleID: ruleID)]
    }
}

public struct StartNursingCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?
    public let context: BreastfeedContext
    public let planned: Bool

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil, context: BreastfeedContext, planned: Bool) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
        self.context = context
        self.planned = planned
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        guard ledger.openSession(kind: .nursing, ruleID: ruleID) == nil else {
            throw CommandError.alreadyActive(.nursing)
        }
        return [makeEvent(type: .breastfeedStarted, at: occurredAt, now: now, session: SessionID(), payload: .breastfeed(context: context, planned: planned), ruleID: ruleID)]
    }
}

public struct EndNursingCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let ruleID: RuleID?
    public let context: BreastfeedContext
    public let planned: Bool

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, ruleID: RuleID? = nil, context: BreastfeedContext, planned: Bool) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.ruleID = ruleID
        self.context = context
        self.planned = planned
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        guard let open = ledger.openSession(kind: .nursing, ruleID: ruleID) else {
            throw CommandError.noActiveSession(.nursing)
        }
        guard occurredAt >= open.startedAt else { throw CommandError.endBeforeStart }
        return [makeEvent(type: .breastfeedEnded, at: occurredAt, now: now, session: open.session, payload: .breastfeed(context: context, planned: planned), ruleID: ruleID)]
    }
}

// MARK: - Quick log

public struct LogDiaperCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        [makeEvent(type: .diaperChanged, at: occurredAt, now: now)]
    }
}

public struct LogWaterCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        [makeEvent(type: .waterLogged, at: occurredAt, now: now)]
    }
}

public struct RecordWeightCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let kilograms: Double

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, kilograms: Double) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.kilograms = kilograms
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        [makeEvent(type: .weightRecorded, at: occurredAt, now: now, payload: .weight(kilograms: kilograms))]
    }
}

public struct RecordHealthNoteCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let text: String

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, text: String) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.text = text
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        [makeEvent(type: .healthNoteRecorded, at: occurredAt, now: now, payload: .healthNote(text: text))]
    }
}

public struct ChangeDayModeCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let mode: DayMode

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, mode: DayMode) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.mode = mode
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        [makeEvent(type: .modeChanged, at: occurredAt, now: now, payload: .mode(mode))]
    }
}

// MARK: - Correction

/// Corrects when something happened without destroying what was recorded before.
///
/// The correction is a new revision that supersedes the original. Both remain in the ledger, which is
/// what lets a second caregiver's device reconcile and what keeps history honest.
public struct CorrectEventTimeCommand: LoggedEventCommand {
    public let commandID: CommandID
    public let householdID: HouseholdID
    public let personID: PersonID?
    public let occurredAt: Date
    public let source: EventSource
    public let createdBy: PersonID?
    public let target: EventID

    public init(commandID: CommandID = CommandID(), householdID: HouseholdID, personID: PersonID? = nil, correctedTo occurredAt: Date, source: EventSource, createdBy: PersonID? = nil, target: EventID) {
        self.commandID = commandID
        self.householdID = householdID
        self.personID = personID
        self.occurredAt = occurredAt
        self.source = source
        self.createdBy = createdBy
        self.target = target
    }

    public func events(in ledger: EventLedger, now: Date) throws -> [LoggedEvent] {
        guard let original = ledger.event(id: target) else { throw CommandError.unknownEvent(target) }
        if original.type.closesSession, let session = original.logicalSessionID {
            let start = ledger.effectiveEvents.first { $0.logicalSessionID == session && $0.type.opensSession }
            if let start, occurredAt < start.startedAt { throw CommandError.endBeforeStart }
        }
        return [makeEvent(
            type: original.type,
            at: occurredAt,
            now: now,
            session: original.logicalSessionID,
            payload: original.payload,
            ruleID: original.ruleID,
            revision: original.revision + 1,
            supersedes: original.id
        )]
    }
}
