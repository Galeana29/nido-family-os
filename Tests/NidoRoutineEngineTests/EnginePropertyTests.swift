import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

/// Randomized scenarios run against the invariants, with a fixed seed so any failure replays exactly.
/// Hand-written cases test what we thought of; these test what we did not.
final class EnginePropertyTests: XCTestCase {
    private let fixture = DayFixture()
    private let seed: UInt64 = 0x1D0_FAM11Y

    private struct Scenario {
        let input: ResolutionInput
        let nap1: RuleID
        let nap2: RuleID
        let bedtime: RuleID
        let offsets: (min: Int, preferred: Int, max: Int)
        let actualNapEnd: Date?
        let iteration: Int
    }

    private func makeScenario(iteration: Int, using generator: inout SeededGenerator) -> Scenario {
        let nap1 = RuleID()
        let nap2 = RuleID()
        let bedtime = RuleID()

        let nap1Earliest = Int.random(in: 570...615, using: &generator)          // 09:30–10:15
        let nap1Preferred = nap1Earliest + Int.random(in: 0...20, using: &generator)
        let nap1Latest = nap1Preferred + Int.random(in: 0...30, using: &generator)
        let nap1Duration = Int.random(in: 30...90, using: &generator)

        let offsetMin = Int.random(in: 150...200, using: &generator)
        let offsetPreferred = offsetMin + Int.random(in: 0...30, using: &generator)
        let offsetMax = offsetPreferred + Int.random(in: 0...30, using: &generator)
        let nap2Duration = Int.random(in: 30...90, using: &generator)

        let bedtimeEarliest = Int.random(in: 1110...1170, using: &generator)      // 18:30–19:30
        let bedtimePreferred = bedtimeEarliest + Int.random(in: 0...30, using: &generator)
        let bedtimeLatest = bedtimePreferred + Int.random(in: 0...30, using: &generator)

        let rules = [
            RoutineRule(id: nap1, name: "Nap 1", category: .sleep, timing: .window(earliest: wallClock(nap1Earliest), preferred: wallClock(nap1Preferred), latest: wallClock(nap1Latest)), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: nap1Duration)),
            RoutineRule(id: nap2, name: "Nap 2", category: .sleep, timing: .dependent(reference: nap1, minMinutes: offsetMin, preferredMinutes: offsetPreferred, maxMinutes: offsetMax), priority: .p2ImportantRoutine, duration: DurationRange(expectedMinutes: nap2Duration)),
            RoutineRule(id: bedtime, name: "Bedtime", category: .sleep, timing: .anchor(earliest: wallClock(bedtimeEarliest), preferred: wallClock(bedtimePreferred), latest: wallClock(bedtimeLatest)), priority: .p1AnchorExternalCommitment, duration: DurationRange(expectedMinutes: 30), adjustmentPolicies: [.durationResponsive(reference: nap2, shortfallMinutes: Int.random(in: 10...40, using: &generator), shiftMinutes: Int.random(in: 5...45, using: &generator))])
        ]

        var events: [LoggedEvent] = []
        var actualNapEnd: Date?
        if Bool.random(using: &generator) {
            let start = minutesAsDate(nap1Preferred + Int.random(in: -20...45, using: &generator))
            let end = start.addingTimeInterval(TimeInterval(Int.random(in: 15...110, using: &generator) * 60))
            events = [
                fixture.sleepEvent(.napStarted, at: start, rule: nap1),
                fixture.sleepEvent(.napEnded, at: end, rule: nap1)
            ]
            actualNapEnd = end
        }

        var commitments: [ExternalCommitment] = []
        if Bool.random(using: &generator) {
            let start = minutesAsDate(Int.random(in: 720...960, using: &generator))
            commitments = [ExternalCommitment(id: ExternalCommitmentID(), start: start, end: start.addingTimeInterval(TimeInterval(Int.random(in: 30...90, using: &generator) * 60)))]
        }

        let input = fixture.input(
            rules: rules,
            commitments: commitments,
            events: events,
            now: minutesAsDate(Int.random(in: 360...1320, using: &generator))
        )
        return Scenario(input: input, nap1: nap1, nap2: nap2, bedtime: bedtime, offsets: (offsetMin, offsetPreferred, offsetMax), actualNapEnd: actualNapEnd, iteration: iteration)
    }

    private func wallClock(_ minutesFromMidnight: Int) -> WallClock {
        WallClock(hour: minutesFromMidnight / 60, minute: minutesFromMidnight % 60)
    }

    private func minutesAsDate(_ minutesFromMidnight: Int) -> Date {
        let clamped = max(0, min(23 * 60 + 59, minutesFromMidnight))
        return fixture.at(clamped / 60, clamped % 60)
    }

    private func context(_ scenario: Scenario) -> String {
        "seed \(String(seed, radix: 16)), iteration \(scenario.iteration)"
    }

    // MARK: - Properties

    func testRandomScenariosAlwaysHonourTheirOwnGuardrails() throws {
        var generator = SeededGenerator(seed: seed)
        let engine = RoutineEngine()

        for iteration in 0..<2_000 {
            let scenario = makeScenario(iteration: iteration, using: &generator)
            let result = try engine.resolve(scenario.input)

            for occurrence in result.plan.occurrences {
                XCTAssertLessThanOrEqual(occurrence.resolvedTiming.earliest, occurrence.resolvedTiming.preferred, context(scenario))
                XCTAssertLessThanOrEqual(occurrence.resolvedTiming.preferred, occurrence.resolvedTiming.latest, context(scenario))
                XCTAssertLessThanOrEqual(occurrence.originalTiming.earliest, occurrence.originalTiming.latest, context(scenario))
            }

            if let actualNapEnd = scenario.actualNapEnd, let nap2 = result.occurrence(scenario.nap2) {
                XCTAssertGreaterThanOrEqual(nap2.resolvedTiming.preferred, actualNapEnd.addingTimeInterval(TimeInterval(scenario.offsets.min * 60)), context(scenario))
                XCTAssertLessThanOrEqual(nap2.resolvedTiming.preferred, actualNapEnd.addingTimeInterval(TimeInterval(scenario.offsets.max * 60)), context(scenario))
            }
        }
    }

    func testRandomScenariosNeverMoveSomethingWithoutSayingWhy() throws {
        var generator = SeededGenerator(seed: seed &+ 1)
        let engine = RoutineEngine()

        for iteration in 0..<2_000 {
            let scenario = makeScenario(iteration: iteration, using: &generator)
            let result = try engine.resolve(scenario.input)

            for occurrence in result.plan.occurrences {
                let moved = occurrence.originalTiming.preferred != occurrence.resolvedTiming.preferred
                let omitted = occurrence.status == .cancelled
                if moved || omitted {
                    XCTAssertFalse(occurrence.adjustmentReasons.isEmpty, "unexplained change (\(context(scenario)))")
                }
            }
        }
    }

    func testRandomScenariosNeverOmitSafetyOrAnchorPriorities() throws {
        var generator = SeededGenerator(seed: seed &+ 2)
        let engine = RoutineEngine()

        for iteration in 0..<2_000 {
            let scenario = makeScenario(iteration: iteration, using: &generator)
            let result = try engine.resolve(scenario.input)

            for occurrence in result.plan.occurrences where occurrence.priority <= .p1AnchorExternalCommitment {
                XCTAssertNotEqual(occurrence.status, .cancelled, context(scenario))
            }
        }
    }

    func testRandomScenariosAreReproducible() throws {
        var generator = SeededGenerator(seed: seed &+ 3)
        let engine = RoutineEngine()

        for iteration in 0..<500 {
            let scenario = makeScenario(iteration: iteration, using: &generator)
            XCTAssertEqual(try engine.resolve(scenario.input), try engine.resolve(scenario.input), context(scenario))
        }
    }

    /// Stability must never be bought at the cost of validity: a retained time is always still legal.
    func testHysteresisNeverKeepsATimeThatNoLongerFits() throws {
        var generator = SeededGenerator(seed: seed &+ 4)
        let engine = RoutineEngine()

        for iteration in 0..<1_000 {
            let scenario = makeScenario(iteration: iteration, using: &generator)
            let first = try engine.resolve(scenario.input)

            // Reality is corrected by a few minutes, exactly the case hysteresis exists for.
            let drift = Int.random(in: -12...12, using: &generator)
            guard let originalEnd = scenario.actualNapEnd else { continue }
            let movedEnd = originalEnd.addingTimeInterval(TimeInterval(drift * 60))
            let events = [
                fixture.sleepEvent(.napStarted, at: movedEnd.addingTimeInterval(-30 * 60), rule: scenario.nap1),
                fixture.sleepEvent(.napEnded, at: movedEnd, rule: scenario.nap1)
            ]
            let second = try engine.resolve(fixture.input(
                rules: scenario.input.template.rules,
                commitments: scenario.input.commitments,
                events: events,
                previousPlan: first.plan,
                now: scenario.input.currentTime
            ))

            for occurrence in second.plan.occurrences {
                let retained = occurrence.adjustmentReasons.contains { if case .retainedForStability = $0 { return true }; return false }
                guard retained else { continue }
                XCTAssertGreaterThanOrEqual(occurrence.resolvedTiming.preferred, occurrence.resolvedTiming.earliest, context(scenario))
                XCTAssertLessThanOrEqual(occurrence.resolvedTiming.preferred, occurrence.resolvedTiming.latest, context(scenario))
            }
        }
    }
}
