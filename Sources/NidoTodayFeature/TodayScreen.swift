import Foundation
import NidoDomain

/// What the caregiver can do from the Now card, in the order the day actually happens.
public enum TodayAction: Sendable, Equatable, Hashable {
    case startSleep(RuleID)
    case endSleep(RuleID)
    case startMeal(RuleID)
    case finishMeal(RuleID)
    case rateMeal(RuleID, MealRating)
    case delay(RuleID, minutes: Int)
    case skip(RuleID)
}

/// The hero of Today. It answers one question — what matters now — and offers one obvious next tap.
public struct NowCard: Sendable, Equatable {
    public let ruleID: RuleID
    public let eyebrow: String
    public let title: String
    public let timeRange: String
    public let statusLabel: String
    public let primaryAction: TodayAction
    public let primaryActionLabel: String
    /// Present only when something moved and the reason is worth a sentence.
    public let explanation: String?
    public let isActive: Bool
}

public struct NextItem: Sendable, Equatable {
    public let ruleID: RuleID
    public let time: String
    public let title: String
    public let statusLabel: String
    /// Adjusted is an indicator, never a lifecycle state and never a failure.
    public let wasAdjusted: Bool
}

public struct TodayScreen: Sendable, Equatable {
    public let greeting: String
    public let dateLine: String
    /// One sentence describing the shape of the day. Neutral, never congratulatory or scolding.
    public let dayState: String
    public let now: NowCard?
    public let next: [NextItem]
    /// Things only the caregiver can settle. Empty on a normal day.
    public let notices: [String]
}
