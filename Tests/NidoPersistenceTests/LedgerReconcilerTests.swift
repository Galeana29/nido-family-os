import XCTest
import Foundation
@testable import NidoDomain

/// Two caregivers, two devices, one afternoon. The reconciler decides what the merged ledger contains
/// and, more importantly, what it refuses to decide on its own.
final class LedgerReconcilerTests: XCTestCase {
    private let fixture = DayFixture()
    private let household = HouseholdID()

    private func ledgerWithNap(start: (Int, Int), end: (Int, Int)?, rule: RuleID?, source: EventSource) throws -> EventLedger {
        var ledger = EventLedger()
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(start.0, start.1), source: source, ruleID: rule, sleepType: .nap1), now: fixture.at(start.0, start.1))
        if let end {
            try ledger.apply(EndSleepCommand(householdID: household, occurredAt: fixture.at(end.0, end.1), source: source, ruleID: rule, sleepType: .nap1), now: fixture.at(end.0, end.1))
        }
        return ledger
    }

    // MARK: - Union

    func testMergeKeepsEverythingFromBothSides() throws {
        let nap = RuleID()
        let local = try ledgerWithNap(start: (10, 44), end: (11, 31), rule: nap, source: .watch)
        var remoteLedger = EventLedger()
        try remoteLedger.apply(LogDiaperCommand(householdID: household, occurredAt: fixture.at(12, 0), source: .app), now: fixture.at(12, 0))

        let report = LedgerReconciler.merge(local.events, remoteLedger.events)
        XCTAssertEqual(report.events.count, 3)
        XCTAssertEqual(report.added.count, 1)
    }

    func testMergeIsCommutative() throws {
        let nap = RuleID()
        let local = try ledgerWithNap(start: (10, 44), end: (11, 31), rule: nap, source: .watch)
        let remote = try ledgerWithNap(start: (15, 1), end: (15, 34), rule: RuleID(), source: .app)

        let forward = LedgerReconciler.merge(local.events, remote.events)
        let backward = LedgerReconciler.merge(remote.events, local.events)
        XCTAssertEqual(forward.events, backward.events, "which device syncs first must not change the result")
    }

    func testMergeIsIdempotent() throws {
        let local = try ledgerWithNap(start: (10, 44), end: (11, 31), rule: RuleID(), source: .watch)
        let remote = try ledgerWithNap(start: (15, 1), end: (15, 34), rule: RuleID(), source: .app)

        let once = LedgerReconciler.merge(local.events, remote.events)
        let twice = LedgerReconciler.merge(once.events, remote.events)
        XCTAssertEqual(once.events, twice.events)
        XCTAssertTrue(twice.added.isEmpty)
    }

    // MARK: - Duplicate sessions

    func testNearIdenticalNapsAreProposedAsDuplicatesRatherThanMerged() throws {
        let nap = RuleID()
        let mine = try ledgerWithNap(start: (10, 43), end: (11, 31), rule: nap, source: .watch)
        let theirs = try ledgerWithNap(start: (10, 45), end: (11, 30), rule: nap, source: .app)

        let report = LedgerReconciler.merge(mine.events, theirs.events)
        XCTAssertEqual(report.duplicateSessions.count, 1)
        XCTAssertEqual(report.duplicateSessions.first?.startDifferenceMinutes, 2)
        XCTAssertEqual(report.events.count, 4, "both accounts survive; the system only suggests")
    }

    func testGenuinelyDifferentNapsAreNotProposed() throws {
        let nap = RuleID()
        let morning = try ledgerWithNap(start: (10, 44), end: (11, 31), rule: nap, source: .watch)
        let afternoon = try ledgerWithNap(start: (15, 1), end: (15, 34), rule: nap, source: .app)

        let report = LedgerReconciler.merge(morning.events, afternoon.events)
        XCTAssertTrue(report.duplicateSessions.isEmpty, "two naps in one day are normal")
    }

    func testLargeDiscrepanciesAreNeverProposed() throws {
        let nap = RuleID()
        let mine = try ledgerWithNap(start: (10, 44), end: (12, 30), rule: nap, source: .watch)
        let theirs = try ledgerWithNap(start: (11, 10), end: (12, 20), rule: nap, source: .app)

        let report = LedgerReconciler.merge(mine.events, theirs.events)
        XCTAssertTrue(report.duplicateSessions.isEmpty, "26 minutes apart is a disagreement about reality, not a duplicate tap")
    }

    func testDifferentActivitiesAreNeverProposedAsDuplicates() throws {
        let rule = RuleID()
        var mine = EventLedger()
        try mine.apply(StartSleepCommand(householdID: household, occurredAt: fixture.at(12, 0), source: .app, ruleID: rule, sleepType: .nap1), now: fixture.at(12, 0))
        var theirs = EventLedger()
        try theirs.apply(StartMealCommand(householdID: household, occurredAt: fixture.at(12, 2), source: .app, ruleID: rule), now: fixture.at(12, 2))

        let report = LedgerReconciler.merge(mine.events, theirs.events)
        XCTAssertTrue(report.duplicateSessions.isEmpty)
    }

    // MARK: - Concurrent corrections

    func testConcurrentCorrectionsResolveToExactlyOneCurrentRevision() throws {
        let nap = RuleID()
        var base = try ledgerWithNap(start: (10, 44), end: (11, 31), rule: nap, source: .watch)
        let end = try XCTUnwrap(base.effectiveEvents.last)

        var mine = base
        try mine.apply(CorrectEventTimeCommand(householdID: household, correctedTo: fixture.at(11, 20), source: .app, target: end.id), now: fixture.at(11, 40))
        var theirs = base
        try theirs.apply(CorrectEventTimeCommand(householdID: household, correctedTo: fixture.at(11, 25), source: .watch, target: end.id), now: fixture.at(11, 45))

        let report = LedgerReconciler.merge(mine.events, theirs.events)
        XCTAssertEqual(report.revisionConflicts.count, 1, "the disagreement is reported")

        let effective = LedgerProjection.effective(report.events)
        let endings = effective.filter { $0.type == .napEnded }
        XCTAssertEqual(endings.count, 1, "but the day has exactly one wake time")
        XCTAssertEqual(endings.first?.startedAt, fixture.at(11, 25), "the later edit wins, deterministically")

        // Both devices reach the same answer without talking to each other.
        let mirrored = LedgerReconciler.merge(theirs.events, mine.events)
        XCTAssertEqual(LedgerProjection.effective(mirrored.events), effective)
        _ = base
    }

    // MARK: - Properties

    func testMergingRandomLedgersNeverLosesOrInventsEvents() throws {
        var generator = SeededGenerator(seed: 0x5417_2026)

        for iteration in 0..<500 {
            let local = try randomLedger(using: &generator)
            let remote = try randomLedger(using: &generator)
            let report = LedgerReconciler.merge(local.events, remote.events)

            let expected = Set(local.events.map(\.id)).union(remote.events.map(\.id))
            XCTAssertEqual(Set(report.events.map(\.id)), expected, "iteration \(iteration)")
            XCTAssertEqual(report.events.count, expected.count, "no duplicates, iteration \(iteration)")
        }
    }

    func testMergingRandomLedgersAlwaysLeavesOneCurrentRevisionPerCorrection() throws {
        var generator = SeededGenerator(seed: 0x5417_2027)

        for iteration in 0..<500 {
            let local = try randomLedger(using: &generator)
            let remote = try randomLedger(using: &generator)
            let effective = LedgerProjection.effective(LedgerReconciler.merge(local.events, remote.events).events)

            let ids = Set(effective.map(\.id))
            for event in effective {
                if let supersedes = event.supersedes {
                    XCTAssertFalse(ids.contains(supersedes), "a superseded revision still stands, iteration \(iteration)")
                }
            }
            XCTAssertEqual(ids.count, effective.count, "iteration \(iteration)")
        }
    }

    private func randomLedger(using generator: inout SeededGenerator) throws -> EventLedger {
        var ledger = EventLedger()
        let rule = Bool.random(using: &generator) ? RuleID() : nil
        let start = Int.random(in: 600...700, using: &generator)
        let startDate = fixture.at(start / 60, start % 60)
        try ledger.apply(StartSleepCommand(householdID: household, occurredAt: startDate, source: .watch, ruleID: rule, sleepType: .nap1), now: startDate)

        if Bool.random(using: &generator) {
            let endDate = startDate.addingTimeInterval(TimeInterval(Int.random(in: 20...120, using: &generator) * 60))
            let end = try ledger.apply(EndSleepCommand(householdID: household, occurredAt: endDate, source: .watch, ruleID: rule, sleepType: .nap1), now: endDate)
            if Bool.random(using: &generator), let target = end.first {
                let corrected = endDate.addingTimeInterval(TimeInterval(Int.random(in: -10...10, using: &generator) * 60))
                if corrected >= startDate {
                    try ledger.apply(CorrectEventTimeCommand(householdID: household, correctedTo: corrected, source: .app, target: target.id), now: endDate.addingTimeInterval(600))
                }
            }
        }
        if Bool.random(using: &generator) {
            let at = fixture.at(Int.random(in: 12...20, using: &generator), 0)
            try ledger.apply(LogDiaperCommand(householdID: household, occurredAt: at, source: .app), now: at)
        }
        return ledger
    }
}

/// SplitMix64, seeded so a failing merge replays exactly.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
