import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

/// The properties that must hold for NIDO to be trustworthy, stated as tests rather than as prose in
/// a document. These are not feature tests: each one is an attempt to break the engine.
final class EngineInvariantTests: XCTestCase {
    private let fixture = DayFixture()

    // MARK: - Priority

    func testExactTimingIsImmovableUnderPressure() throws {
        let medication = RuleID()
        let lunch = RuleID()
        let outdoor = RuleID()
        let rules = [
            RoutineRule(id: medication, name: "Medication", category: .health, timing: .exact(WallClock(hour: 13, minute: 0)), priority: .p0SafetyLockedCare, duration: DurationRange(expectedMinutes: 15)),
            fixture.anchorRule(lunch, "Lunch", earliest: (12, 30), preferred: (13, 0), latest: (13, 30), priority: .p1AnchorExternalCommitment, minutes: 45),
            fixture.windowRule(outdoor, "Outdoor", earliest: (12, 30), preferred: (13, 0), latest: (14, 30), priority: .p3Flexible, minutes: 60)
        ]
        let commitment = ExternalCommitment(id: ExternalCommitmentID(), start: fixture.at(12, 50), end: fixture.at(13, 20))
        let result = try RoutineEngine().resolve(fixture.input(rules: rules, commitments: [commitment]))

        let resolved = try XCTUnwrap(result.occurrence(medication))
        XCTAssertEqual(resolved.resolvedTiming.preferred, fixture.at(13, 0))
        XCTAssertEqual(resolved.originalTiming.preferred, resolved.resolvedTiming.preferred)
    }

    func testSafetyPriorityIsNeverDisplacedOrOmitted() throws {
        let safety = RuleID()
        let anchor = RuleID()
        let rules = [
            fixture.anchorRule(safety, "Locked care", earliest: (13, 0), preferred: (13, 30), latest: (14, 0), priority: .p0SafetyLockedCare, minutes: 30),
            fixture.anchorRule(anchor, "Appointment prep", earliest: (13, 0), preferred: (13, 30), latest: (14, 0), priority: .p1AnchorExternalCommitment, minutes: 30)
        ]
        let commitment = ExternalCommitment(id: ExternalCommitmentID(), start: fixture.at(13, 0), end: fixture.at(14, 0))
        let result = try RoutineEngine().resolve(fixture.input(rules: rules, commitments: [commitment]))

        let resolved = try XCTUnwrap(result.occurrence(safety))
        XCTAssertEqual(resolved.resolvedTiming.preferred, fixture.at(13, 30), "P0 holds its slot against everything")
        XCTAssertNotEqual(resolved.status, .cancelled)
    }

    func testOptionalIsSacrificedBeforeImportant() throws {
        let important = RuleID()
        let optional = RuleID()
        let rules = [
            fixture.windowRule(optional, "Optional play", earliest: (13, 0), preferred: (13, 0), latest: (13, 20), priority: .p4Optional, minutes: 60),
            fixture.anchorRule(important, "Lunch", earliest: (13, 0), preferred: (13, 0), latest: (13, 20), priority: .p1AnchorExternalCommitment, minutes: 60)
        ]
        let result = try RoutineEngine().resolve(fixture.input(rules: rules))

        XCTAssertEqual(try XCTUnwrap(result.occurrence(important)).resolvedTiming.preferred, fixture.at(13, 0), "the important one keeps the slot")
        XCTAssertEqual(try XCTUnwrap(result.occurrence(optional)).status, .cancelled)
        XCTAssertEqual(result.conflicts, [], "an omitted optional item is a resolution, not a conflict")
    }

    func testNothingEverDisappearsFromThePlan() throws {
        let rules = (0..<6).map { index in
            fixture.windowRule(RuleID(), "Rule \(index)", earliest: (13, 0), preferred: (13, 0), latest: (13, 30), priority: index < 2 ? .p1AnchorExternalCommitment : .p4Optional, minutes: 45)
        }
        let result = try RoutineEngine().resolve(fixture.input(rules: rules))

        XCTAssertEqual(result.plan.occurrences.count, rules.count, "omitted occurrences are still reported, with a reason")
        for rule in rules {
            XCTAssertNotNil(result.occurrence(rule.id))
        }
    }

    // MARK: - Caregiver authority

    func testManualOverrideSurvivesReResolution() throws {
        let lunch = RuleID()
        let rules = [fixture.anchorRule(lunch, "Lunch", earliest: (11, 45), preferred: (12, 0), latest: (12, 45), priority: .p1AnchorExternalCommitment, minutes: 40)]
        let override = ManualOverride(ruleID: lunch, kind: .moveTo(WallClock(hour: 13, minute: 15)), decidedAt: fixture.at(11, 0))
        let engine = RoutineEngine()

        var plan = try engine.resolve(fixture.input(rules: rules, overrides: [override])).plan
        for _ in 0..<5 {
            plan = try engine.resolve(fixture.input(rules: rules, overrides: [override], previousPlan: plan)).plan
        }
        let resolved = try XCTUnwrap(plan.occurrences.first { $0.ruleID == lunch })
        XCTAssertEqual(resolved.resolvedTiming.preferred, fixture.at(13, 15), "the engine must not walk the caregiver back to the old plan")
    }

    // MARK: - Determinism

    func testCurrentTimeChangesStatusesButNeverTimings() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            fixture.windowRule(nap1, "Nap 1", earliest: (10, 5), preferred: (10, 20), latest: (10, 40), priority: .p2ImportantRoutine, minutes: 45),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let engine = RoutineEngine()
        let early = try engine.resolve(fixture.input(rules: rules, now: fixture.at(6, 0)))
        let late = try engine.resolve(fixture.input(rules: rules, now: fixture.at(21, 0)))

        for occurrence in early.plan.occurrences {
            let counterpart = try XCTUnwrap(late.occurrence(occurrence.ruleID))
            XCTAssertEqual(occurrence.resolvedTiming, counterpart.resolvedTiming, "the wall clock must not influence placement")
        }
        XCTAssertNotEqual(early.plan.occurrences.map(\.status), late.plan.occurrences.map(\.status))
    }

    func testRepeatedResolutionIsStable() throws {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let rules = [
            fixture.windowRule(nap1, "Nap 1", earliest: (10, 5), preferred: (10, 20), latest: (10, 40), priority: .p2ImportantRoutine, minutes: 45),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: 195, preferredMinutes: 210, maxMinutes: 225), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: 75))
        ]
        let events = [fixture.sleepEvent(.napEnded, at: fixture.at(11, 31), rule: nap1)]
        let engine = RoutineEngine()

        var plan = try engine.resolve(fixture.input(rules: rules, events: events)).plan
        let firstPass = plan
        for _ in 0..<20 {
            plan = try engine.resolve(fixture.input(rules: rules, events: events, previousPlan: plan)).plan
        }
        XCTAssertEqual(plan, firstPass, "re-resolving an unchanged day must not drift")
    }

    // MARK: - Malformed input

    func testInvertedGuardrailsAreRejectedRatherThanQuietlySorted() {
        let broken = RuleID()
        let rules = [fixture.anchorRule(broken, "Backwards", earliest: (20, 0), preferred: (19, 30), latest: (19, 0), priority: .p1AnchorExternalCommitment, minutes: 30)]

        XCTAssertThrowsError(try RoutineEngine().resolve(fixture.input(rules: rules))) { error in
            XCTAssertEqual(error as? ResolutionError, .malformedWindow(broken))
        }
    }

    func testInvertedOffsetsAreRejected() {
        let reference = RuleID()
        let dependent = RuleID()
        let rules = [
            fixture.windowRule(reference, "Nap", earliest: (10, 0), preferred: (10, 20), latest: (10, 40), priority: .p2ImportantRoutine, minutes: 45),
            RoutineRule(id: dependent, name: "Later", category: .sleep, timing: .dependent(reference: reference, minMinutes: 225, preferredMinutes: 210, maxMinutes: 195), priority: .p2ImportantRoutine)
        ]
        XCTAssertThrowsError(try RoutineEngine().resolve(fixture.input(rules: rules))) { error in
            XCTAssertEqual(error as? ResolutionError, .invalidOffsets)
        }
    }

    // MARK: - Conflicts

    func testUnmovableOccurrenceCollidingWithACommitmentIsReported() throws {
        let medication = RuleID()
        let rules = [RoutineRule(id: medication, name: "Medication", category: .health, timing: .exact(WallClock(hour: 13, minute: 45)), priority: .p0SafetyLockedCare, duration: DurationRange(expectedMinutes: 15))]
        let commitment = ExternalCommitment(id: ExternalCommitmentID(), start: fixture.at(13, 30), end: fixture.at(14, 10))
        let result = try RoutineEngine().resolve(fixture.input(rules: rules, commitments: [commitment]))

        XCTAssertEqual(result.conflicts, [ResolutionConflict(kind: .commitmentOverlap(medication, commitment.id))])
        XCTAssertEqual(try XCTUnwrap(result.occurrence(medication)).resolvedTiming.preferred, fixture.at(13, 45), "reported, not silently moved")
    }

    func testAdjacentOccurrencesTouchingAtTheBoundaryDoNotConflict() throws {
        let first = RuleID()
        let second = RuleID()
        let rules = [
            fixture.anchorRule(first, "Lunch", earliest: (12, 0), preferred: (12, 0), latest: (12, 0), priority: .p1AnchorExternalCommitment, minutes: 30),
            fixture.anchorRule(second, "Play", earliest: (12, 30), preferred: (12, 30), latest: (12, 30), priority: .p1AnchorExternalCommitment, minutes: 30)
        ]
        let result = try RoutineEngine().resolve(fixture.input(rules: rules))
        XCTAssertEqual(result.conflicts, [], "one ending exactly when the next begins is a normal day, not a collision")
    }
}
