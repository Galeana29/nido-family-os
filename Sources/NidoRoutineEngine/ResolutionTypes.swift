import Foundation
import NidoDomain

/// Identifies the ruleset that produced a plan. Same normalized inputs + same policy version => same output,
/// so a stored plan can always be traced back to the logic that made it.
public struct EnginePolicyVersion: Hashable, Sendable, Codable, CustomStringConvertible {
    public let value: String
    public init(_ value: String) { self.value = value }
    public static let v0 = EnginePolicyVersion("v0.1.0")
    public var description: String { value }
}

/// Everything the engine is allowed to look at. Notably includes `currentTime`: the engine never reads
/// the clock itself, so a scenario is reproducible forever.
public struct ResolutionInput: Sendable {
    public let operationalDay: OperationalDayID
    public let timeZone: TimeZone
    public let mode: DayMode
    public let template: RoutineTemplate
    public let careConstraints: [CareConstraint]
    public let commitments: [ExternalCommitment]
    public let events: [LoggedEvent]
    public let overrides: [ManualOverride]
    public let previousPlan: ResolvedDayPlan?
    public let currentTime: Date

    public init(operationalDay: OperationalDayID, timeZone: TimeZone, mode: DayMode = .normal, template: RoutineTemplate, careConstraints: [CareConstraint] = [], commitments: [ExternalCommitment] = [], events: [LoggedEvent] = [], overrides: [ManualOverride] = [], previousPlan: ResolvedDayPlan? = nil, currentTime: Date) {
        self.operationalDay = operationalDay
        self.timeZone = timeZone
        self.mode = mode
        self.template = template
        self.careConstraints = careConstraints
        self.commitments = commitments
        self.events = events
        self.overrides = overrides
        self.previousPlan = previousPlan
        self.currentTime = currentTime
    }
}

/// Something the engine could not settle on its own. Surfacing a conflict is always preferred over
/// silently dropping an important occurrence.
public struct ResolutionConflict: Sendable, Equatable, Hashable {
    public enum Kind: Sendable, Equatable, Hashable {
        /// No slot inside the guardrails was free, and the occurrence is too important to omit.
        case unsatisfiable(RuleID)
        /// Two placed occurrences overlap. The caregiver decides, not the engine.
        case overlap(RuleID, RuleID)
    }
    public let kind: Kind
    public init(kind: Kind) { self.kind = kind }
}

public struct ResolutionResult: Sendable, Equatable {
    public let plan: ResolvedDayPlan
    public let conflicts: [ResolutionConflict]
    public let policyVersion: EnginePolicyVersion

    public init(plan: ResolvedDayPlan, conflicts: [ResolutionConflict], policyVersion: EnginePolicyVersion) {
        self.plan = plan
        self.conflicts = conflicts
        self.policyVersion = policyVersion
    }
}

/// Half-open interval `[start, end)`. Zero-duration occurrences therefore never collide with anything.
struct Interval: Equatable {
    let start: Date
    let end: Date
    func overlaps(_ other: Interval) -> Bool { start < other.end && other.start < end }
}

struct TimeWindow: Equatable {
    var earliest: Date
    var preferred: Date
    var latest: Date

    /// Widens the guardrails so an authoritative caregiver choice is never rejected by its own window.
    func including(_ date: Date) -> TimeWindow {
        TimeWindow(earliest: min(earliest, date), preferred: date, latest: max(latest, date))
    }

    var resolved: ResolvedTiming { ResolvedTiming(earliest: earliest, preferred: preferred, latest: latest) }
}
