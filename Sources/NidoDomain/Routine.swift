import Foundation

public struct RoutineTemplateID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }
public struct CareInstructionID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }
public struct ExternalCommitmentID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }

public enum RoutineCategory: String, Codable, Sendable {
    case sleep, feeding, breastfeeding, health, hygiene, development, outdoor
    case personal, household, appointment, travel, prep, shopping, other
}

/// How long an occurrence is expected to occupy the day. Used for overlap detection, never to score the caregiver.
public struct DurationRange: Hashable, Codable, Sendable {
    public let minMinutes: Int
    public let expectedMinutes: Int
    public let maxMinutes: Int

    public init(minMinutes: Int, expectedMinutes: Int, maxMinutes: Int) {
        self.minMinutes = minMinutes
        self.expectedMinutes = expectedMinutes
        self.maxMinutes = maxMinutes
    }

    public init(expectedMinutes: Int) {
        self.init(minMinutes: expectedMinutes, expectedMinutes: expectedMinutes, maxMinutes: expectedMinutes)
    }
}

/// The five placement rules. Adjustment behaviour is orthogonal and lives in `AdjustmentPolicy`.
public enum TimingRule: Sendable, Equatable, Hashable {
    /// Externally fixed. The engine never moves it.
    case exact(WallClock)
    /// A preferred wall-clock time with hard guardrails, e.g. bedtime.
    case anchor(earliest: WallClock, preferred: WallClock, latest: WallClock)
    /// Should happen inside a range, with a preferred point inside it.
    case window(earliest: WallClock, preferred: WallClock, latest: WallClock)
    /// Offset from where the referenced occurrence is *planned* to end.
    case relative(reference: RuleID, minMinutes: Int, preferredMinutes: Int, maxMinutes: Int)
    /// Offset from where the referenced occurrence *actually* ended; falls back to the plan until reality is logged.
    case dependent(reference: RuleID, minMinutes: Int, preferredMinutes: Int, maxMinutes: Int)
}

public enum AdjustmentPolicy: Sendable, Equatable, Hashable {
    /// When `reference` runs at least `shortfallMinutes` shorter than expected, move this occurrence
    /// earlier by `shiftMinutes`, always clamped to its own guardrails. Short nap → earlier bedtime.
    case durationResponsive(reference: RuleID, shortfallMinutes: Int, shiftMinutes: Int)
    case externalConflict
    case modePolicy
    case manualOverride
}

public struct RoutineRule: Sendable, Equatable, Identifiable {
    public let id: RuleID
    public let name: String
    public let category: RoutineCategory
    public let timing: TimingRule
    public let priority: RoutinePriority
    public let duration: DurationRange?
    public let adjustmentPolicies: [AdjustmentPolicy]

    public init(id: RuleID, name: String, category: RoutineCategory, timing: TimingRule, priority: RoutinePriority, duration: DurationRange? = nil, adjustmentPolicies: [AdjustmentPolicy] = []) {
        self.id = id
        self.name = name
        self.category = category
        self.timing = timing
        self.priority = priority
        self.duration = duration
        self.adjustmentPolicies = adjustmentPolicies
    }

    public var expectedDurationMinutes: Int { duration?.expectedMinutes ?? 0 }

    /// Rules this one must be resolved after. Drives topological ordering and cycle detection.
    public var references: [RuleID] {
        var result: [RuleID] = []
        switch timing {
        case .relative(let reference, _, _, _), .dependent(let reference, _, _, _):
            result.append(reference)
        case .exact, .anchor, .window:
            break
        }
        for policy in adjustmentPolicies {
            if case .durationResponsive(let reference, _, _) = policy { result.append(reference) }
        }
        var seen = Set<RuleID>()
        return result.filter { seen.insert($0).inserted }
    }
}

public struct RoutineTemplate: Sendable, Equatable {
    public let id: RoutineTemplateID
    public let version: Int
    public let rules: [RoutineRule]

    public init(id: RoutineTemplateID, version: Int, rules: [RoutineRule]) {
        self.id = id
        self.version = version
        self.rules = rules
    }
}

/// A locked professional instruction pinned to a rule. Automation may schedule around it but never
/// silently omit or move it outside its guardrails.
public struct CareConstraint: Sendable, Equatable {
    public let id: CareInstructionID
    public let ruleID: RuleID
    public let isLocked: Bool

    public init(id: CareInstructionID, ruleID: RuleID, isLocked: Bool) {
        self.id = id
        self.ruleID = ruleID
        self.isLocked = isLocked
    }
}

/// An external commitment read from the calendar. Deliberately carries no title: the engine needs the
/// interval, not the description. See `docs/safety/privacy-security.md`.
public struct ExternalCommitment: Sendable, Equatable, Identifiable {
    public let id: ExternalCommitmentID
    public let start: Date
    public let end: Date
    public let priority: RoutinePriority

    public init(id: ExternalCommitmentID, start: Date, end: Date, priority: RoutinePriority = .p1AnchorExternalCommitment) {
        self.id = id
        self.start = start
        self.end = end
        self.priority = priority
    }
}

public enum ManualOverrideKind: Sendable, Equatable, Hashable {
    case moveTo(WallClock)
    case delay(minutes: Int)
    case skip
    case complete
}

/// The caregiver is authoritative. An override is an input to the next resolution, not a value the
/// engine may quietly correct back toward the old plan.
public struct ManualOverride: Sendable, Equatable {
    public let ruleID: RuleID
    public let kind: ManualOverrideKind
    public let decidedAt: Date

    public init(ruleID: RuleID, kind: ManualOverrideKind, decidedAt: Date) {
        self.ruleID = ruleID
        self.kind = kind
        self.decidedAt = decidedAt
    }
}
