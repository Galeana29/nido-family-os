import Foundation
import NidoDomain
import NidoRoutineEngine

/// Turns a `ResolvedDayPlan` into the screen, and nothing else.
///
/// This is the layer that keeps the doctrine honest: the UI performs no scheduling. Everything here
/// is a projection of what the engine already decided, which is why it can be tested without a
/// simulator and why Today, a widget and the Watch can never disagree about the day.
public struct TodayPresenter: Sendable {
    public let timeZone: TimeZone
    public let language: Language

    public init(timeZone: TimeZone, language: Language) {
        self.timeZone = timeZone
        self.language = language
    }

    public func screen(for result: ResolutionResult, template: RoutineTemplate, now: Date) -> TodayScreen {
        let rules = Dictionary(uniqueKeysWithValues: template.rules.map { ($0.id, $0) })
        let visible = result.plan.occurrences.filter { $0.status != .completed && $0.status != .cancelled && $0.status != .skipped }

        let stillCurrent = visible.filter { now <= $0.resolvedTiming.latest }
        let current = hero(in: result, now: now)
        let upcoming = stillCurrent.filter { $0.ruleID != current?.ruleID }.prefix(3)

        return TodayScreen(
            greeting: Strings.greeting(hour: hour(of: now), language),
            dateLine: dateLine(result.plan.id.anchorDate),
            dayState: dayState(for: result, now: current),
            now: current.flatMap { nowCard(for: $0, rule: rules[$0.ruleID]) },
            next: upcoming.compactMap { nextItem(for: $0, rule: rules[$0.ruleID]) },
            notices: notices(for: result, rules: rules)
        )
    }

    /// The whole day in order, including what is already settled.
    ///
    /// Today answers "what now"; this answers "what else", which is the question a caregiver asks
    /// when they want to log something that is not the hero, or just see where the day stands. It is
    /// the same projection — same times, same labels, same taps — so the two views cannot disagree.
    public func day(for result: ResolutionResult, template: RoutineTemplate, now: Date) -> [DayEntry] {
        let rules = Dictionary(uniqueKeysWithValues: template.rules.map { ($0.id, $0) })
        let current = hero(in: result, now: now)
        return result.plan.occurrences.compactMap { occurrence in
            guard let rule = rules[occurrence.ruleID] else { return nil }
            let action = primaryAction(for: rule, status: occurrence.status)
            return DayEntry(
                ruleID: rule.id,
                time: clock(occurrence.resolvedTiming.preferred),
                timeRange: timeRange(for: occurrence, rule: rule),
                title: rule.name,
                statusLabel: Strings.status(occurrence.status, language),
                wasAdjusted: occurrence.originalTiming.preferred != occurrence.resolvedTiming.preferred,
                isCurrent: occurrence.ruleID == current?.ruleID,
                isSettled: occurrence.status == .completed || occurrence.status == .skipped || occurrence.status == .cancelled,
                action: action,
                actionLabel: Strings.actionLabel(action, language),
                explanation: Strings.explanation(for: occurrence.adjustmentReasons, language)
            )
        }
    }

    /// What matters now.
    ///
    /// The engine deliberately has no "missed" state: once a window opens an occurrence stays ready
    /// until someone acts on it, because a late nap is not a failure. That is right for the domain and
    /// wrong for a screen — at noon, a nap whose window closed at 10:40 is not what matters now. So
    /// this asks a question the engine does not: is this still current?
    private func hero(in result: ResolutionResult, now: Date) -> ResolvedOccurrence? {
        let visible = result.plan.occurrences.filter { $0.status != .completed && $0.status != .cancelled && $0.status != .skipped }
        let stillCurrent = visible.filter { now <= $0.resolvedTiming.latest }
        // An occurrence in progress is current by definition, even if it has run past its window.
        return visible.first { $0.status == .active }
            ?? stillCurrent.first { $0.status == .ready }
            ?? stillCurrent.first
    }

    // MARK: - Now

    private func nowCard(for occurrence: ResolvedOccurrence, rule: RoutineRule?) -> NowCard? {
        guard let rule else { return nil }
        let action = primaryAction(for: rule, status: occurrence.status)
        return NowCard(
            ruleID: rule.id,
            eyebrow: Strings.now(language),
            title: rule.name,
            timeRange: timeRange(for: occurrence, rule: rule),
            statusLabel: Strings.status(occurrence.status, language),
            primaryAction: action,
            primaryActionLabel: Strings.actionLabel(action, language),
            explanation: Strings.explanation(for: occurrence.adjustmentReasons, language),
            isActive: occurrence.status == .active
        )
    }

    /// One obvious tap, chosen from what the occurrence is and where it is in its own life.
    private func primaryAction(for rule: RoutineRule, status: OccurrenceStatus) -> TodayAction {
        switch rule.category {
        case .sleep:
            return status == .active ? .endSleep(rule.id) : .startSleep(rule.id)
        case .feeding, .breastfeeding:
            return status == .active ? .finishMeal(rule.id) : .startMeal(rule.id)
        default:
            return status == .active ? .finishMeal(rule.id) : .startMeal(rule.id)
        }
    }

    private func nextItem(for occurrence: ResolvedOccurrence, rule: RoutineRule?) -> NextItem? {
        guard let rule else { return nil }
        return NextItem(
            ruleID: rule.id,
            time: clock(occurrence.resolvedTiming.preferred),
            title: rule.name,
            statusLabel: Strings.status(occurrence.status, language),
            wasAdjusted: occurrence.originalTiming.preferred != occurrence.resolvedTiming.preferred
        )
    }

    // MARK: - Day state

    /// The sentence at the top of the screen. It reports; it never grades.
    private func dayState(for result: ResolutionResult, now: ResolvedOccurrence?) -> String {
        if result.plan.mode == .chaos { return Strings.simplifiedDay(language) }

        if result.plan.occurrences.contains(where: { occurrence in
            occurrence.adjustmentReasons.contains { if case .shortDuration = $0 { return true }; return false }
        }) {
            return Strings.shortNap(language)
        }

        let drift = largestDrift(in: result)
        if drift >= 10 { return Strings.runningLater(minutes: drift, language) }
        if drift <= -10 { return Strings.runningEarlier(minutes: abs(drift), language) }

        if now == nil { return Strings.nothingLeft(language) }
        return Strings.onTrack(language)
    }

    /// How far the day has slipped, taken from the engine's own figures rather than recomputed here.
    private func largestDrift(in result: ResolutionResult) -> Int {
        var drift = 0
        for occurrence in result.plan.occurrences {
            for reason in occurrence.adjustmentReasons {
                if case .actualEventRecorded(let delta) = reason, abs(delta) > abs(drift) { drift = delta }
            }
        }
        return drift
    }

    private func notices(for result: ResolutionResult, rules: [RuleID: RoutineRule]) -> [String] {
        result.conflicts.map { conflict in
            switch conflict.kind {
            case .unsatisfiable(let ruleID):
                return Strings.unsatisfiableNotice(rules[ruleID]?.name ?? "", language)
            case .overlap(let first, _), .commitmentOverlap(let first, _):
                return Strings.conflictNotice(rules[first]?.name ?? "", language)
            }
        }
    }

    // MARK: - Formatting

    private func timeRange(for occurrence: ResolvedOccurrence, rule: RoutineRule) -> String {
        let start = occurrence.resolvedTiming.preferred
        guard rule.expectedDurationMinutes > 0 else { return clock(start) }
        let end = start.addingTimeInterval(TimeInterval(rule.expectedDurationMinutes * 60))
        return "\(clock(start))–\(clock(end))"
    }

    /// 24-hour throughout. Unambiguous in both languages, and identical in tests and on screen.
    private func clock(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func hour(of date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.hour, from: date)
    }

    private func dateLine(_ date: LocalDate) -> String {
        let months = language == .english
            ? ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            : ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
        let month = months[max(0, min(11, date.month - 1))]
        return language == .english ? "\(month) \(date.day)" : "\(date.day) de \(month)"
    }
}
