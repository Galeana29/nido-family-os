import Foundation
import NidoDomain

extension RoutineEngine {
    /// Resolves one whole operational day.
    ///
    /// Pipeline, per `docs/architecture/resolution-algorithm.md`: normalize → P0/care constraints →
    /// exact commitments → dependency graph → candidate windows → place P1…P4 → adjustment policies →
    /// hysteresis → validate → emit plan and conflicts.
    ///
    /// The core invariant is minimum change: among valid plans, prefer the one closest to what the
    /// caregiver was already shown.
    public func resolve(_ input: ResolutionInput) throws -> ResolutionResult {
        var resolver = DayResolver(input: input, policy: policy)
        return try resolver.run()
    }
}

/// Actual reality reconstructed from the ledger. Never mutated back into the plan.
struct ActualState {
    private(set) var starts: [RuleID: Date] = [:]
    private(set) var ends: [RuleID: Date] = [:]
    private(set) var completed: Set<RuleID> = []

    init(events: [LoggedEvent]) {
        for event in events.sorted(by: { $0.startedAt < $1.startedAt }) {
            guard event.deletedAt == nil, let ruleID = event.ruleID else { continue }
            switch event.type {
            case .napStarted, .mealStarted, .breastfeedStarted, .nightSleepStarted, .routineStarted:
                starts[ruleID] = event.startedAt
            case .childWoke:
                // A wake is instantaneous: it both opens and closes its occurrence, so the plan is
                // pinned to when the child actually woke rather than when the template hoped.
                starts[ruleID] = event.startedAt
                ends[ruleID] = event.startedAt
                completed.insert(ruleID)
            case .napEnded, .mealEnded, .breastfeedEnded, .nightSleepEnded, .routineCompleted, .mealRated:
                ends[ruleID] = event.endedAt ?? event.startedAt
                completed.insert(ruleID)
            default:
                continue
            }
        }
    }

    func duration(of ruleID: RuleID) -> Int? {
        guard let start = starts[ruleID], let end = ends[ruleID] else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }
}

private struct DayResolver {
    let input: ResolutionInput
    let policy: ResolutionPolicy
    let clock: DayClock
    let actuals: ActualState
    let ruleByID: [RuleID: RoutineRule]
    let declarationIndex: [RuleID: Int]
    let overrideByRule: [RuleID: ManualOverride]
    let lockedRules: [RuleID: CareInstructionID]
    let previousPreferred: [RuleID: Date]

    var conflicts: [ResolutionConflict] = []

    init(input: ResolutionInput, policy: ResolutionPolicy) {
        self.input = input
        self.policy = policy
        self.clock = DayClock(day: input.operationalDay.anchorDate, timeZone: input.timeZone)
        self.actuals = ActualState(events: input.events)

        var ruleByID: [RuleID: RoutineRule] = [:]
        var declarationIndex: [RuleID: Int] = [:]
        for (index, rule) in input.template.rules.enumerated() {
            ruleByID[rule.id] = rule
            declarationIndex[rule.id] = index
        }
        self.ruleByID = ruleByID
        self.declarationIndex = declarationIndex

        var overrideByRule: [RuleID: ManualOverride] = [:]
        for override in input.overrides.sorted(by: { $0.decidedAt < $1.decidedAt }) {
            overrideByRule[override.ruleID] = override
        }
        self.overrideByRule = overrideByRule

        var lockedRules: [RuleID: CareInstructionID] = [:]
        for constraint in input.careConstraints where constraint.isLocked {
            lockedRules[constraint.ruleID] = constraint.id
        }
        self.lockedRules = lockedRules

        var previousPreferred: [RuleID: Date] = [:]
        for occurrence in input.previousPlan?.occurrences ?? [] {
            previousPreferred[occurrence.ruleID] = occurrence.resolvedTiming.preferred
        }
        self.previousPreferred = previousPreferred
    }

    /// One occurrence per rule per operational day, with an id derived from the rule so the same
    /// scenario always yields the same identifiers.
    func occurrenceID(_ ruleID: RuleID) -> OccurrenceID { OccurrenceID(ruleID.rawValue) }

    mutating func run() throws -> ResolutionResult {
        try validateInput()
        let ordered = try DependencyGraph.topologicalOrder(rules: input.template.rules)

        let original = computeWindows(ordered, applyReality: false).windows
        var (windows, reasons) = computeWindows(ordered, applyReality: true)

        var omitted = Set<RuleID>()
        for rule in ordered where input.mode == .chaos && rule.priority >= .p3Flexible {
            omitted.insert(rule.id)
            reasons[rule.id, default: []].append(.omittedForSimplifiedDay)
        }
        for rule in ordered where overrideByRule[rule.id]?.kind == .skip {
            omitted.insert(rule.id)
        }

        place(ordered, windows: &windows, reasons: &reasons, omitted: &omitted)
        validateOverlaps(ordered, windows: windows, omitted: omitted)

        let occurrences = ordered
            .sorted { lhs, rhs in
                let lhsTime = windows[lhs.id]?.preferred ?? .distantFuture
                let rhsTime = windows[rhs.id]?.preferred ?? .distantFuture
                if lhsTime != rhsTime { return lhsTime < rhsTime }
                return (declarationIndex[lhs.id] ?? 0) < (declarationIndex[rhs.id] ?? 0)
            }
            .compactMap { rule -> ResolvedOccurrence? in
                guard let window = windows[rule.id] else { return nil }
                return ResolvedOccurrence(
                    id: occurrenceID(rule.id),
                    ruleID: rule.id,
                    priority: rule.priority,
                    originalTiming: (original[rule.id] ?? window).resolved,
                    resolvedTiming: window.resolved,
                    status: status(for: rule, window: window, omitted: omitted.contains(rule.id)),
                    adjustmentReasons: reasons[rule.id] ?? []
                )
            }

        let plan = ResolvedDayPlan(
            id: input.operationalDay,
            generatedAt: input.currentTime,
            mode: input.mode,
            occurrences: occurrences
        )
        return ResolutionResult(plan: plan, conflicts: conflicts, policyVersion: policy.version)
    }

    /// Rejects malformed input rather than quietly normalizing it. A template whose guardrails are
    /// inverted is a configuration error, and silently sorting the bounds would hide it from whoever
    /// authored the routine.
    private func validateInput() throws {
        for event in input.events where !event.hasConsistentPayload {
            throw ResolutionError.inconsistentEventPayload(event.id)
        }
        for rule in input.template.rules {
            switch rule.timing {
            case .anchor(let earliest, let preferred, let latest),
                 .window(let earliest, let preferred, let latest):
                guard earliest <= preferred, preferred <= latest else {
                    throw ResolutionError.malformedWindow(rule.id)
                }
            case .relative(_, let minMinutes, let preferredMinutes, let maxMinutes),
                 .dependent(_, let minMinutes, let preferredMinutes, let maxMinutes):
                guard minMinutes <= preferredMinutes, preferredMinutes <= maxMinutes else {
                    throw ResolutionError.invalidOffsets
                }
            case .exact:
                continue
            }
        }
    }

    // MARK: - Candidate windows

    /// Computes each occurrence's window. With `applyReality` false this is pure template intent —
    /// the plan as authored — which is what `originalTiming` must report so adjustments stay explainable.
    private func computeWindows(_ ordered: [RoutineRule], applyReality: Bool) -> (windows: [RuleID: TimeWindow], reasons: [RuleID: [AdjustmentReason]]) {
        var windows: [RuleID: TimeWindow] = [:]
        var reasons: [RuleID: [AdjustmentReason]] = [:]

        for rule in ordered {
            var window: TimeWindow
            switch rule.timing {
            case .exact(let wallClock):
                let instant = clock.instant(wallClock)
                window = TimeWindow(earliest: instant, preferred: instant, latest: instant)

            case .anchor(let earliest, let preferred, let latest),
                 .window(let earliest, let preferred, let latest):
                window = TimeWindow(earliest: clock.instant(earliest), preferred: clock.instant(preferred), latest: clock.instant(latest))

            case .relative(let reference, let minMinutes, let preferredMinutes, let maxMinutes):
                let base = end(of: reference, windows: windows, applyReality: applyReality) ?? clock.instant(WallClock(hour: 0, minute: 0))
                window = offsetWindow(from: base, minMinutes: minMinutes, preferredMinutes: preferredMinutes, maxMinutes: maxMinutes)

            case .dependent(let reference, let minMinutes, let preferredMinutes, let maxMinutes):
                let base: Date
                if applyReality, let actualEnd = actuals.ends[reference] {
                    base = actualEnd
                    reasons[rule.id, default: []].append(.dependencyResolved(reference: occurrenceID(reference)))
                } else {
                    base = end(of: reference, windows: windows, applyReality: applyReality) ?? clock.instant(WallClock(hour: 0, minute: 0))
                    if applyReality {
                        reasons[rule.id, default: []].append(.estimatedFromPlan(reference: occurrenceID(reference)))
                    }
                }
                window = offsetWindow(from: base, minMinutes: minMinutes, preferredMinutes: preferredMinutes, maxMinutes: maxMinutes)
            }

            if applyReality {
                window = applyRealityAdjustments(to: window, rule: rule, reasons: &reasons)
            }
            windows[rule.id] = window
        }
        return (windows, reasons)
    }

    private func offsetWindow(from base: Date, minMinutes: Int, preferredMinutes: Int, maxMinutes: Int) -> TimeWindow {
        let lower = min(minMinutes, preferredMinutes, maxMinutes)
        let upper = max(minMinutes, preferredMinutes, maxMinutes)
        return TimeWindow(
            earliest: base.addingTimeInterval(TimeInterval(lower * 60)),
            preferred: base.addingTimeInterval(TimeInterval(preferredMinutes * 60)),
            latest: base.addingTimeInterval(TimeInterval(upper * 60))
        )
    }

    private func end(of ruleID: RuleID, windows: [RuleID: TimeWindow], applyReality: Bool) -> Date? {
        if applyReality, let actualEnd = actuals.ends[ruleID] { return actualEnd }
        guard let window = windows[ruleID], let rule = ruleByID[ruleID] else { return nil }
        return window.preferred.addingTimeInterval(TimeInterval(rule.expectedDurationMinutes * 60))
    }

    /// Reality, caregiver decisions and duration-responsive policies, then stability.
    private func applyRealityAdjustments(to window: TimeWindow, rule: RoutineRule, reasons: inout [RuleID: [AdjustmentReason]]) -> TimeWindow {
        var window = window

        if let actualStart = actuals.starts[rule.id] {
            let deltaMinutes = Int(actualStart.timeIntervalSince(window.preferred) / 60)
            if deltaMinutes != 0 {
                reasons[rule.id, default: []].append(.actualEventRecorded(deltaMinutes: deltaMinutes))
            }
            return window.including(actualStart)
        }

        if let override = overrideByRule[rule.id] {
            switch override.kind {
            case .moveTo(let wallClock):
                reasons[rule.id, default: []].append(.manualOverride)
                return window.including(clock.instant(wallClock))
            case .delay(let minutes):
                reasons[rule.id, default: []].append(.manualOverride)
                return window.including(window.preferred.addingTimeInterval(TimeInterval(minutes * 60)))
            case .skip, .complete:
                break
            }
        }

        for policy in rule.adjustmentPolicies {
            guard case .durationResponsive(let reference, let shortfallMinutes, let shiftMinutes) = policy,
                  let actualMinutes = actuals.duration(of: reference),
                  let referenceRule = ruleByID[reference]
            else { continue }
            let shortfall = referenceRule.expectedDurationMinutes - actualMinutes
            guard shortfall >= shortfallMinutes else { continue }
            let shifted = max(window.earliest, window.preferred.addingTimeInterval(TimeInterval(-shiftMinutes * 60)))
            window.preferred = shifted
            reasons[rule.id, default: []].append(.shortDuration(reference: occurrenceID(reference), minutes: actualMinutes))
        }

        if let previous = previousPreferred[rule.id] {
            let deltaMinutes = Int(abs(window.preferred.timeIntervalSince(previous)) / 60)
            let stillValid = previous >= window.earliest && previous <= window.latest
            if deltaMinutes < policy.materialityThresholdMinutes && stillValid && previous != window.preferred {
                window.preferred = previous
                reasons[rule.id, default: []].append(.retainedForStability(deltaMinutes: deltaMinutes))
            }
        }

        if let instruction = lockedRules[rule.id] {
            reasons[rule.id, default: []].append(.careConstraint(id: instruction))
        }

        return window
    }

    // MARK: - Placement

    private mutating func place(_ ordered: [RoutineRule], windows: inout [RuleID: TimeWindow], reasons: inout [RuleID: [AdjustmentReason]], omitted: inout Set<RuleID>) {
        var blockers: [(interval: Interval, priority: RoutinePriority, isCommitment: Bool)] = input.commitments
            .sorted { $0.start < $1.start }
            .map { (Interval(start: $0.start, end: $0.end), $0.priority, true) }

        let placementOrder = ordered.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            let lhsTime = windows[lhs.id]?.preferred ?? .distantFuture
            let rhsTime = windows[rhs.id]?.preferred ?? .distantFuture
            if lhsTime != rhsTime { return lhsTime < rhsTime }
            return (declarationIndex[lhs.id] ?? 0) < (declarationIndex[rhs.id] ?? 0)
        }

        for rule in placementOrder {
            guard !omitted.contains(rule.id), var window = windows[rule.id] else { continue }
            let duration = TimeInterval(rule.expectedDurationMinutes * 60)

            let isPinned = actuals.starts[rule.id] != nil
                || lockedRules[rule.id] != nil
                || rule.priority == .p0SafetyLockedCare
                || isExact(rule)
                || overrideByRule[rule.id] != nil

            if isPinned {
                blockers.append((Interval(start: window.preferred, end: window.preferred.addingTimeInterval(duration)), rule.priority, false))
                continue
            }

            let placement = firstFreeStart(window: window, duration: duration, blockers: blockers)
            if let placement {
                if placement.start != window.preferred {
                    reasons[rule.id, default: []].append(placement.displacedByCommitment ? .externalCommitmentConflict : .priorityDisplacement(byPriority: placement.blockingPriority))
                    window = window.including(placement.start)
                    windows[rule.id] = window
                }
                blockers.append((Interval(start: placement.start, end: placement.start.addingTimeInterval(duration)), rule.priority, false))
            } else if rule.priority >= .p3Flexible {
                omitted.insert(rule.id)
                reasons[rule.id, default: []].append(.externalCommitmentConflict)
            } else {
                // Too important to drop silently: keep it and let the caregiver decide.
                conflicts.append(ResolutionConflict(kind: .unsatisfiable(rule.id)))
                blockers.append((Interval(start: window.preferred, end: window.preferred.addingTimeInterval(duration)), rule.priority, false))
            }
        }
    }

    private func isExact(_ rule: RoutineRule) -> Bool {
        if case .exact = rule.timing { return true }
        return false
    }

    private struct Placement {
        let start: Date
        let blockingPriority: RoutinePriority
        let displacedByCommitment: Bool
    }

    /// Nearest free start to the preferred time, inside the guardrails. Candidates are the preferred
    /// time plus the edges of everything already placed, so the search is exact and finite.
    private func firstFreeStart(window: TimeWindow, duration: TimeInterval, blockers: [(interval: Interval, priority: RoutinePriority, isCommitment: Bool)]) -> Placement? {
        var candidates: [Date] = [window.preferred, window.earliest, window.latest]
        for blocker in blockers {
            candidates.append(blocker.interval.end)
            candidates.append(blocker.interval.start.addingTimeInterval(-duration))
        }

        var seen = Set<TimeInterval>()
        let ordered = candidates
            .filter { $0 >= window.earliest && $0 <= window.latest }
            .filter { seen.insert($0.timeIntervalSince1970).inserted }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.timeIntervalSince(window.preferred))
                let rhsDistance = abs(rhs.timeIntervalSince(window.preferred))
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                return lhs < rhs
            }

        var nearestBlocker: (priority: RoutinePriority, isCommitment: Bool)?
        for candidate in ordered {
            let interval = Interval(start: candidate, end: candidate.addingTimeInterval(duration))
            if let hit = blockers.first(where: { $0.interval.overlaps(interval) }) {
                if nearestBlocker == nil { nearestBlocker = (hit.priority, hit.isCommitment) }
                continue
            }
            return Placement(
                start: candidate,
                blockingPriority: nearestBlocker?.priority ?? .p1AnchorExternalCommitment,
                displacedByCommitment: nearestBlocker?.isCommitment ?? false
            )
        }
        return nil
    }

    // MARK: - Validation and status

    private mutating func validateOverlaps(_ ordered: [RoutineRule], windows: [RuleID: TimeWindow], omitted: Set<RuleID>) {
        let placed = ordered
            .filter { !omitted.contains($0.id) }
            .compactMap { rule -> (RoutineRule, Interval)? in
                guard let window = windows[rule.id] else { return nil }
                return (rule, Interval(start: window.preferred, end: window.preferred.addingTimeInterval(TimeInterval(rule.expectedDurationMinutes * 60))))
            }
            .sorted { $0.1.start < $1.1.start }

        // An occurrence that could not be moved may still collide with a calendar entry. Saying so is
        // the whole point: the caregiver resolves it, the engine does not pretend the day is fine.
        for (rule, interval) in placed {
            for commitment in input.commitments where interval.overlaps(Interval(start: commitment.start, end: commitment.end)) {
                conflicts.append(ResolutionConflict(kind: .commitmentOverlap(rule.id, commitment.id)))
            }
        }

        guard placed.count > 1 else { return }
        for outer in 0..<(placed.count - 1) {
            for inner in (outer + 1)..<placed.count where placed[outer].1.overlaps(placed[inner].1) {
                conflicts.append(ResolutionConflict(kind: .overlap(placed[outer].0.id, placed[inner].0.id)))
            }
        }
    }

    /// There is deliberately no "missed" or "overdue" state: once a window opens the occurrence stays
    /// ready until someone acts on it. A late nap is not a failure.
    private func status(for rule: RoutineRule, window: TimeWindow, omitted: Bool) -> OccurrenceStatus {
        if omitted {
            return overrideByRule[rule.id]?.kind == .skip ? .skipped : .cancelled
        }
        if actuals.completed.contains(rule.id) || overrideByRule[rule.id]?.kind == .complete { return .completed }
        if actuals.starts[rule.id] != nil { return .active }
        if input.currentTime >= window.earliest { return .ready }
        return .upcoming
    }
}
