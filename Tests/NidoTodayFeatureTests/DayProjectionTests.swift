import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoPersistence
@testable import NidoRoutineEngine
@testable import NidoTodayFeature

/// The whole day, projected for a caregiver who wants to log something that is not the hero.
///
/// The risk this guards is a screen that quietly disagrees with itself: the Now card saying one
/// thing and the list saying another about the same occurrence. They come from one projection here
/// precisely so that cannot happen.
final class DayProjectionTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "America/Vancouver")!
    private let day = LocalDate(year: 2026, month: 8, day: 17)
    private let household = HouseholdID()

    private let breakfast = RuleID()
    private let nap = RuleID()
    private let lunch = RuleID()

    private func at(_ hour: Int, _ minute: Int) -> Date {
        DayClock(day: day, timeZone: timeZone).instant(WallClock(hour: hour, minute: minute))
    }

    private func template() -> RoutineTemplate {
        RoutineTemplate(id: RoutineTemplateID(), version: 1, rules: [
            RoutineRule(id: breakfast, name: "Desayuno", category: .feeding, timing: .anchor(earliest: WallClock(hour: 7, minute: 0), preferred: WallClock(hour: 7, minute: 20), latest: WallClock(hour: 8, minute: 0)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 25)),
            RoutineRule(id: nap, name: "Siesta 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 0), preferred: WallClock(hour: 10, minute: 15), latest: WallClock(hour: 10, minute: 55)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: lunch, name: "Comida", category: .feeding, timing: .anchor(earliest: WallClock(hour: 11, minute: 45), preferred: WallClock(hour: 12, minute: 0), latest: WallClock(hour: 12, minute: 45)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 30)),
        ])
    }

    private func store(events: [LoggedEvent] = []) -> TodayStore {
        TodayStore(
            store: InMemoryEventStore(events: events),
            template: template(),
            household: household,
            operationalDay: OperationalDayID(anchorDate: day),
            timeZone: timeZone
        )
    }

    private func presenter() -> TodayPresenter {
        TodayPresenter(timeZone: timeZone, language: .spanish)
    }

    func testTheDayHoldsEveryStepIncludingWhatIsAlreadyDone() async throws {
        let store = self.store()
        try await store.perform(.startMeal(breakfast), now: at(7, 22))
        try await store.perform(.finishMeal(breakfast), now: at(7, 48))
        let result = try await store.resolve(now: at(10, 30))

        let entries = presenter().day(for: result, template: template(), now: at(10, 30))

        XCTAssertEqual(entries.count, 3)
        let done = try XCTUnwrap(entries.first { $0.ruleID == breakfast })
        XCTAssertTrue(done.isSettled, "a finished meal is settled, and the list still has to show it")
    }

    func testExactlyOneStepIsCurrentAndItIsTheOneTodayLeadsWith() async throws {
        let store = self.store()
        let result = try await store.resolve(now: at(10, 30))
        let now = at(10, 30)

        let entries = presenter().day(for: result, template: template(), now: now)
        let screen = presenter().screen(for: result, template: template(), now: now)

        XCTAssertEqual(entries.filter(\.isCurrent).count, 1)
        XCTAssertEqual(entries.first(where: \.isCurrent)?.ruleID, screen.now?.ruleID)
    }

    func testEveryStepOffersTheSameTapTodayWouldOffer() async throws {
        let result = try await store().resolve(now: at(7, 10))
        let now = at(7, 10)

        let entries = presenter().day(for: result, template: template(), now: now)
        let screen = presenter().screen(for: result, template: template(), now: now)
        let hero = try XCTUnwrap(entries.first(where: \.isCurrent))

        XCTAssertEqual(hero.action, screen.now?.primaryAction)
        XCTAssertEqual(hero.actionLabel, screen.now?.primaryActionLabel)
        // A nap is fallen into, a meal is started. The list must not flatten that into one verb.
        let napEntry = try XCTUnwrap(entries.first { $0.ruleID == nap })
        XCTAssertEqual(napEntry.action, .startSleep(nap))
    }

    func testAStepThatMovedSaysSoWithoutCallingItAFailure() async throws {
        let store = self.store()
        try await store.perform(.delay(lunch, minutes: 30), now: at(11, 30))
        let result = try await store.resolve(now: at(11, 30))

        let entry = try XCTUnwrap(presenter().day(for: result, template: template(), now: at(11, 30)).first { $0.ruleID == lunch })

        XCTAssertTrue(entry.wasAdjusted)
        XCTAssertEqual(entry.time, "12:30")
        XCTAssertFalse(entry.isSettled, "moving something is not finishing it")
    }
}
