import XCTest
import Foundation
import NidoDomain
import NidoRoutineEngine
import NidoScenario

/// The canonical imperfect day, resolved from the real `examples/sample-day.json`.
///
/// Every expectation here is derived from the fixture itself — offsets, guardrails and event times are
/// read back out of the decoded input. Nothing is transcribed by hand, because a handwritten expected
/// time is exactly how the original 14:45 defect got into the repository and stayed there.
final class CanonicalDayTests: XCTestCase {
    private func loadCanonicalDay() throws -> (fixture: ScenarioFixture, input: ResolutionInput, result: ResolutionResult) {
        let url = ScenarioLocator.canonicalDayFixture
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ScenarioError.fixtureNotFound(url.path)
        }
        let fixture = try ScenarioFixture.load(from: url)
        let input = try fixture.makeInput()
        return (fixture, input, try RoutineEngine().resolve(input))
    }

    private func rule(_ input: ResolutionInput, _ name: String) throws -> RoutineRule {
        let id = ScenarioFixture.ruleID(name)
        return try XCTUnwrap(input.template.rules.first { $0.id == id })
    }

    private func occurrence(_ result: ResolutionResult, _ name: String) throws -> ResolvedOccurrence {
        let id = ScenarioFixture.ruleID(name)
        return try XCTUnwrap(result.plan.occurrences.first { $0.ruleID == id })
    }

    private func interval(_ occurrence: ResolvedOccurrence, _ rule: RoutineRule) -> (start: Date, end: Date) {
        let start = occurrence.resolvedTiming.preferred
        return (start, start.addingTimeInterval(TimeInterval(rule.expectedDurationMinutes * 60)))
    }

    func testCanonicalDayResolvesWithoutConflicts() throws {
        let day = try loadCanonicalDay()
        XCTAssertEqual(day.result.conflicts, [], "the canonical day must resolve cleanly")
        XCTAssertEqual(day.result.plan.occurrences.count, day.input.template.rules.count)
    }

    func testNoTwoOccurrencesOverlap() throws {
        let day = try loadCanonicalDay()
        let placed = try day.result.plan.occurrences
            .filter { $0.status != .cancelled && $0.status != .skipped }
            .map { occurrence -> (String, start: Date, end: Date) in
                let rule = try XCTUnwrap(day.input.template.rules.first { $0.id == occurrence.ruleID })
                let bounds = interval(occurrence, rule)
                return (rule.name, bounds.start, bounds.end)
            }
            .sorted { $0.start < $1.start }

        for index in placed.indices.dropLast() {
            XCTAssertLessThanOrEqual(placed[index].end, placed[index + 1].start, "\(placed[index].0) overlaps \(placed[index + 1].0)")
        }
    }

    func testExternalAppointmentIntervalIsKeptFree() throws {
        let day = try loadCanonicalDay()
        let appointment = try XCTUnwrap(day.input.commitments.first)

        for occurrence in day.result.plan.occurrences where occurrence.status != .cancelled {
            let rule = try XCTUnwrap(day.input.template.rules.first { $0.id == occurrence.ruleID })
            let bounds = interval(occurrence, rule)
            let overlaps = bounds.start < appointment.end && appointment.start < bounds.end
            XCTAssertFalse(overlaps, "\(rule.name) runs through the fixed appointment")
        }
    }

    func testSecondNapLandsInsideTheWindowItsOwnRuleDeclares() throws {
        let day = try loadCanonicalDay()
        let nap2Rule = try rule(day.input, "nap2")
        guard case .dependent(let reference, let minMinutes, _, let maxMinutes) = nap2Rule.timing else {
            return XCTFail("nap2 is expected to be a dependent rule in the fixture")
        }
        let actualEnd = try XCTUnwrap(day.input.events.first { $0.ruleID == reference && $0.type == .napEnded }?.startedAt)
        let resolved = try occurrence(day.result, "nap2").resolvedTiming

        XCTAssertGreaterThanOrEqual(resolved.preferred, actualEnd.addingTimeInterval(TimeInterval(minMinutes * 60)))
        XCTAssertLessThanOrEqual(resolved.preferred, actualEnd.addingTimeInterval(TimeInterval(maxMinutes * 60)))
    }

    func testAnchoredOccurrencesStayInsideTheirGuardrails() throws {
        let day = try loadCanonicalDay()
        let clock = DayClock(day: day.input.operationalDay.anchorDate, timeZone: day.input.timeZone)

        for rule in day.input.template.rules {
            guard case .anchor(let earliest, _, let latest) = rule.timing else { continue }
            let resolved = try occurrence(day.result, ruleName(for: rule, in: day.fixture)).resolvedTiming
            XCTAssertGreaterThanOrEqual(resolved.preferred, clock.instant(earliest), "\(rule.name) moved before its guardrail")
            XCTAssertLessThanOrEqual(resolved.preferred, clock.instant(latest), "\(rule.name) moved past its guardrail")
        }
    }

    func testSafetyAndAnchorPrioritiesAreNeverOmitted() throws {
        let day = try loadCanonicalDay()
        for occurrence in day.result.plan.occurrences where occurrence.priority <= .p1AnchorExternalCommitment {
            XCTAssertNotEqual(occurrence.status, .cancelled, "a P0/P1 occurrence must never be silently dropped")
        }
    }

    func testStatusesReflectWhatAlreadyHappened() throws {
        let day = try loadCanonicalDay()
        XCTAssertEqual(try occurrence(day.result, "nap1").status, .completed, "nap 1 has a logged end")
        XCTAssertEqual(try occurrence(day.result, "breakfast").status, .completed, "breakfast was rated")

        let lunch = try occurrence(day.result, "lunch")
        let expected: OccurrenceStatus = day.input.currentTime >= lunch.resolvedTiming.earliest ? .ready : .upcoming
        XCTAssertEqual(lunch.status, expected)
        XCTAssertEqual(try occurrence(day.result, "bedtime").status, .upcoming)
    }

    func testResolvingTheCanonicalDayTwiceIsIdentical() throws {
        let first = try loadCanonicalDay()
        let second = try loadCanonicalDay()
        XCTAssertEqual(first.result, second.result)
    }

    /// Locks the reviewed engine output. The snapshot is generated by `NidoScenarioRunner`, read by a
    /// human and committed; it is never authored by hand. Until it exists the test reports as skipped.
    func testCanonicalDayMatchesTheReviewedGoldenSnapshot() throws {
        let day = try loadCanonicalDay()
        let rendered = SnapshotRenderer(template: day.input.template, timeZone: day.input.timeZone).render(day.result)
        let url = ScenarioLocator.goldenSnapshot

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("----- canonical day, generated for review -----")
            print(rendered)
            throw XCTSkip("golden snapshot not committed yet: review the output above and commit it as examples/\(url.lastPathComponent)")
        }
        let golden = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(rendered, golden, "engine output drifted from the reviewed snapshot")
    }

    private func ruleName(for rule: RoutineRule, in fixture: ScenarioFixture) -> String {
        fixture.planned.first { ScenarioFixture.ruleID($0.id) == rule.id }?.id ?? ""
    }
}
