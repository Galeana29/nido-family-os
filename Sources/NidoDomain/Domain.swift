import Foundation

public struct HouseholdID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }
public struct PersonID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }
public struct EventID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }
public struct SessionID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }
public struct OccurrenceID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }
public struct RuleID: Hashable, Sendable, Codable { public let rawValue: UUID; public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue } }

public enum RoutinePriority: Int, Codable, Sendable, Comparable {
    case p0SafetyLockedCare = 0, p1AnchorExternalCommitment = 1, p2ImportantRoutine = 2, p3Flexible = 3, p4Optional = 4
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
public enum OccurrenceStatus: String, Codable, Sendable { case upcoming, ready, active, completed, skipped, cancelled }
public enum DayMode: String, Codable, Sendable { case normal, daycare, out, sick, chaos, custom }
public struct LocalDate: Hashable, Codable, Sendable { public let year: Int; public let month: Int; public let day: Int; public init(year:Int,month:Int,day:Int){self.year=year;self.month=month;self.day=day} }
public struct OperationalDayID: Hashable, Codable, Sendable { public let anchorDate: LocalDate; public init(anchorDate:LocalDate){self.anchorDate=anchorDate} }

public enum EventType: String, Codable, Sendable {
    case childWoke, mealStarted, mealEnded, mealRated, napStarted, napEnded, nightSleepStarted, nightSleepEnded, nightWake
    case breastfeedStarted, breastfeedEnded, diaperChanged, waterLogged, routineStarted, routineCompleted, routineSkipped, routineRescheduled
    case modeChanged, weightRecorded, healthNoteRecorded, calendarConflictAcknowledged, eventCorrected
}
public enum EventSource: String, Codable, Sendable { case app, watch, voice, widget, siri, imported, automation }

public enum MealRating: String, Codable, Sendable { case none, taste, small, normal, more }
public enum MealBehavior: String, Codable, Sendable { case closedMouth, threwFood, distracted, tired, askedForMilk, other }
public enum SleepType: String, Codable, Sendable { case night, nap1, nap2, other }
public enum SleepAssistance: String, Codable, Sendable { case none, cuddle, breastfeed, other }
public enum BreastfeedContext: String, Codable, Sendable { case wake, nap, bedtime, comfort, other }
/// Typed per-event detail. Detail is optional by design: logging speed wins, payloads never become mandatory.
public enum EventPayload: Codable, Sendable, Equatable {
    case mealRated(rating: MealRating, foods: [String], behaviors: [MealBehavior], notes: String?)
    case sleep(type: SleepType, assistance: SleepAssistance?)
    // `planned` distinguishes structured vs on-demand feeding patterns without requiring volume measurement.
    case breastfeed(context: BreastfeedContext, planned: Bool)
    case weight(kilograms: Double)
    case healthNote(text: String)
    case none
}

public struct LoggedEvent: Codable, Sendable, Equatable {
    public let id: EventID; public let householdID: HouseholdID; public let personID: PersonID?; public let logicalSessionID: SessionID?
    public let type: EventType; public let startedAt: Date; public let endedAt: Date?; public let source: EventSource; public let createdBy: PersonID?
    public let createdAt: Date; public let modifiedAt: Date; public let revision: Int; public let deletedAt: Date?
    public let payload: EventPayload
    public init(id:EventID=EventID(), householdID:HouseholdID, personID:PersonID?=nil, logicalSessionID:SessionID?=nil, type:EventType, startedAt:Date, endedAt:Date?=nil, source:EventSource, createdBy:PersonID?=nil, createdAt:Date, modifiedAt:Date, revision:Int=1, deletedAt:Date?=nil, payload:EventPayload = .none){ self.id=id;self.householdID=householdID;self.personID=personID;self.logicalSessionID=logicalSessionID;self.type=type;self.startedAt=startedAt;self.endedAt=endedAt;self.source=source;self.createdBy=createdBy;self.createdAt=createdAt;self.modifiedAt=modifiedAt;self.revision=revision;self.deletedAt=deletedAt;self.payload=payload }
}
public enum TimingRule: Sendable, Equatable { case exact(Date); case anchor(earliest:Date,preferred:Date,latest:Date); case window(earliest:Date,preferred:Date,latest:Date); case relative(reference:OccurrenceID,minMinutes:Int,preferredMinutes:Int,maxMinutes:Int); case dependent(reference:OccurrenceID,minMinutes:Int,preferredMinutes:Int,maxMinutes:Int) }
public enum AdjustmentPolicy: Sendable, Equatable { case durationResponsive(reference:OccurrenceID,thresholdMinutes:Int,shiftMinutes:Int); case externalConflict, modePolicy, manualOverride }
public enum AdjustmentReason: Sendable, Equatable { case dependencyResolved(reference:OccurrenceID); case retainedForStability(deltaMinutes:Int); case shortDuration(reference:OccurrenceID,minutes:Int); case externalCommitmentConflict, manualOverride }
public struct ResolvedTiming: Sendable, Equatable { public let earliest:Date; public let preferred:Date; public let latest:Date; public init(earliest:Date,preferred:Date,latest:Date){ precondition(earliest <= preferred && preferred <= latest); self.earliest=earliest;self.preferred=preferred;self.latest=latest } }
/// Carries both the originally planned timing and the resolved timing so every adjustment is explainable against intent.
public struct ResolvedOccurrence: Sendable, Equatable {
    public let id:OccurrenceID; public let ruleID:RuleID; public let priority:RoutinePriority
    public let originalTiming:ResolvedTiming; public let resolvedTiming:ResolvedTiming
    public let status:OccurrenceStatus; public let adjustmentReasons:[AdjustmentReason]
    public init(id:OccurrenceID, ruleID:RuleID, priority:RoutinePriority, originalTiming:ResolvedTiming, resolvedTiming:ResolvedTiming, status:OccurrenceStatus, adjustmentReasons:[AdjustmentReason]){ self.id=id;self.ruleID=ruleID;self.priority=priority;self.originalTiming=originalTiming;self.resolvedTiming=resolvedTiming;self.status=status;self.adjustmentReasons=adjustmentReasons }
}
public struct ResolvedDayPlan: Sendable, Equatable {
    public let id:OperationalDayID; public let generatedAt:Date; public let mode:DayMode; public let occurrences:[ResolvedOccurrence]
    public init(id:OperationalDayID, generatedAt:Date, mode:DayMode, occurrences:[ResolvedOccurrence]){ self.id=id;self.generatedAt=generatedAt;self.mode=mode;self.occurrences=occurrences }
}
