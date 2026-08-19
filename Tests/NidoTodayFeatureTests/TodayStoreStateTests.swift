import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoPersistence
@testable import NidoRoutineEngine
@testable import NidoTodayFeature

/// A client that closes and reopens has to be able to hand the store back what it was holding.
///
/// Events already survive, because they live in the ledger. Decisions did not: a delay lived only in
/// the store, so closing the app quietly undid something the caregiver had chosen. These tests fix
/// both halves of that seam — what goes back in, and what can be read back out.
final class TodayStoreStateTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "America/Vancouver")!
    private let day = LocalDate(year: 2026, month: 8, day: 17)
    private let household = HouseholdID()
    private let lunch = RuleID()

    private func at(_ hour: Int, _ minute: Int) -> Date {
        DayClock(day: day, timeZone: timeZone).instant(WallClock(hour: hour, minute: minute))
    }

    private func template() -> RoutineTemplate {
        RoutineTemplate(id: RoutineTemplateID(), version: 1, rules: [
            RoutineRule(
                id: lunch,
                name: "Comida",
                category: .feeding,
                timing: .anchor(earliest: WallClock(hour: 11, minute: 45), preferred: WallClock(hour: 12, minute: 0), latest: WallClock(hour: 12, minute: 45)),
                priority: .p1AnchorExternalCommitment,
                duration: DurationRange(expectedMinutes: 40)
            )
        ])
    }

    private func makeStore(overrides: [ManualOverride] = [], events: [LoggedEvent] = []) -> TodayStore {
        TodayStore(
            store: InMemoryEventStore(events: events),
            template: template(),
            household: household,
            operationalDay: OperationalDayID(anchorDate: day),
            timeZone: timeZone,
            overrides: overrides
        )
    }

    func testADelaySurvivesBeingHandedBackToANewStore() async throws {
        let first = makeStore()
        try await first.perform(.delay(lunch, minutes: 20), now: at(11, 50))
        let carried = await first.currentOverrides()
        XCTAssertEqual(carried.count, 1)

        let reopened = makeStore(overrides: carried)
        let plan = try await reopened.resolve(now: at(11, 50)).plan
        let occurrence = try XCTUnwrap(plan.occurrences.first { $0.ruleID == lunch })
        XCTAssertEqual(occurrence.resolvedTiming.preferred, at(12, 20))
    }

    func testTheLedgerCanBeReadBackOutForStorage() async throws {
        let store = makeStore()
        let before = try await store.currentEvents()
        XCTAssertTrue(before.isEmpty)

        try await store.perform(.startMeal(lunch), now: at(12, 2))
        let events = try await store.currentEvents()

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.ruleID, lunch)
    }

    func testAStoreWithNothingHandedBackBehavesExactlyAsBefore() async throws {
        let plan = try await makeStore().resolve(now: at(11, 50)).plan
        let occurrence = try XCTUnwrap(plan.occurrences.first { $0.ruleID == lunch })
        XCTAssertEqual(occurrence.resolvedTiming.preferred, at(12, 0))
    }
}
