import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

/// Resolution across a daylight-saving transition.
///
/// The rule NIDO has to get right: **offsets are elapsed time, anchors are wall-clock intent.** Three
/// hours after a nap is three hours of a child sleeping, whatever the clock did meanwhile; bedtime at
/// 19:30 is 19:30 on the wall, whatever the offset from midnight became.
final class DstResolutionTests: XCTestCase {
    private func calendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func makeRules(nap: RuleID, dependent: RuleID, bedtime: RuleID) -> [RoutineRule] {
        [
            RoutineRule(id: nap, name: "Night sleep", category: .sleep, timing: .window(earliest: WallClock(hour: 0, minute: 30), preferred: WallClock(hour: 1, minute: 0), latest: WallClock(hour: 1, minute: 30)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 30)),
            RoutineRule(id: dependent, name: "Next sleep", category: .sleep, timing: .dependent(reference: nap, minMinutes: 150, preferredMinutes: 180, maxMinutes: 210), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 60)),
            RoutineRule(id: bedtime, name: "Bedtime", category: .sleep, timing: .anchor(earliest: WallClock(hour: 19, minute: 0), preferred: WallClock(hour: 19, minute: 30), latest: WallClock(hour: 20, minute: 0)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 30))
        ]
    }

    private func resolve(day: LocalDate, timeZone: TimeZone, napEnd: Date, nap: RuleID, dependent: RuleID, bedtime: RuleID) throws -> ResolutionResult {
        let events = [
            LoggedEvent(householdID: HouseholdID(), type: .napStarted, startedAt: napEnd.addingTimeInterval(-30 * 60), source: .app, createdAt: napEnd, modifiedAt: napEnd, payload: .sleep(type: .night, assistance: SleepAssistance.none), ruleID: nap),
            LoggedEvent(householdID: HouseholdID(), type: .napEnded, startedAt: napEnd, source: .app, createdAt: napEnd, modifiedAt: napEnd, payload: .sleep(type: .night, assistance: SleepAssistance.none), ruleID: nap)
        ]
        let input = ResolutionInput(
            operationalDay: OperationalDayID(anchorDate: day),
            timeZone: timeZone,
            template: RoutineTemplate(id: RoutineTemplateID(), version: 1, rules: makeRules(nap: nap, dependent: dependent, bedtime: bedtime)),
            events: events,
            currentTime: napEnd
        )
        return try RoutineEngine().resolve(input)
    }

    func testSpringForwardKeepsOffsetsElapsedAndAnchorsOnTheWall() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let calendar = calendar(timeZone)
        let day = LocalDate(year: 2026, month: 3, day: 8)
        let nap = RuleID(), dependent = RuleID(), bedtime = RuleID()

        // 01:30 PST, half an hour before the clocks jump from 02:00 to 03:00.
        let napEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 30)))
        let result = try resolve(day: day, timeZone: timeZone, napEnd: napEnd, nap: nap, dependent: dependent, bedtime: bedtime)

        let next = try XCTUnwrap(result.occurrence(dependent))
        XCTAssertEqual(next.resolvedTiming.preferred.timeIntervalSince(napEnd), 180 * 60, "three hours must stay three hours of real time")
        XCTAssertEqual(calendar.component(.hour, from: next.resolvedTiming.preferred), 5, "which reads as 05:30 on the wall, because an hour disappeared")
        XCTAssertEqual(calendar.component(.minute, from: next.resolvedTiming.preferred), 30)

        let sleep = try XCTUnwrap(result.occurrence(bedtime))
        XCTAssertEqual(calendar.component(.hour, from: sleep.resolvedTiming.preferred), 19, "bedtime is wall-clock intent and does not shift")
        XCTAssertEqual(calendar.component(.minute, from: sleep.resolvedTiming.preferred), 30)
    }

    func testFallBackKeepsOffsetsElapsedThroughTheRepeatedHour() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let calendar = calendar(timeZone)
        let day = LocalDate(year: 2026, month: 11, day: 1)
        let nap = RuleID(), dependent = RuleID(), bedtime = RuleID()

        // 00:30 PDT, before 02:00 falls back to 01:00 and the 01:00 hour happens twice.
        let napEnd = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30)))
        let result = try resolve(day: day, timeZone: timeZone, napEnd: napEnd, nap: nap, dependent: dependent, bedtime: bedtime)

        let next = try XCTUnwrap(result.occurrence(dependent))
        XCTAssertEqual(next.resolvedTiming.preferred.timeIntervalSince(napEnd), 180 * 60, "elapsed time is unaffected by the repeated hour")
        XCTAssertEqual(calendar.component(.hour, from: next.resolvedTiming.preferred), 2, "three elapsed hours land at 02:30 PST, not 03:30")
        XCTAssertEqual(calendar.component(.minute, from: next.resolvedTiming.preferred), 30)

        let sleep = try XCTUnwrap(result.occurrence(bedtime))
        XCTAssertEqual(calendar.component(.hour, from: sleep.resolvedTiming.preferred), 19)
    }

    func testAnchorInsideTheSpringForwardGapResolvesToARealInstant() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let calendar = calendar(timeZone)
        let clock = DayClock(day: LocalDate(year: 2026, month: 3, day: 8), timeZone: timeZone)

        // 02:30 does not exist on this date.
        let instant = clock.instant(WallClock(hour: 2, minute: 30))
        let hour = calendar.component(.hour, from: instant)
        XCTAssertEqual(hour, 3, "a routine anchored in the gap moves forward to the first hour that exists")
    }

    func testOperationalDayIsUnaffectedByTheTransition() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Vancouver"))
        let calendar = calendar(timeZone)
        let wake = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 7, minute: 4)))
        XCTAssertEqual(OperationalDay.id(openedByPrimaryWake: wake, timeZone: timeZone).anchorDate, LocalDate(year: 2026, month: 3, day: 8))
    }
}
