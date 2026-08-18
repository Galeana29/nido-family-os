import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoPersistence

/// The contract every `EventStore` must satisfy, written once.
///
/// When SwiftData or SQLite arrives, its test case subclasses this and overrides `makeStore()`. If it
/// passes, ADR 0011 can be decided on evidence rather than on which framework sounds nicer. The base
/// class skips itself, since it has no store of its own.
class EventStoreConformanceTests: XCTestCase {
    var store: (any EventStore)!
    let household = HouseholdID()
    let day = DayFixture()

    /// Subclasses return the implementation under test.
    func makeStore() -> (any EventStore)? { nil }

    override func setUp() async throws {
        try await super.setUp()
        guard let store = makeStore() else {
            throw XCTSkip("abstract conformance suite; subclass and override makeStore()")
        }
        self.store = store
    }

    // MARK: - Recording

    func testAppendedEventsCanBeReadBack() async throws {
        let events = try await store.apply(RecordWakeCommand(householdID: household, occurredAt: day.at(7, 4), source: .app), now: day.at(7, 4))
        let stored = try await store.allEvents()

        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, events.first?.id)
        XCTAssertEqual(try await store.event(id: XCTUnwrap(events.first).id)?.type, .childWoke)
    }

    func testAppendingTheSameEventTwiceStoresItOnce() async throws {
        let events = try await store.apply(RecordWakeCommand(householdID: household, occurredAt: day.at(7, 4), source: .app), now: day.at(7, 4))
        try await store.append(events)
        try await store.append(events)

        XCTAssertEqual(try await store.allEvents().count, 1)
    }

    func testARetriedCommandDoesNotRecordTwice() async throws {
        let command = LogDiaperCommand(householdID: household, occurredAt: day.at(9, 0), source: .watch)
        try await store.apply(command, now: day.at(9, 0))
        try await store.apply(command, now: day.at(9, 1))

        XCTAssertEqual(try await store.allEvents().count, 1, "the same tap delivered twice is one event")
    }

    func testEventsCanBeQueriedByInterval() async throws {
        try await store.apply(RecordWakeCommand(householdID: household, occurredAt: day.at(7, 4), source: .app), now: day.at(7, 4))
        try await store.apply(LogDiaperCommand(householdID: household, occurredAt: day.at(15, 0), source: .app), now: day.at(15, 0))

        let morning = try await store.events(in: DateInterval(start: day.at(6, 0), end: day.at(12, 0)))
        XCTAssertEqual(morning.count, 1)
        XCTAssertEqual(morning.first?.type, .childWoke)
    }

    func testEventsComeBackInCanonicalOrder() async throws {
        try await store.apply(LogDiaperCommand(householdID: household, occurredAt: day.at(15, 0), source: .app), now: day.at(15, 0))
        try await store.apply(RecordWakeCommand(householdID: household, occurredAt: day.at(7, 4), source: .app), now: day.at(15, 0))

        let stored = try await store.allEvents()
        XCTAssertEqual(stored.map(\.type), [.childWoke, .diaperChanged], "storage order must not leak into the day")
    }

    // MARK: - Sessions and projection

    func testLedgerSeesTheCurrentRevisionOnly() async throws {
        let nap = RuleID()
        try await store.apply(StartSleepCommand(householdID: household, occurredAt: day.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: day.at(10, 44))
        let end = try await XCTUnwrap(store.apply(EndSleepCommand(householdID: household, occurredAt: day.at(11, 31), source: .watch, ruleID: nap, sleepType: .nap1), now: day.at(11, 31)).first)
        try await store.apply(CorrectEventTimeCommand(householdID: household, correctedTo: day.at(11, 20), source: .app, target: end.id), now: day.at(11, 40))

        let ledger = try await store.ledger()
        XCTAssertEqual(try await store.allEvents().count, 3, "history is kept")
        XCTAssertEqual(ledger.effectiveEvents.count, 2, "but only the current revision stands")
        XCTAssertEqual(ledger.effectiveEvents.last?.startedAt, day.at(11, 20))
    }

    func testDeletingLeavesATombstoneRatherThanAHole() async throws {
        let logged = try await XCTUnwrap(store.apply(LogWaterCommand(householdID: household, occurredAt: day.at(9, 0), source: .app), now: day.at(9, 0)).first)
        try await store.apply(DeleteEventCommand(householdID: household, occurredAt: day.at(9, 5), source: .app, target: logged.id), now: day.at(9, 5))

        XCTAssertEqual(try await store.allEvents().count, 2, "the tombstone is a revision, not an erasure")
        XCTAssertTrue(try await store.ledger().effectiveEvents.isEmpty, "and nothing stands afterwards")
    }

    // MARK: - Outbox

    func testLocallyRecordedEventsAreQueuedForUpload() async throws {
        let events = try await store.apply(RecordWakeCommand(householdID: household, occurredAt: day.at(7, 4), source: .app), now: day.at(7, 4))
        let pending = try await store.pendingUploads()

        XCTAssertEqual(pending.map(\.id), events.map(\.id))
    }

    func testUploadedEventsLeaveTheOutbox() async throws {
        let events = try await store.apply(RecordWakeCommand(householdID: household, occurredAt: day.at(7, 4), source: .app), now: day.at(7, 4))
        try await store.markUploaded(events.map(\.id))

        XCTAssertTrue(try await store.pendingUploads().isEmpty)
        XCTAssertEqual(try await store.allEvents().count, 1, "leaving the outbox does not leave the ledger")
    }

    func testEventsArrivingFromElsewhereAreNotQueuedForUpload() async throws {
        let remote = try makeRemoteEvents()
        try await store.receive(remote)

        XCTAssertEqual(try await store.allEvents().count, remote.count)
        XCTAssertTrue(try await store.pendingUploads().isEmpty, "the cloud already has what the cloud sent us")
    }

    // MARK: - Merging

    func testReceivingIsIdempotent() async throws {
        let remote = try makeRemoteEvents()
        try await store.receive(remote)
        let second = try await store.receive(remote)

        XCTAssertEqual(try await store.allEvents().count, remote.count)
        XCTAssertTrue(second.added.isEmpty, "a repeated sync adds nothing")
    }

    func testMergingKeepsBothSidesOfADisconnection() async throws {
        try await store.apply(LogDiaperCommand(householdID: household, occurredAt: day.at(9, 0), source: .app), now: day.at(9, 0))
        let remote = try makeRemoteEvents()
        let report = try await store.receive(remote)

        XCTAssertEqual(report.added.count, remote.count)
        XCTAssertEqual(try await store.allEvents().count, remote.count + 1, "an offline device is not wrong")
    }

    /// Events produced by "the other device": a separate ledger, so its ids and sessions are its own.
    private func makeRemoteEvents() throws -> [LoggedEvent] {
        var ledger = EventLedger()
        let nap = RuleID()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: day.at(10, 44), source: .watch, ruleID: nap, sleepType: .nap1), now: day.at(10, 44))
        try ledger.apply(EndSleepCommand(householdID: household, occurredAt: day.at(11, 31), source: .watch, ruleID: nap, sleepType: .nap1), now: day.at(11, 31))
        return ledger.events
    }
}

/// The in-memory store must satisfy the same contract as any database we later choose.
final class InMemoryEventStoreTests: EventStoreConformanceTests {
    override func makeStore() -> (any EventStore)? { InMemoryEventStore() }
}

/// Minimal date helper, kept local so the persistence tests do not depend on the engine test target.
struct DayFixture {
    let timeZone = TimeZone(identifier: "America/Vancouver")!
    let day = LocalDate(year: 2026, month: 8, day: 17)

    func at(_ hour: Int, _ minute: Int) -> Date {
        DayClock(day: day, timeZone: timeZone).instant(WallClock(hour: hour, minute: minute))
    }
}
