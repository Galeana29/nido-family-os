import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

/// Shared scaffolding for engine tests: one operational day, one time zone, and terse builders.
struct DayFixture {
    let timeZone: TimeZone
    let day: LocalDate

    init(timeZone identifier: String = "America/Vancouver", year: Int = 2026, month: Int = 8, day: Int = 17) {
        self.timeZone = TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0)!
        self.day = LocalDate(year: year, month: month, day: day)
    }

    var clock: DayClock { DayClock(day: day, timeZone: timeZone) }

    func at(_ hour: Int, _ minute: Int) -> Date { clock.instant(WallClock(hour: hour, minute: minute)) }

    func minutes(from start: Date, to end: Date) -> Int { Int(end.timeIntervalSince(start) / 60) }

    func input(
        rules: [RoutineRule],
        commitments: [ExternalCommitment] = [],
        events: [LoggedEvent] = [],
        overrides: [ManualOverride] = [],
        careConstraints: [CareConstraint] = [],
        mode: DayMode = .normal,
        previousPlan: ResolvedDayPlan? = nil,
        now: Date? = nil
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
            currentTime: now ?? at(12, 0)
        )
    }

    /// Builds an event directly rather than through a command. Resolver tests need synthetic ledger
    /// states that no legal sequence of commands would produce — a nap end with no start, for
    /// instance — precisely to prove the resolver survives them. Ledger and command behaviour is
    /// tested through the real command path in EventLedgerTests.
    func event(_ type: EventType, at instant: Date, rule: RuleID, payload: EventPayload = .none) -> LoggedEvent {
        LoggedEvent(householdID: HouseholdID(), type: type, startedAt: instant, source: .app, createdAt: instant, modifiedAt: instant, payload: payload, ruleID: rule)
    }

    func sleepEvent(_ type: EventType, at instant: Date, rule: RuleID) -> LoggedEvent {
        event(type, at: instant, rule: rule, payload: .sleep(type: .nap1, assistance: SleepAssistance.none))
    }

    func windowRule(_ id: RuleID, _ name: String, earliest: (Int, Int), preferred: (Int, Int), latest: (Int, Int), priority: RoutinePriority, minutes duration: Int) -> RoutineRule {
        RoutineRule(
            id: id, name: name, category: .other,
            timing: .window(earliest: WallClock(hour: earliest.0, minute: earliest.1), preferred: WallClock(hour: preferred.0, minute: preferred.1), latest: WallClock(hour: latest.0, minute: latest.1)),
            priority: priority, duration: DurationRange(expectedMinutes: duration)
        )
    }

    func anchorRule(_ id: RuleID, _ name: String, earliest: (Int, Int), preferred: (Int, Int), latest: (Int, Int), priority: RoutinePriority, minutes duration: Int, policies: [AdjustmentPolicy] = []) -> RoutineRule {
        RoutineRule(
            id: id, name: name, category: .other,
            timing: .anchor(earliest: WallClock(hour: earliest.0, minute: earliest.1), preferred: WallClock(hour: preferred.0, minute: preferred.1), latest: WallClock(hour: latest.0, minute: latest.1)),
            priority: priority, duration: DurationRange(expectedMinutes: duration), adjustmentPolicies: policies
        )
    }
}

extension ResolutionResult {
    func occurrence(_ ruleID: RuleID) -> ResolvedOccurrence? {
        plan.occurrences.first { $0.ruleID == ruleID }
    }
}

/// SplitMix64. Seeded on purpose: a randomized suite that cannot be replayed is not a test, it is a
/// rumour. Every failure here reproduces exactly from the seed printed in the assertion.
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
