import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

/// The command layer: the only supported way to record reality.
final class EventLedgerTests: XCTestCase {
    private let fixture = DayFixture()
    private let household = HouseholdID()

    // MARK: - Sessions

    func testStartAndEndSharePairedSessionIdentity() throws {
        let nap = RuleID()
        var ledger = EventLedger()
        let start = try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(10, 44))
        let end = try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(11, 31), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(11, 31))

        let session = try XCTUnwrap(start.first?.logicalSessionID)
        XCTAssertEqual(end.first?.logicalSessionID, session, "a nap is one logical session across two taps")
        XCTAssertNil(ledger.openSession(kind: .sleep, ruleID: nap), "and it is closed afterwards")
    }

    func testEndingSomethingThatNeverStartedIsRejected() {
        var ledger = EventLedger()
        XCTAssertThrowsError(try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(11, 31), source: .watch, ruleID: RuleID(), sleepType: .nap1), now: fixture.at(11, 31))) { error in
            XCTAssertEqual(error as? CommandError, .noActiveSession(.sleep))
        }
    }

    func testStartingTwiceIsRejected() throws {
        let nap = RuleID()
        var ledger = EventLedger()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(10, 44))

        XCTAssertThrowsError(try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 50), source: .app, ruleID: nap, sleepType: .nap1), now: fixture.at(10, 50))) { error in
            XCTAssertEqual(error as? CommandError, .alreadyActive(.sleep))
        }
    }

    func testEndingBeforeTheStartIsRejected() throws {
        let nap = RuleID()
        var ledger = EventLedger()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(10, 44))

        XCTAssertThrowsError(try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(10, 20), source: .app, ruleID: nap, sleepType: .nap1), now: fixture.at(11, 0))) { error in
            XCTAssertEqual(error as? CommandError, .endBeforeStart)
        }
    }

    func testTheFutureCannotBeLogged() {
        var ledger = EventLedger()
        XCTAssertThrowsError(try ledger.apply(LogDiaperCommand(householdID: household, occurredAt: fixture.at(15, 0), source: .app), now: fixture.at(12, 0))) { error in
            XCTAssertEqual(error as? CommandError, .futureTimestamp)
        }
    }

    func testAFewMinutesOfClockDriftIsTolerated() throws {
        var ledger = EventLedger()
        let events = try ledger.apply(LogDiaperCommand(householdID: household, occurredAt: fixture.at(12, 2), source: .watch), now: fixture.at(12, 0))
        XCTAssertEqual(events.count, 1, "a watch a couple of minutes ahead is not an error")
    }

    // MARK: - Idempotency

    func testRetryingTheSameCommandDoesNotRecordItTwice() throws {
        let nap = RuleID()
        let command = StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1)
        var ledger = EventLedger()

        let first = try ledger.apply(command, now: fixture.at(10, 44))
        let retried = try ledger.apply(command, now: fixture.at(10, 45))

        XCTAssertEqual(ledger.events.count, 1, "a retried tap must not open a second nap")
        XCTAssertEqual(first, retried, "the retry returns what the first attempt recorded")
    }

    func testTwoGenuinelySeparateActivitiesAreBothRecorded() throws {
        let nap = RuleID()
        var ledger = EventLedger()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(10, 44))
        try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(11, 31), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(11, 31))
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(15, 1), source: .watch, ruleID: nap, sleepType: .nap2), now: fixture.at(15, 1))

        XCTAssertEqual(ledger.events.count, 3, "deduplication is by command identity, not by resemblance")
    }

    // MARK: - Corrections

    func testCorrectingATimeAppendsARevisionAndKeepsHistory() throws {
        let nap = RuleID()
        var ledger = EventLedger()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(10, 44))
        let end = try XCTUnwrap(try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(11, 31), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(11, 31)).first)

        let corrected = try XCTUnwrap(try ledger.apply(CorrectEventTimeCommand(householdID: household, correctedTo: fixture.at(11, 20), source: .app, target: end.id), now: fixture.at(11, 40)).first)

        XCTAssertEqual(ledger.events.count, 3, "the original is retained: history is never rewritten")
        XCTAssertEqual(corrected.supersedes, end.id)
        XCTAssertEqual(corrected.revision, end.revision + 1)
        XCTAssertEqual(corrected.logicalSessionID, end.logicalSessionID, "still the same nap")

        let effective = ledger.effectiveEvents
        XCTAssertEqual(effective.count, 2, "but only the current revision describes reality")
        XCTAssertFalse(effective.contains { $0.id == end.id })
    }

    func testCorrectingAnEndToBeforeItsStartIsRejected() throws {
        let nap = RuleID()
        var ledger = EventLedger()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(10, 44))
        let end = try XCTUnwrap(try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(11, 31), source: .watch, ruleID: nap, sleepType: .nap1), now: fixture.at(11, 31)).first)

        XCTAssertThrowsError(try ledger.apply(CorrectEventTimeCommand(householdID: household, correctedTo: fixture.at(9, 0), source: .app, target: end.id), now: fixture.at(11, 40))) { error in
            XCTAssertEqual(error as? CommandError, .endBeforeStart)
        }
    }

    func testCorrectingAnUnknownEventIsRejected() {
        var ledger = EventLedger()
        let missing = EventID()
        XCTAssertThrowsError(try ledger.apply(CorrectEventTimeCommand(householdID: household, correctedTo: fixture.at(11, 20), source: .app, target: missing), now: fixture.at(11, 40))) { error in
            XCTAssertEqual(error as? CommandError, .unknownEvent(missing))
        }
    }

    // MARK: - Payload integrity

    func testEveryCommandProducesAConsistentPayload() throws {
        var ledger = EventLedger()
        let now = fixture.at(12, 0)
        let commands: [any LoggedEventCommand] = [
            RecordWakeCommand(householdID: household, occurredAt: fixture.at(7, 4), source: .app),
            RateMealCommand(householdID: household, occurredAt: fixture.at(7, 45), source: .app, rating: .small),
            LogWaterCommand(householdID: household, occurredAt: fixture.at(9, 0), source: .app),
            LogDiaperCommand(householdID: household, occurredAt: fixture.at(9, 5), source: .app),
            RecordWeightCommand(householdID: household, occurredAt: fixture.at(9, 10), source: .app, kilograms: 11.4),
            RecordHealthNoteCommand(householdID: household, occurredAt: fixture.at(9, 15), source: .app, text: "slight cough"),
            ChangeDayModeCommand(householdID: household, occurredAt: fixture.at(9, 20), source: .app, mode: .chaos)
        ]
        for command in commands { try ledger.apply(command, now: now) }

        XCTAssertEqual(ledger.events.count, commands.count)
        for event in ledger.events {
            XCTAssertTrue(event.hasConsistentPayload, "\(event.type) produced a mismatched payload")
            XCTAssertNotNil(event.commandID, "every recorded event traces back to a command")
        }
    }

    func testNursingRecordsWhetherItWasPlanned() throws {
        var ledger = EventLedger()
        let events = try ledger.apply(StartNursingCommand(householdID: household, occurredAt: fixture.at(14, 0), source: .app, context: .comfort, planned: false), now: fixture.at(14, 0))
        guard case .breastfeed(let context, let planned) = try XCTUnwrap(events.first).payload else {
            return XCTFail("nursing must carry its context")
        }
        XCTAssertEqual(context, .comfort)
        XCTAssertFalse(planned, "structured versus on-demand is the distinction the care plan depends on")
    }

    // MARK: - DO → LOG → RECALCULATE

    func testLoggingRealityThroughCommandsMovesTheRestOfTheDay() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            fixture.windowRule(nap1, "Nap 1", earliest: (10, 5), preferred: (10, 20), latest: (10, 40), priority: .p2ImportantRoutine, minutes: 45),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let engine = RoutineEngine()

        let planned = try engine.resolve(fixture.input(rules: rules, now: fixture.at(8, 0)))
        let plannedNap2 = try XCTUnwrap(planned.occurrence(nap2)).resolvedTiming.preferred

        var ledger = EventLedger()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(10, 44), source: .watch, ruleID: nap1, sleepType: .nap1), now: fixture.at(10, 44))
        let end = try XCTUnwrap(try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(11, 31), source: .watch, ruleID: nap1, sleepType: .nap1), now: fixture.at(11, 31)).first)

        let afterLogging = try engine.resolve(fixture.input(rules: rules, events: ledger.effectiveEvents, previousPlan: planned.plan, now: fixture.at(11, 31)))
        let resolvedNap2 = try XCTUnwrap(afterLogging.occurrence(nap2)).resolvedTiming.preferred

        XCTAssertNotEqual(resolvedNap2, plannedNap2, "logging reality must move the rest of the day")
        XCTAssertEqual(resolvedNap2.timeIntervalSince(fixture.at(11, 31)), 210 * 60)
        XCTAssertEqual(try XCTUnwrap(afterLogging.occurrence(nap1)).status, .completed)

        // The caregiver corrects the wake time by eleven minutes; the day follows.
        try ledger.apply(CorrectEventTimeCommand(householdID: household, correctedTo: fixture.at(11, 20), source: .app, target: end.id), now: fixture.at(11, 40))
        let afterCorrection = try engine.resolve(fixture.input(rules: rules, events: ledger.effectiveEvents, previousPlan: afterLogging.plan, now: fixture.at(11, 40)))

        XCTAssertEqual(try XCTUnwrap(afterCorrection.occurrence(nap2)).resolvedTiming.preferred.timeIntervalSince(fixture.at(11, 20)), 210 * 60, "the correction, not the original, drives the plan")
    }
}
