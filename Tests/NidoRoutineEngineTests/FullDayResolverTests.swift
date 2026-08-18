import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

final class FullDayResolverTests: XCTestCase {
    private let timeZone = TimeZone(identifier: "America/Vancouver")!
    private let day = LocalDate(year: 2026, month: 8, day: 17)
    private var clock: DayClock { DayClock(day: day, timeZone: timeZone) }

    private func at(_ hour: Int, _ minute: Int) -> Date { clock.instant(WallClock(hour: hour, minute: minute)) }
    private func minutes(_ from: Date, _ to: Date) -> Int { Int(to.timeIntervalSince(from) / 60) }

    private func input(
        rules: [RoutineRule],
        commitments: [ExternalCommitment] = [],
        events: [LoggedEvent] = [],
        overrides: [ManualOverride] = [],
        careConstraints: [CareConstraint] = [],
        mode: DayMode = .normal,
        previousPlan: ResolvedDayPlan? = nil,
        now: (Int, Int) = (12, 0)
    ) -> ResolutionInput {
        ResolutionInput(
            operationalDay: OperationalDayID(anchorDate: day),
            timeZone: timeZone,
            mode: mode,
            template: RoutineTemplate(id: RoutineTemplateID(), version: 1, rules: rules),
            careConstraints: careConstraints,
            commitments: commitments,
            events: events,
            overrides: overrides,
            previousPlan: previousPlan,
            currentTime: at(now.0, now.1)
        )
    }

    private func event(_ type: EventType, _ hour: Int, _ minute: Int, rule: RuleID, payload: EventPayload = .none) -> LoggedEvent {
        let instant = at(hour, minute)
        return LoggedEvent(householdID: HouseholdID(), type: type, startedAt: instant, source: .app, createdAt: instant, modifiedAt: instant, payload: payload, ruleID: rule)
    }

    private func occurrence(_ result: ResolutionResult, _ ruleID: RuleID) throws -> ResolvedOccurrence {
        try XCTUnwrap(result.plan.occurrences.first { $0.ruleID == ruleID })
    }

    // MARK: - Placement rules

    func testExactTimingNeverMovesForAnythingElse() throws {
        let appointment = RuleID()
        let flexible = RuleID()
        let rules = [
            RoutineRule(id: appointment, name: "Medication", category: .health, timing: .exact(WallClock(hour: 13, minute: 45)), priority: .p0SafetyLockedCare, duration: DurationRange(expectedMinutes: 10)),
            RoutineRule(id: flexible, name: "Outdoor", category: .outdoor, timing: .window(earliest: WallClock(hour: 13, minute: 0), preferred: WallClock(hour: 13, minute: 40), latest: WallClock(hour: 15, minute: 0)), priority: .p3Flexible, duration: DurationRange(expectedMinutes: 30))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules))
        XCTAssertEqual(try occurrence(result, appointment).resolvedTiming.preferred, at(13, 45))
    }

    func testLowerPriorityMovesAroundAnExternalCommitment() throws {
        let outdoor = RuleID()
        let rules = [
            RoutineRule(id: outdoor, name: "Outdoor", category: .outdoor, timing: .window(earliest: WallClock(hour: 12, minute: 45), preferred: WallClock(hour: 13, minute: 0), latest: WallClock(hour: 14, minute: 0)), priority: .p3Flexible, duration: DurationRange(expectedMinutes: 45))
        ]
        let commitment = ExternalCommitment(id: ExternalCommitmentID(), start: at(13, 30), end: at(14, 10))
        let result = try RoutineEngine().resolve(input(rules: rules, commitments: [commitment], now: (13, 0)))
        let resolved = try occurrence(result, outdoor)

        XCTAssertEqual(resolved.status, .ready)
        XCTAssertLessThanOrEqual(resolved.resolvedTiming.preferred.addingTimeInterval(45 * 60), at(13, 30), "must finish before the appointment starts")
        XCTAssertTrue(resolved.adjustmentReasons.contains(.externalCommitmentConflict))
    }

    func testOptionalIsOmittedRatherThanOverlappingWhenNoSlotExists() throws {
        let outdoor = RuleID()
        let rules = [
            RoutineRule(id: outdoor, name: "Outdoor", category: .outdoor, timing: .window(earliest: WallClock(hour: 13, minute: 0), preferred: WallClock(hour: 13, minute: 10), latest: WallClock(hour: 13, minute: 30)), priority: .p4Optional, duration: DurationRange(expectedMinutes: 45))
        ]
        let commitment = ExternalCommitment(id: ExternalCommitmentID(), start: at(13, 0), end: at(14, 30))
        let result = try RoutineEngine().resolve(input(rules: rules, commitments: [commitment]))

        XCTAssertEqual(try occurrence(result, outdoor).status, .cancelled, "engine omission is cancelled, never skipped: the caregiver did not skip it")
        XCTAssertTrue(result.conflicts.isEmpty)
    }

    func testImportantOccurrenceWithNoSlotSurfacesAConflictInsteadOfDisappearing() throws {
        let lunch = RuleID()
        let rules = [
            RoutineRule(id: lunch, name: "Lunch", category: .feeding, timing: .anchor(earliest: WallClock(hour: 12, minute: 0), preferred: WallClock(hour: 12, minute: 10), latest: WallClock(hour: 12, minute: 20)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 40))
        ]
        let commitment = ExternalCommitment(id: ExternalCommitmentID(), start: at(11, 0), end: at(14, 0))
        let result = try RoutineEngine().resolve(input(rules: rules, commitments: [commitment]))

        XCTAssertEqual(result.conflicts, [ResolutionConflict(kind: .unsatisfiable(lunch))])
        XCTAssertNotEqual(try occurrence(result, lunch).status, .cancelled)
    }

    // MARK: - Dependencies

    func testDependentTimingUsesActualEndAndReportsTheDependency() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            RoutineRule(id: nap1, name: "Nap 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 5), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let events = [
            event(.napStarted, 10, 44, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none)),
            event(.napEnded, 11, 31, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules, events: events))
        let resolved = try occurrence(result, nap2)

        XCTAssertEqual(minutes(at(11, 31), resolved.resolvedTiming.preferred), 210)
        XCTAssertEqual(minutes(at(11, 31), resolved.resolvedTiming.earliest), 195)
        XCTAssertEqual(minutes(at(11, 31), resolved.resolvedTiming.latest), 225)
        XCTAssertTrue(resolved.adjustmentReasons.contains(.dependencyResolved(reference: OccurrenceID(nap1.rawValue))))
        XCTAssertNotEqual(resolved.originalTiming.preferred, resolved.resolvedTiming.preferred, "reality moved it, so the original plan must still differ")
    }

    func testDependentFallsBackToThePlanBeforeRealityIsLogged() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            RoutineRule(id: nap1, name: "Nap 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 5), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules, now: (8, 0)))
        let resolved = try occurrence(result, nap2)

        XCTAssertEqual(resolved.resolvedTiming.preferred, at(14, 35), "10:20 + 45 min planned nap + 210 min")
        XCTAssertTrue(resolved.adjustmentReasons.contains(.estimatedFromPlan(reference: OccurrenceID(nap1.rawValue))))
    }

    func testDependencyCycleIsRejected() {
        let first = RuleID()
        let second = RuleID()
        let rules = [
            RoutineRule(id: first, name: "First", category: .other, timing: .dependent(reference: second, minMinutes: 10, preferredMinutes: 10, maxMinutes: 10), priority: .p2ImportantRoutine),
            RoutineRule(id: second, name: "Second", category: .other, timing: .dependent(reference: first, minMinutes: 10, preferredMinutes: 10, maxMinutes: 10), priority: .p2ImportantRoutine)
        ]
        XCTAssertThrowsError(try RoutineEngine().resolve(input(rules: rules))) { error in
            XCTAssertEqual(error as? ResolutionError, .dependencyCycle)
        }
    }

    func testUnknownReferenceIsRejected() {
        let orphan = RuleID()
        let missing = RuleID()
        let rules = [
            RoutineRule(id: orphan, name: "Orphan", category: .other, timing: .dependent(reference: missing, minMinutes: 10, preferredMinutes: 10, maxMinutes: 10), priority: .p2ImportantRoutine)
        ]
        XCTAssertThrowsError(try RoutineEngine().resolve(input(rules: rules))) { error in
            XCTAssertEqual(error as? ResolutionError, .unknownReference(missing))
        }
    }

    // MARK: - Adjustment policies

    func testShortNapMovesBedtimeEarlierInsideItsGuardrails() throws {
        let nap2 = RuleID()
        let bedtime = RuleID()
        let rules = [
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .window(earliest: WallClock(hour: 14, minute: 30), preferred: WallClock(hour: 15, minute: 0), latest: WallClock(hour: 15, minute: 30)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75)),
            RoutineRule(id: bedtime, name: "Bedtime", category: .sleep, timing: .anchor(earliest: WallClock(hour: 19, minute: 0), preferred: WallClock(hour: 19, minute: 30), latest: WallClock(hour: 20, minute: 0)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 30), adjustmentPolicies: [.durationResponsive(reference: nap2, shortfallMinutes: 30, shiftMinutes: 20)])
        ]
        let events = [
            event(.napStarted, 15, 1, rule: nap2, payload: .sleep(type: .nap2, assistance: SleepAssistance.none)),
            event(.napEnded, 15, 34, rule: nap2, payload: .sleep(type: .nap2, assistance: SleepAssistance.none))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules, events: events, now: (16, 0)))
        let resolved = try occurrence(result, bedtime)

        XCTAssertEqual(minutes(resolved.resolvedTiming.preferred, resolved.originalTiming.preferred), 20, "shifted earlier by exactly the configured amount")
        XCTAssertGreaterThanOrEqual(resolved.resolvedTiming.preferred, at(19, 0), "never outside the anchor guardrails")
        XCTAssertTrue(resolved.adjustmentReasons.contains(.shortDuration(reference: OccurrenceID(nap2.rawValue), minutes: 33)))
    }

    func testDurationResponsivePolicyStaysInsideGuardrails() throws {
        let nap2 = RuleID()
        let bedtime = RuleID()
        let rules = [
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .window(earliest: WallClock(hour: 14, minute: 30), preferred: WallClock(hour: 15, minute: 0), latest: WallClock(hour: 15, minute: 30)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 120)),
            RoutineRule(id: bedtime, name: "Bedtime", category: .sleep, timing: .anchor(earliest: WallClock(hour: 19, minute: 20), preferred: WallClock(hour: 19, minute: 30), latest: WallClock(hour: 20, minute: 0)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 30), adjustmentPolicies: [.durationResponsive(reference: nap2, shortfallMinutes: 10, shiftMinutes: 90)])
        ]
        let events = [
            event(.napStarted, 15, 0, rule: nap2, payload: .sleep(type: .nap2, assistance: SleepAssistance.none)),
            event(.napEnded, 15, 20, rule: nap2, payload: .sleep(type: .nap2, assistance: SleepAssistance.none))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules, events: events, now: (16, 0)))
        XCTAssertEqual(try occurrence(result, bedtime).resolvedTiming.preferred, at(19, 20), "clamped to earliest, not shifted the full 90 minutes")
    }

    // MARK: - Caregiver authority and stability

    func testManualOverrideWinsAndIsNotCorrectedBack() throws {
        let lunch = RuleID()
        let rules = [
            RoutineRule(id: lunch, name: "Lunch", category: .feeding, timing: .anchor(earliest: WallClock(hour: 11, minute: 45), preferred: WallClock(hour: 12, minute: 0), latest: WallClock(hour: 12, minute: 45)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 40))
        ]
        let override = ManualOverride(ruleID: lunch, kind: .moveTo(WallClock(hour: 13, minute: 15)), decidedAt: at(11, 0))
        let result = try RoutineEngine().resolve(input(rules: rules, overrides: [override]))
        let resolved = try occurrence(result, lunch)

        XCTAssertEqual(resolved.resolvedTiming.preferred, at(13, 15), "outside the original guardrails, because the caregiver said so")
        XCTAssertTrue(resolved.adjustmentReasons.contains(.manualOverride))
    }

    func testImmaterialChangeRetainsThePlanAlreadyShown() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            RoutineRule(id: nap1, name: "Nap 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 5), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let events = [
            event(.napStarted, 10, 44, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none)),
            event(.napEnded, 11, 31, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none))
        ]
        let first = try RoutineEngine().resolve(input(rules: rules, events: events))

        // The same day resolved again after a two-minute correction to when nap 1 ended.
        let corrected = [
            event(.napStarted, 10, 44, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none)),
            event(.napEnded, 11, 33, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none))
        ]
        let second = try RoutineEngine().resolve(input(rules: rules, events: corrected, previousPlan: first.plan))
        let resolved = try occurrence(second, nap2)

        XCTAssertEqual(resolved.resolvedTiming.preferred, try occurrence(first, nap2).resolvedTiming.preferred, "a two-minute correction must not redraw the day")
        XCTAssertTrue(resolved.adjustmentReasons.contains(.retainedForStability(deltaMinutes: 2)))
    }

    // MARK: - Modes, validation, determinism

    func testSimplifiedDayKeepsEssentialsAndOmitsTheRest() throws {
        let dinner = RuleID()
        let outdoor = RuleID()
        let rules = [
            RoutineRule(id: dinner, name: "Dinner", category: .feeding, timing: .anchor(earliest: WallClock(hour: 17, minute: 30), preferred: WallClock(hour: 17, minute: 45), latest: WallClock(hour: 18, minute: 15)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 40)),
            RoutineRule(id: outdoor, name: "Outdoor", category: .outdoor, timing: .window(earliest: WallClock(hour: 13, minute: 0), preferred: WallClock(hour: 13, minute: 30), latest: WallClock(hour: 15, minute: 0)), priority: .p3Flexible, duration: DurationRange(expectedMinutes: 45))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules, mode: .chaos))

        let kept = try occurrence(result, dinner)
        XCTAssertNotEqual(kept.status, .cancelled, "essentials survive a simplified day")
        XCTAssertFalse(kept.adjustmentReasons.contains(.omittedForSimplifiedDay))

        let omitted = try occurrence(result, outdoor)
        XCTAssertEqual(omitted.status, .cancelled)
        XCTAssertTrue(omitted.adjustmentReasons.contains(.omittedForSimplifiedDay))
    }

    func testEventWithMismatchedPayloadIsRejected() {
        let nap = RuleID()
        let rules = [RoutineRule(id: nap, name: "Nap", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 0), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45))]
        let broken = event(.napStarted, 10, 20, rule: nap, payload: .mealRated(rating: .small, foods: [], behaviors: [], notes: nil))

        XCTAssertThrowsError(try RoutineEngine().resolve(input(rules: rules, events: [broken]))) { error in
            XCTAssertEqual(error as? ResolutionError, .inconsistentEventPayload(broken.id))
        }
    }

    func testSameInputProducesTheSameOutput() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let lunch = RuleID()
        let rules = [
            RoutineRule(id: nap1, name: "Nap 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 5), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: lunch, name: "Lunch", category: .feeding, timing: .anchor(earliest: WallClock(hour: 11, minute: 45), preferred: WallClock(hour: 12, minute: 0), latest: WallClock(hour: 12, minute: 45)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 40)),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let events = [event(.napEnded, 11, 31, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none))]
        let engine = RoutineEngine()

        let first = try engine.resolve(input(rules: rules, events: events))
        let second = try engine.resolve(input(rules: rules, events: events))
        XCTAssertEqual(first, second)
    }

    func testEveryAdjustedOccurrenceCarriesAReason() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            RoutineRule(id: nap1, name: "Nap 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 5), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let events = [
            event(.napStarted, 10, 44, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none)),
            event(.napEnded, 11, 31, rule: nap1, payload: .sleep(type: .nap1, assistance: SleepAssistance.none))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules, events: events))

        for occurrence in result.plan.occurrences where occurrence.originalTiming.preferred != occurrence.resolvedTiming.preferred {
            XCTAssertFalse(occurrence.adjustmentReasons.isEmpty, "an unexplained move is a bug: every change must be explainable")
        }
    }

    func testWindowBoundsAreAlwaysOrdered() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            RoutineRule(id: nap1, name: "Nap 1", category: .sleep, timing: .window(earliest: WallClock(hour: 10, minute: 5), preferred: WallClock(hour: 10, minute: 20), latest: WallClock(hour: 10, minute: 40)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 45)),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 225, preferredMinutes: 210, maxMinutes: 195), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let result = try RoutineEngine().resolve(input(rules: rules))
        for occurrence in result.plan.occurrences {
            XCTAssertLessThanOrEqual(occurrence.resolvedTiming.earliest, occurrence.resolvedTiming.preferred)
            XCTAssertLessThanOrEqual(occurrence.resolvedTiming.preferred, occurrence.resolvedTiming.latest)
        }
    }
}
