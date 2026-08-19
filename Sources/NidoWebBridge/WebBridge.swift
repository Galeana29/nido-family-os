import Foundation
import NidoDomain
import NidoPersistence
import NidoRoutineEngine
import NidoScenario
import NidoTodayFeature

// The engine, reachable from a browser.
//
// This target exists because the caregiver we are building for does not own a Mac. Compiled to
// WebAssembly it runs the same NidoRoutineEngine and TodayPresenter the iOS app will run, so the
// web build can never disagree with the phone about what the day says.
//
// It is a pure function on purpose: one JSON request in on stdin, one JSON response out on stdout.
// Durability lives in the browser, where the event log is the source of truth. That keeps the web
// build local-first and keeps ADR 0011 open, because nothing here picks a database.

// MARK: - Wire format

struct OverrideDTO: Codable {
    let ruleID: UUID
    let kind: String       // "delay" or "skip"
    let minutes: Int?
    let decidedAt: Date
}

struct ActionDTO: Codable {
    let kind: String       // startSleep | endSleep | startMeal | finishMeal | rateMeal | delay | skip
    let ruleID: UUID?
    let minutes: Int?
    let rating: String?
}

struct Request: Codable {
    /// The scenario fixture, passed as text so the module never needs a filesystem.
    let fixture: String
    /// The ledger held by the browser. Absent on the first run, when the fixture seeds the day.
    let events: [LoggedEvent]?
    let overrides: [OverrideDTO]?
    /// Rule id to the preferred time the caregiver was last shown. Feeds the anti-churn rule in the
    /// resolver so a re-render never nudges a time by a couple of minutes for no reason.
    let previousPreferred: [String: Date]?
    let now: Date?
    let language: String?
    let mode: String?
    let action: ActionDTO?
}

struct NowCardDTO: Codable {
    let ruleID: UUID
    let eyebrow: String
    let title: String
    let timeRange: String
    let statusLabel: String
    let primaryAction: ActionDTO
    let primaryActionLabel: String
    let explanation: String?
    let isActive: Bool
}

struct NextItemDTO: Codable {
    let ruleID: UUID
    let time: String
    let title: String
    let statusLabel: String
    let wasAdjusted: Bool
}

struct ScreenDTO: Codable {
    let greeting: String
    let dateLine: String
    let dayState: String
    let now: NowCardDTO?
    let next: [NextItemDTO]
    let notices: [String]
}

struct DayEntryDTO: Codable {
    let ruleID: UUID
    let time: String
    let timeRange: String
    let title: String
    let statusLabel: String
    let wasAdjusted: Bool
    let isCurrent: Bool
    let isSettled: Bool
    let action: ActionDTO
    let actionLabel: String
    let explanation: String?
}

struct RuleDTO: Codable {
    let ruleID: UUID
    let name: String
    let category: String
}

struct Response: Codable {
    let ok: Bool
    let error: String?
    /// The instant this screen was resolved at. The first call has no clock of its own, so this is
    /// how a client learns where the day starts without doing timezone arithmetic of its own.
    let now: Date?
    let screen: ScreenDTO?
    let events: [LoggedEvent]?
    let overrides: [OverrideDTO]?
    let previousPreferred: [String: Date]?
    let rules: [RuleDTO]?
    /// The whole day, not just what is next. A caregiver logging a snack at 15:40 should not have to
    /// wait for the snack to become the hero.
    let day: [DayEntryDTO]?
}

// MARK: - Translation

enum BridgeError: Error, CustomStringConvertible {
    case message(String)
    var description: String {
        if case .message(let text) = self { return text }
        return "bridge error"
    }
}

func todayAction(from dto: ActionDTO) throws -> TodayAction {
    guard let raw = dto.ruleID else { throw BridgeError.message("action \(dto.kind) needs a ruleID") }
    let ruleID = RuleID(raw)
    switch dto.kind {
    case "startSleep": return .startSleep(ruleID)
    case "endSleep": return .endSleep(ruleID)
    case "startMeal": return .startMeal(ruleID)
    case "finishMeal": return .finishMeal(ruleID)
    case "rateMeal":
        guard let rating = MealRating(rawValue: dto.rating ?? "") else {
            throw BridgeError.message("unknown meal rating")
        }
        return .rateMeal(ruleID, rating)
    case "delay": return .delay(ruleID, minutes: dto.minutes ?? 15)
    case "skip": return .skip(ruleID)
    default: throw BridgeError.message("unknown action \(dto.kind)")
    }
}

func actionDTO(from action: TodayAction) -> ActionDTO {
    switch action {
    case .startSleep(let id): return ActionDTO(kind: "startSleep", ruleID: id.rawValue, minutes: nil, rating: nil)
    case .endSleep(let id): return ActionDTO(kind: "endSleep", ruleID: id.rawValue, minutes: nil, rating: nil)
    case .startMeal(let id): return ActionDTO(kind: "startMeal", ruleID: id.rawValue, minutes: nil, rating: nil)
    case .finishMeal(let id): return ActionDTO(kind: "finishMeal", ruleID: id.rawValue, minutes: nil, rating: nil)
    case .rateMeal(let id, let rating): return ActionDTO(kind: "rateMeal", ruleID: id.rawValue, minutes: nil, rating: rating.rawValue)
    case .delay(let id, let minutes): return ActionDTO(kind: "delay", ruleID: id.rawValue, minutes: minutes, rating: nil)
    case .skip(let id): return ActionDTO(kind: "skip", ruleID: id.rawValue, minutes: nil, rating: nil)
    }
}

func manualOverrides(from dtos: [OverrideDTO]) throws -> [ManualOverride] {
    try dtos.map { dto in
        switch dto.kind {
        case "delay":
            return ManualOverride(ruleID: RuleID(dto.ruleID), kind: .delay(minutes: dto.minutes ?? 15), decidedAt: dto.decidedAt)
        case "skip":
            return ManualOverride(ruleID: RuleID(dto.ruleID), kind: .skip, decidedAt: dto.decidedAt)
        default:
            throw BridgeError.message("unknown override \(dto.kind)")
        }
    }
}

func overrideDTOs(from overrides: [ManualOverride]) -> [OverrideDTO] {
    overrides.compactMap { override in
        switch override.kind {
        case .delay(let minutes):
            return OverrideDTO(ruleID: override.ruleID.rawValue, kind: "delay", minutes: minutes, decidedAt: override.decidedAt)
        case .skip:
            return OverrideDTO(ruleID: override.ruleID.rawValue, kind: "skip", minutes: nil, decidedAt: override.decidedAt)
        // moveTo and complete cannot be produced by Today yet. They are dropped rather than guessed,
        // and the day Today offers them this switch has to grow with it.
        case .moveTo, .complete:
            return nil
        }
    }
}

/// The resolver reads only ruleID and resolvedTiming.preferred back out of a previous plan, so that
/// is all the browser has to carry between two calls.
func carriedPlan(from map: [String: Date], day: OperationalDayID, mode: DayMode) -> ResolvedDayPlan? {
    guard !map.isEmpty else { return nil }
    let occurrences: [ResolvedOccurrence] = map.compactMap { key, preferred in
        guard let uuid = UUID(uuidString: key) else { return nil }
        let timing = ResolvedTiming(earliest: preferred, preferred: preferred, latest: preferred)
        return ResolvedOccurrence(
            id: OccurrenceID(uuid),
            ruleID: RuleID(uuid),
            priority: .p2ImportantRoutine,
            originalTiming: timing,
            resolvedTiming: timing,
            status: .upcoming,
            adjustmentReasons: []
        )
    }
    guard let generatedAt = occurrences.map({ $0.resolvedTiming.preferred }).min() else { return nil }
    return ResolvedDayPlan(id: day, generatedAt: generatedAt, mode: mode, occurrences: occurrences)
}

func screenDTO(_ screen: TodayScreen) -> ScreenDTO {
    ScreenDTO(
        greeting: screen.greeting,
        dateLine: screen.dateLine,
        dayState: screen.dayState,
        now: screen.now.map { card in
            NowCardDTO(
                ruleID: card.ruleID.rawValue,
                eyebrow: card.eyebrow,
                title: card.title,
                timeRange: card.timeRange,
                statusLabel: card.statusLabel,
                primaryAction: actionDTO(from: card.primaryAction),
                primaryActionLabel: card.primaryActionLabel,
                explanation: card.explanation,
                isActive: card.isActive
            )
        },
        next: screen.next.map {
            NextItemDTO(
                ruleID: $0.ruleID.rawValue,
                time: $0.time,
                title: $0.title,
                statusLabel: $0.statusLabel,
                wasAdjusted: $0.wasAdjusted
            )
        },
        notices: screen.notices
    )
}

// MARK: - Entry point

@main
struct WebBridge {
    static func main() async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            var text = ""
            while let line = readLine(strippingNewline: false) { text += line }
            guard let data = text.data(using: .utf8), !data.isEmpty else {
                throw BridgeError.message("empty request on stdin")
            }
            let request = try decoder.decode(Request.self, from: data)
            emit(try await respond(to: request), encoder: encoder)
        } catch {
            emit(
                Response(ok: false, error: "\(error)", now: nil, screen: nil, events: nil, overrides: nil, previousPreferred: nil, rules: nil, day: nil),
                encoder: encoder
            )
        }
    }

    static func emit(_ response: Response, encoder: JSONEncoder) {
        if let data = try? encoder.encode(response), let text = String(data: data, encoding: .utf8) {
            print(text)
        } else {
            print("{\"ok\":false,\"error\":\"response could not be encoded\"}")
        }
    }

    static func respond(to request: Request) async throws -> Response {
        guard let fixtureData = request.fixture.data(using: .utf8) else {
            throw BridgeError.message("fixture is not utf8")
        }
        let fixture = try JSONDecoder().decode(ScenarioFixture.self, from: fixtureData)
        let seed = try fixture.makeInput()

        let events = request.events ?? seed.events
        let mode = request.mode.flatMap(DayMode.init(rawValue:)) ?? seed.mode
        let language = request.language.flatMap(Language.init(rawValue:)) ?? .spanish
        let now = request.now ?? seed.currentTime
        let household = events.first?.householdID ?? seed.events.first?.householdID ?? HouseholdID()

        let store = TodayStore(
            store: InMemoryEventStore(events: events),
            template: seed.template,
            household: household,
            operationalDay: seed.operationalDay,
            timeZone: seed.timeZone,
            commitments: seed.commitments,
            careConstraints: seed.careConstraints,
            mode: mode,
            overrides: try manualOverrides(from: request.overrides ?? []),
            previousPlan: carriedPlan(from: request.previousPreferred ?? [:], day: seed.operationalDay, mode: mode)
        )

        if let dto = request.action {
            try await store.perform(todayAction(from: dto), now: now)
        }

        let result = try await store.resolve(now: now)
        let presenter = TodayPresenter(timeZone: seed.timeZone, language: language)
        let screen = presenter.screen(for: result, template: seed.template, now: now)
        let day = presenter.day(for: result, template: seed.template, now: now).map { entry in
            DayEntryDTO(
                ruleID: entry.ruleID.rawValue,
                time: entry.time,
                timeRange: entry.timeRange,
                title: entry.title,
                statusLabel: entry.statusLabel,
                wasAdjusted: entry.wasAdjusted,
                isCurrent: entry.isCurrent,
                isSettled: entry.isSettled,
                action: actionDTO(from: entry.action),
                actionLabel: entry.actionLabel,
                explanation: entry.explanation
            )
        }

        var carried: [String: Date] = [:]
        for occurrence in result.plan.occurrences {
            carried[occurrence.ruleID.rawValue.uuidString] = occurrence.resolvedTiming.preferred
        }

        return Response(
            ok: true,
            error: nil,
            now: now,
            screen: screenDTO(screen),
            events: try await store.currentEvents(),
            overrides: overrideDTOs(from: await store.currentOverrides()),
            previousPreferred: carried,
            rules: seed.template.rules.map { RuleDTO(ruleID: $0.id.rawValue, name: $0.name, category: $0.category.rawValue) },
            day: day
        )
    }
}
