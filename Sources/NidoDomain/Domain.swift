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
public struct LoggedEvent: Codable, Sendable, Equatable {
    public let id: EventID; public let householdID: HouseholdID; public let personID: PersonID?; public let logicalSessionID: SessionID?
    public let type: EventType; public let startedAt: Date; public let endedAt: Date?; public let source: EventSource; public let createdBy: PersonID?
    public let createdAt: Date; public let modifiedAt: Date; public let revision: Int; public let deletedAt: Date?
    public init(id:EventID=EventID(), householdID:HouseholdID, personID:PersonID?=nil, logicalSessionID:SessionID?=nil, type:EventType, startedAt:Date, endedAt:Date?=nil, source:EventSource, createdBy:PersonID?=nil, createdAt:Date, modifiedAt:Date, revision:Int=1, deletedAt:Date?=nil){ self.id=id;self.householdID=householdID;self.personID=personID;self.logicalSessionID=logicalSessionID;self.type=type;self.startedAt=startedAt;self.endedAt=endedAt;self.source=source;self.createdBy=createdBy;self.createdAt=createdAt;self.modifiedAt=modifiedAt;self.revision=revision;self.deletedAt=deletedAt }
}
public enum TimingRule: Sendable, Equatable { case exact(Date); case anchor(earliest:Date,preferred:Date,latest:Date); case window(earliest:Date,preferred:Date,latest:Date); case relative(reference:OccurrenceID,minMinutes:Int,preferredMinutes:Int,maxMinutes:Int); case dependent(reference:OccurrenceID,minMinutes:Int,preferredMinutes:Int,maxMinutes:Int) }
public enum AdjustmentPolicy: Sendable, Equatable { case durationResponsive(reference:OccurrenceID,thresholdMinutes:Int,shiftMinutes:Int); case externalConflict, modePolicy, manualOverride }
public enum AdjustmentReason: Sendable, Equatable { case dependencyResolved(reference:OccurrenceID); case retainedForStability(deltaMinutes:Int); case shortDuration(reference:OccurrenceID,minutes:Int); case externalCommitmentConflict, manualOverride }
public struct ResolvedTiming: Sendable, Equatable { public let earliest:Date; public let preferred:Date; public let latest:Date; public init(earliest:Date,preferred:Date,latest:Date){ precondition(earliest <= preferred && preferred <= latest); self.earliest=earliest;self.preferred=preferred;self.latest=latest } }
public struct ResolvedOccurrence: Sendable, Equatable { public let id:OccurrenceID; public let ruleID:RuleID; public let priority:RoutinePriority; public let timing:ResolvedTiming; public let status:OccurrenceStatus; public let adjustmentReasons:[AdjustmentReason] }
public struct ResolvedDayPlan: Sendable, Equatable { public let id:OperationalDayID; public let generatedAt:Date; public let mode:DayMode; public let occurrences:[ResolvedOccurrence] }
