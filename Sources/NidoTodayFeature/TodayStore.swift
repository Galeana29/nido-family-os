import Foundation
import NidoDomain
import NidoRoutineEngine

/// Owns the loop: a tap becomes a command, the command becomes reality, reality re-resolves the day,
/// and the screen is whatever the day now says. Nothing here decides a time.
public actor TodayStore {
    private let store: any EventStore
    private let engine: RoutineEngine
    private let template: RoutineTemplate
    private let household: HouseholdID
    private let operationalDay: OperationalDayID
    private let timeZone: TimeZone
    private let commitments: [ExternalCommitment]
    private let careConstraints: [CareConstraint]

    private var mode: DayMode
    private var overrides: [ManualOverride] = []
    /// What the caregiver was last shown. The engine uses it to avoid redrawing the day over nothing.
    private var previousPlan: ResolvedDayPlan?

    public init(
        store: any EventStore,
        engine: RoutineEngine = RoutineEngine(),
        template: RoutineTemplate,
        household: HouseholdID,
        operationalDay: OperationalDayID,
        timeZone: TimeZone,
        commitments: [ExternalCommitment] = [],
        careConstraints: [CareConstraint] = [],
        mode: DayMode = .normal,
        overrides: [ManualOverride] = [],
        previousPlan: ResolvedDayPlan? = nil
    ) {
        self.store = store
        self.engine = engine
        self.template = template
        self.household = household
        self.operationalDay = operationalDay
        self.timeZone = timeZone
        self.commitments = commitments
        self.careConstraints = careConstraints
        self.mode = mode
        self.overrides = overrides
        self.previousPlan = previousPlan
    }

    /// What the caregiver has decided by hand, and what the ledger holds. A client that survives
    /// being closed has to be able to read both back out, or a delay lasts only as long as the
    /// process does. Reading is all that is offered: decisions still go through `perform`.
    public func currentOverrides() -> [ManualOverride] { overrides }

    public func currentEvents() async throws -> [LoggedEvent] { try await store.allEvents() }

    public func resolve(now: Date) async throws -> ResolutionResult {
        let ledger = try await store.ledger()
        let result = try engine.resolve(ResolutionInput(
            operationalDay: operationalDay,
            timeZone: timeZone,
            mode: mode,
            template: template,
            careConstraints: careConstraints,
            commitments: commitments,
            events: ledger.effectiveEvents,
            overrides: overrides,
            previousPlan: previousPlan,
            currentTime: now
        ))
        previousPlan = result.plan
        return result
    }

    public func screen(now: Date, language: Language) async throws -> TodayScreen {
        let result = try await resolve(now: now)
        return TodayPresenter(timeZone: timeZone, language: language).screen(for: result, template: template, now: now)
    }

    /// Applies a caregiver action. Logging goes to the ledger through commands; delaying and skipping
    /// are decisions about the plan, so they become overrides the engine must respect.
    public func perform(_ action: TodayAction, now: Date) async throws {
        switch action {
        case .startSleep(let ruleID):
            try await store.apply(StartSleepCommand(householdID: household, occurredAt: now, source: .app, ruleID: ruleID, sleepType: sleepType(for: ruleID)), now: now)
        case .endSleep(let ruleID):
            try await store.apply(EndSleepCommand(householdID: household, occurredAt: now, source: .app, ruleID: ruleID, sleepType: sleepType(for: ruleID)), now: now)
        case .startMeal(let ruleID):
            try await store.apply(StartMealCommand(householdID: household, occurredAt: now, source: .app, ruleID: ruleID), now: now)
        case .finishMeal(let ruleID):
            try await store.apply(EndMealCommand(householdID: household, occurredAt: now, source: .app, ruleID: ruleID), now: now)
        case .rateMeal(let ruleID, let rating):
            try await store.apply(RateMealCommand(householdID: household, occurredAt: now, source: .app, ruleID: ruleID, rating: rating), now: now)
        case .delay(let ruleID, let minutes):
            setOverride(ManualOverride(ruleID: ruleID, kind: .delay(minutes: minutes), decidedAt: now))
        case .skip(let ruleID):
            setOverride(ManualOverride(ruleID: ruleID, kind: .skip, decidedAt: now))
        }
    }

    public func setMode(_ mode: DayMode, now: Date) async throws {
        self.mode = mode
        try await store.apply(ChangeDayModeCommand(householdID: household, occurredAt: now, source: .app, mode: mode), now: now)
    }

    private func setOverride(_ override: ManualOverride) {
        overrides.removeAll { $0.ruleID == override.ruleID }
        overrides.append(override)
    }

    /// Naming the nap lets the log stay readable later without asking the caregiver to classify it.
    private func sleepType(for ruleID: RuleID) -> SleepType {
        guard let rule = template.rules.first(where: { $0.id == ruleID }) else { return .other }
        let name = rule.name.lowercased()
        if name.contains("night") || name.contains("bedtime") || name.contains("noche") || name.contains("dormir") { return .night }
        if name.contains("1") { return .nap1 }
        if name.contains("2") { return .nap2 }
        return .other
    }
}
