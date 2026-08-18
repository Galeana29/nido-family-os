import Foundation
import NidoDomain
import NidoRoutineEngine

public enum ScenarioError: Error, Equatable {
    case malformedTime(String)
    case malformedDate(String)
    case unknownPriority(String)
    case unknownEventType(String)
    case unknownTimingRule(String)
    case unknownPayload(String)
    case unknownOverride(String)
    case fixtureNotFound(String)
}

/// Decodes `examples/sample-day.json` into engine input.
///
/// The fixture holds inputs only. Expected output is never stored here: it is produced by the engine
/// and reviewed as a golden snapshot, so a handwritten number can never masquerade as a result again.
public struct ScenarioFixture: Decodable, Sendable {
    public let date: String
    public let timezone: String
    public let mode: String
    public let currentTime: String
    public let planned: [PlannedRule]
    public let externalCommitments: [Commitment]
    public let events: [Event]
    public let manualOverrides: [Override]?

    public struct WindowSpec: Decodable, Sendable {
        public let earliest: String
        public let preferred: String
        public let latest: String
    }

    public struct OffsetSpec: Decodable, Sendable {
        public let min: Int
        public let preferred: Int
        public let max: Int
    }

    public struct DependsOn: Decodable, Sendable {
        public let rule: String
        public let kind: String
        public let offsetMinutes: OffsetSpec
    }

    public struct PolicySpec: Decodable, Sendable {
        public let type: String
        public let reference: String
        public let shortfallMinutes: Int
        public let shiftMinutes: Int
    }

    public struct PlannedRule: Decodable, Sendable {
        public let id: String
        public let name: String
        public let category: String
        public let priority: String
        public let durationMinutes: Int?
        public let exact: String?
        public let anchor: WindowSpec?
        public let window: WindowSpec?
        public let dependsOn: DependsOn?
        public let adjustmentPolicies: [PolicySpec]?
    }

    public struct Commitment: Decodable, Sendable {
        public let id: String
        public let start: String
        public let end: String
        public let priority: String
    }

    public struct PayloadSpec: Decodable, Sendable {
        public let kind: String
        public let rating: String?
        public let sleepType: String?
        public let assistance: String?
        public let context: String?
        public let planned: Bool?
        public let kilograms: Double?
        public let text: String?
    }

    public struct Event: Decodable, Sendable {
        public let type: String
        public let at: String
        public let rule: String?
        public let session: String?
        public let payload: PayloadSpec?
    }

    public struct Override: Decodable, Sendable {
        public let rule: String
        public let kind: String
        public let at: String?
        public let minutes: Int?
        public let decidedAt: String
    }
}

extension ScenarioFixture {
    public static func load(from url: URL) throws -> ScenarioFixture {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScenarioFixture.self, from: data)
    }

    public var localDate: LocalDate {
        get throws {
            let parts = date.split(separator: "-")
            guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
                throw ScenarioError.malformedDate(date)
            }
            return LocalDate(year: year, month: month, day: day)
        }
    }

    public func makeTemplate() throws -> RoutineTemplate {
        let rules = try planned.map { spec -> RoutineRule in
            RoutineRule(
                id: Self.ruleID(spec.id),
                name: spec.name,
                category: RoutineCategory(rawValue: spec.category) ?? .other,
                timing: try Self.timing(for: spec),
                priority: try Self.priority(spec.priority),
                duration: spec.durationMinutes.map { DurationRange(expectedMinutes: $0) },
                adjustmentPolicies: (spec.adjustmentPolicies ?? []).map {
                    .durationResponsive(reference: Self.ruleID($0.reference), shortfallMinutes: $0.shortfallMinutes, shiftMinutes: $0.shiftMinutes)
                }
            )
        }
        return RoutineTemplate(id: RoutineTemplateID(Self.stableUUID("template")), version: 1, rules: rules)
    }

    public func makeInput() throws -> ResolutionInput {
        let day = try localDate
        guard let timeZone = TimeZone(identifier: timezone) else { throw ScenarioError.malformedDate(timezone) }
        let clock = DayClock(day: day, timeZone: timeZone)
        let household = HouseholdID(Self.stableUUID("household"))

        let commitments = try externalCommitments.map { spec in
            ExternalCommitment(
                id: ExternalCommitmentID(Self.stableUUID("commitment:" + spec.id)),
                start: clock.instant(try Self.wallClock(spec.start)),
                end: clock.instant(try Self.wallClock(spec.end)),
                priority: try Self.priority(spec.priority)
            )
        }

        // Reality is replayed through the command layer, exactly as a caregiver's taps would be.
        // Nothing here can assemble an event by hand, so a fixture that describes an impossible day —
        // a nap that ends without starting — fails to load rather than resolving into nonsense.
        var ledger = EventLedger()
        var latestEventTime = clock.instant(WallClock(hour: 0, minute: 0))
        for spec in self.events {
            let at = clock.instant(try Self.wallClock(spec.at))
            latestEventTime = max(latestEventTime, at)
            try ledger.apply(try Self.command(spec, at: at, household: household), now: latestEventTime)
        }
        let events = ledger.effectiveEvents

        let overrides = try (manualOverrides ?? []).map { spec -> ManualOverride in
            ManualOverride(
                ruleID: Self.ruleID(spec.rule),
                kind: try Self.overrideKind(spec),
                decidedAt: clock.instant(try Self.wallClock(spec.decidedAt))
            )
        }

        return ResolutionInput(
            operationalDay: OperationalDayID(anchorDate: day),
            timeZone: timeZone,
            mode: DayMode(rawValue: mode) ?? .normal,
            template: try makeTemplate(),
            commitments: commitments,
            events: events,
            overrides: overrides,
            currentTime: clock.instant(try Self.wallClock(currentTime))
        )
    }

    // MARK: - Mapping helpers

    static func wallClock(_ text: String) throws -> WallClock {
        guard let value = WallClock(text) else { throw ScenarioError.malformedTime(text) }
        return value
    }

    static func priority(_ text: String) throws -> RoutinePriority {
        switch text {
        case "P0": return .p0SafetyLockedCare
        case "P1": return .p1AnchorExternalCommitment
        case "P2": return .p2ImportantRoutine
        case "P3": return .p3Flexible
        case "P4": return .p4Optional
        default: throw ScenarioError.unknownPriority(text)
        }
    }

    static func timing(for spec: PlannedRule) throws -> TimingRule {
        if let exact = spec.exact {
            return .exact(try wallClock(exact))
        }
        if let anchor = spec.anchor {
            return .anchor(earliest: try wallClock(anchor.earliest), preferred: try wallClock(anchor.preferred), latest: try wallClock(anchor.latest))
        }
        if let window = spec.window {
            return .window(earliest: try wallClock(window.earliest), preferred: try wallClock(window.preferred), latest: try wallClock(window.latest))
        }
        if let dependsOn = spec.dependsOn {
            let reference = ruleID(dependsOn.rule)
            let offsets = dependsOn.offsetMinutes
            switch dependsOn.kind {
            case "dependent":
                return .dependent(reference: reference, minMinutes: offsets.min, preferredMinutes: offsets.preferred, maxMinutes: offsets.max)
            case "relative":
                return .relative(reference: reference, minMinutes: offsets.min, preferredMinutes: offsets.preferred, maxMinutes: offsets.max)
            default:
                throw ScenarioError.unknownTimingRule(dependsOn.kind)
            }
        }
        throw ScenarioError.unknownTimingRule(spec.id)
    }

    /// Maps a fixture event onto the command a caregiver would have issued.
    static func command(_ spec: Event, at occurredAt: Date, household: HouseholdID) throws -> any LoggedEventCommand {
        let rule = spec.rule.map { ruleID($0) }
        let commandID = CommandID(stableUUID("command:" + spec.type + ":" + spec.at))

        switch spec.type {
        case "childWoke":
            return RecordWakeCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule)
        case "napStarted", "nightSleepStarted":
            return StartSleepCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule, sleepType: sleepType(spec), assistance: assistance(spec))
        case "napEnded", "nightSleepEnded":
            return EndSleepCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule, sleepType: sleepType(spec))
        case "mealStarted":
            return StartMealCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule)
        case "mealEnded":
            return EndMealCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule)
        case "mealRated":
            guard let raw = spec.payload?.rating, let rating = MealRating(rawValue: raw) else {
                throw ScenarioError.unknownPayload(spec.type)
            }
            return RateMealCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule, rating: rating)
        case "breastfeedStarted":
            return StartNursingCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule, context: context(spec), planned: spec.payload?.planned ?? false)
        case "breastfeedEnded":
            return EndNursingCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, ruleID: rule, context: context(spec), planned: spec.payload?.planned ?? false)
        case "diaperChanged":
            return LogDiaperCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app)
        case "waterLogged":
            return LogWaterCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app)
        case "modeChanged":
            return ChangeDayModeCommand(commandID: commandID, householdID: household, occurredAt: occurredAt, source: .app, mode: DayMode(rawValue: spec.payload?.text ?? "normal") ?? .normal)
        default:
            throw ScenarioError.unknownEventType(spec.type)
        }
    }

    private static func sleepType(_ spec: Event) -> SleepType {
        spec.payload?.sleepType.flatMap { SleepType(rawValue: $0) } ?? .other
    }

    private static func assistance(_ spec: Event) -> SleepAssistance? {
        spec.payload?.assistance.flatMap { SleepAssistance(rawValue: $0) }
    }

    private static func context(_ spec: Event) -> BreastfeedContext {
        spec.payload?.context.flatMap { BreastfeedContext(rawValue: $0) } ?? .other
    }

    static func payload(_ spec: PayloadSpec?) throws -> EventPayload {
        guard let spec else { return .none }
        switch spec.kind {
        case "mealRated":
            guard let raw = spec.rating, let rating = MealRating(rawValue: raw) else { throw ScenarioError.unknownPayload(spec.kind) }
            return .mealRated(rating: rating, foods: [], behaviors: [], notes: nil)
        case "sleep":
            let type = spec.sleepType.flatMap { SleepType(rawValue: $0) } ?? .other
            return .sleep(type: type, assistance: spec.assistance.flatMap { SleepAssistance(rawValue: $0) })
        case "breastfeed":
            let context = spec.context.flatMap { BreastfeedContext(rawValue: $0) } ?? .other
            return .breastfeed(context: context, planned: spec.planned ?? false)
        case "weight":
            guard let kilograms = spec.kilograms else { throw ScenarioError.unknownPayload(spec.kind) }
            return .weight(kilograms: kilograms)
        case "healthNote":
            guard let text = spec.text else { throw ScenarioError.unknownPayload(spec.kind) }
            return .healthNote(text: text)
        default:
            throw ScenarioError.unknownPayload(spec.kind)
        }
    }

    static func overrideKind(_ spec: Override) throws -> ManualOverrideKind {
        switch spec.kind {
        case "skip": return .skip
        case "complete": return .complete
        case "delay":
            guard let minutes = spec.minutes else { throw ScenarioError.unknownOverride(spec.kind) }
            return .delay(minutes: minutes)
        case "moveTo":
            guard let at = spec.at else { throw ScenarioError.unknownOverride(spec.kind) }
            return .moveTo(try wallClock(at))
        default:
            throw ScenarioError.unknownOverride(spec.kind)
        }
    }

    public static func ruleID(_ name: String) -> RuleID { RuleID(stableUUID("rule:" + name)) }

    /// Identifiers derived from fixture names rather than randomly generated, so resolving the same
    /// scenario twice produces byte-identical output and snapshots stay reviewable.
    public static func stableUUID(_ text: String) -> UUID {
        func fnv1a(_ input: String) -> UInt64 {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in input.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x100_0000_01b3
            }
            return hash
        }
        let low = fnv1a(text)
        let high = fnv1a(text + "|nido")
        var bytes: [UInt8] = []
        for shift in 0..<8 { bytes.append(UInt8((low >> (8 * UInt64(shift))) & 0xff)) }
        for shift in 0..<8 { bytes.append(UInt8((high >> (8 * UInt64(shift))) & 0xff)) }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

/// Finds the canonical fixture in the repository rather than a copy inside the test bundle, so the
/// file the docs point at is the file the engine is actually tested against.
public enum ScenarioLocator {
    public static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Sources/NidoScenario
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // repository root
    }

    public static var canonicalDayFixture: URL {
        repositoryRoot.appendingPathComponent("examples/sample-day.json")
    }

    public static var goldenSnapshot: URL {
        repositoryRoot.appendingPathComponent("examples/sample-day.snapshot.txt")
    }
}
