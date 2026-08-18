import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoPersistence
@testable import NidoRoutineEngine
@testable import NidoTodayFeature

/// Today, tested without a screen.
///
/// Everything the caregiver reads is a projection of what the engine already decided, so it can be
/// checked here: the sentence at the top, which card is the hero, which tap it offers, and whether an
/// explanation carries the engine's own numbers rather than invented ones.
final class TodayPresenterTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "America/Vancouver")!
    private let day = LocalDate(year: 2026, month: 8, day: 17)
    private let household = HouseholdID()

    private func at(_ hour: Int, _ minute: Int) -> Date {
        DayClock(day: day, timeZone: timeZone).instant(WallClock(hour: hour, minute: minute))
    }

    private let nap1 = RuleID()
    private let nap2 = RuleID()
    private let lunch = RuleID()

    private func template() -> RoutineTemplate {
        RoutineTemplate(id: RoutineTemplateID(), version: 1, rules: [
            RoutineRule(id: nap1, name: "Siesta 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 5), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: lunch, name: "Comida", category: .feeding, timing: .anchor(earliest: WallClock(hour: 11, minute: 45), preferred: WallClock(hour: 12, minute: 0), latest: WallClock(hour: 12, minute: 45)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 40)),
            RoutineRule(id: nap2, name: "Siesta 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ])
    }

    private func makeStore(events: [LoggedEvent] = []) -> TodayStore {
        TodayStore(
            store: InMemoryEventStore(events: events),
            template: template(),
            household: household,
            operationalDay: OperationalDayID(anchorDate: day),
            timeZone: timeZone
        )
    }

    // MARK: - What matters now

    func testTheHeroIsWhateverIsReadyRightNow() async throws {
        let screen = try await makeStore().screen(now: at(12, 0), language: .spanish)
        let now = try XCTUnwrap(screen.now)

        XCTAssertEqual(now.title, "Comida")
        XCTAssertEqual(now.eyebrow, "AHORA")
        XCTAssertEqual(now.timeRange, "12:00–12:40")
        XCTAssertEqual(now.primaryAction, .startMeal(lunch))
        XCTAssertEqual(now.primaryActionLabel, "Empezar")
    }

    func testAnythingInProgressOutranksWhatIsMerelyReady() async throws {
        let store = makeStore()
        try await store.perform(.startSleep(nap1), now: at(10, 44))
        let screen = try await store.screen(now: at(11, 0), language: .spanish)
        let now = try XCTUnwrap(screen.now)

        XCTAssertEqual(now.title, "Siesta 1")
        XCTAssertTrue(now.isActive)
        XCTAssertEqual(now.primaryAction, .endSleep(nap1), "the only thing left to say about a nap in progress is that it ended")
        XCTAssertEqual(now.primaryActionLabel, "Despertó")
    }

    func testTheNextStripShowsOnlyTheNextFewThings() async throws {
        let screen = try await makeStore().screen(now: at(6, 0), language: .spanish)

        XCTAssertLessThanOrEqual(screen.next.count, 3)
        XCTAssertFalse(screen.next.contains { $0.ruleID == screen.now?.ruleID }, "the hero is not repeated in the strip")
    }

    func testCompletedWorkLeavesTheScreen() async throws {
        let store = makeStore()
        try await store.perform(.startSleep(nap1), now: at(10, 44))
        try await store.perform(.endSleep(nap1), now: at(11, 31))
        let screen = try await store.screen(now: at(11, 35), language: .spanish)

        XCTAssertNotEqual(screen.now?.ruleID, nap1)
        XCTAssertFalse(screen.next.contains { $0.ruleID == nap1 }, "Today is about what is left, not what is behind")
    }

    // MARK: - The sentence at the top

    func testACalmDaySaysSo() async throws {
        let screen = try await makeStore().screen(now: at(12, 0), language: .spanish)
        XCTAssertEqual(screen.dayState, "Todo va más o menos en orden.")
    }

    func testASlippedDayReportsTheEnginesOwnNumber() async throws {
        let store = makeStore()
        try await store.perform(.startSleep(nap1), now: at(10, 44))
        let screen = try await store.screen(now: at(10, 50), language: .spanish)

        // The nap was planned for 10:20 and started at 10:44: twenty-four minutes, from the engine.
        XCTAssertEqual(screen.dayState, "Hoy vamos como 24 minutos más tarde — ya está ajustado.")
    }

    func testTheSentenceNeverBlamesAnyone() async throws {
        let store = makeStore()
        try await store.perform(.startSleep(nap1), now: at(10, 44))

        for language in Language.allCases {
            let screen = try await store.screen(now: at(11, 0), language: language)
            let text = (screen.dayState + " " + (screen.now?.explanation ?? "")).lowercased()
            for forbidden in ["late", "missed", "failed", "behind", "tarde de más", "fallaste", "perdiste", "incumpl"] {
                XCTAssertFalse(text.contains(forbidden), "\(language): found guilt language in \"\(text)\"")
            }
        }
    }

    // MARK: - Explanations

    func testTheExplanationCarriesTheEnginesNumbersRatherThanNewOnes() async throws {
        let store = makeStore()
        try await store.perform(.startSleep(nap1), now: at(10, 44))
        try await store.perform(.endSleep(nap1), now: at(11, 31))
        let screen = try await store.screen(now: at(11, 35), language: .english)
        let now = try XCTUnwrap(screen.now)

        // Nap 2 is timed from when nap 1 actually ended, and the card says why.
        XCTAssertEqual(now.title, "Siesta 2")
        XCTAssertEqual(now.explanation, "Timed from when the last nap actually ended.")
    }

    func testAnUnchangedOccurrenceNeedsNoExplanation() async throws {
        let screen = try await makeStore().screen(now: at(12, 0), language: .english)
        XCTAssertNil(try XCTUnwrap(screen.now).explanation, "explain what moved, not what did not")
    }

    // MARK: - Language

    func testBothLanguagesAreComplete() async throws {
        for language in Language.allCases {
            let screen = try await makeStore().screen(now: at(12, 0), language: language)
            XCTAssertFalse(screen.greeting.isEmpty)
            XCTAssertFalse(screen.dateLine.isEmpty)
            XCTAssertFalse(screen.dayState.isEmpty)
            XCTAssertFalse(try XCTUnwrap(screen.now).primaryActionLabel.isEmpty)
        }
    }

    func testTheDateReadsNaturallyInEachLanguage() async throws {
        let spanish = try await makeStore().screen(now: at(12, 0), language: .spanish)
        let english = try await makeStore().screen(now: at(12, 0), language: .english)

        XCTAssertEqual(spanish.dateLine, "17 de agosto")
        XCTAssertEqual(english.dateLine, "August 17")
    }

    func testTheGreetingFollowsTheHour() async throws {
        let morning = try await makeStore().screen(now: at(8, 0), language: .spanish)
        let evening = try await makeStore().screen(now: at(20, 0), language: .spanish)

        XCTAssertEqual(morning.greeting, "Buenos días")
        XCTAssertEqual(evening.greeting, "Buenas noches")
    }

    // MARK: - The loop

    func testATapMovesTheRestOfTheDayOnScreen() async throws {
        let store = makeStore()
        let before = try await store.screen(now: at(8, 0), language: .spanish)
        let plannedNap2 = try XCTUnwrap(before.next.first { $0.ruleID == nap2 })

        try await store.perform(.startSleep(nap1), now: at(10, 44))
        try await store.perform(.endSleep(nap1), now: at(11, 31))
        let after = try await store.screen(now: at(11, 31), language: .spanish)
        let resolvedNap2 = try XCTUnwrap(after.now)

        XCTAssertEqual(resolvedNap2.ruleID, nap2)
        XCTAssertNotEqual(resolvedNap2.timeRange, plannedNap2.time, "the day visibly reflows after a single tap")
        XCTAssertTrue(after.next.contains { $0.wasAdjusted } || resolvedNap2.explanation != nil)
    }

    func testDelayingIsRespectedOnScreen() async throws {
        let store = makeStore()
        try await store.perform(.delay(lunch, minutes: 20), now: at(11, 50))
        let screen = try await store.screen(now: at(11, 50), language: .spanish)
        let now = try XCTUnwrap(screen.now)

        XCTAssertEqual(now.ruleID, lunch)
        XCTAssertEqual(now.timeRange, "12:20–13:00")
        XCTAssertEqual(now.explanation, "Tú moviste esto.")
    }

    func testASimplifiedDayIsAnnouncedWithoutShame() async throws {
        let store = makeStore()
        try await store.setMode(.chaos, now: at(12, 0))
        let screen = try await store.screen(now: at(12, 0), language: .spanish)

        XCTAssertEqual(screen.dayState, "Día simplificado: solo lo esencial.")
    }
}
