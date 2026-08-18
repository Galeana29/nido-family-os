import Foundation
import NidoDomain
import NidoPersistence
import NidoRoutineEngine
import NidoScenario
import NidoTodayFeature

// Today, running against the canonical imperfect day. `swift run NidoToday` on a Mac opens it; no
// Xcode project needed yet. The clock is simulated so the day can be walked through in a minute
// instead of a day, and every tap goes through the same commands the real app will use.

#if canImport(SwiftUI)
import SwiftUI
import Combine

@MainActor
final class TodayModel: ObservableObject {
    @Published var screen: TodayScreen?
    @Published var language: Language = .spanish
    @Published var now: Date
    @Published var failure: String?

    private let store: TodayStore

    init() {
        do {
            let fixture = try ScenarioFixture.load(from: ScenarioLocator.canonicalDayFixture)
            let input = try fixture.makeInput()
            self.now = input.currentTime
            self.store = TodayStore(
                store: InMemoryEventStore(events: input.events),
                template: input.template,
                household: input.events.first?.householdID ?? HouseholdID(),
                operationalDay: input.operationalDay,
                timeZone: input.timeZone,
                commitments: input.commitments
            )
        } catch {
            self.now = Date(timeIntervalSince1970: 0)
            self.store = TodayStore(
                store: InMemoryEventStore(),
                template: RoutineTemplate(id: RoutineTemplateID(), version: 1, rules: []),
                household: HouseholdID(),
                operationalDay: OperationalDayID(anchorDate: LocalDate(year: 2026, month: 8, day: 17)),
                timeZone: TimeZone(identifier: "America/Vancouver") ?? .gmt
            )
            self.failure = "Could not load the canonical day: \(error)"
        }
    }

    func refresh() async {
        do {
            screen = try await store.screen(now: now, language: language)
            failure = nil
        } catch {
            failure = "\(error)"
        }
    }

    func perform(_ action: TodayAction) async {
        do {
            try await store.perform(action, now: now)
        } catch {
            failure = "\(error)"
        }
        await refresh()
    }

    func advance(minutes: Int) async {
        now = now.addingTimeInterval(TimeInterval(minutes * 60))
        await refresh()
    }
}

struct RootView: View {
    @StateObject private var model = TodayModel()

    var body: some View {
        VStack(spacing: 0) {
            if let screen = model.screen {
                TodayView(screen: screen) { action in
                    Task { await model.perform(action) }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let failure = model.failure {
                Text(failure)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.red)
                    .padding(8)
            }
            simulationControls
        }
        .frame(minWidth: 380, minHeight: 620)
        .task { await model.refresh() }
    }

    /// Not part of the product: a way to walk a whole day in a minute while there is no real clock.
    private var simulationControls: some View {
        HStack(spacing: 12) {
            Button("+15 min") { Task { await model.advance(minutes: 15) } }
            Button("+1 h") { Task { await model.advance(minutes: 60) } }
            Spacer()
            Picker("", selection: $model.language) {
                Text("ES").tag(Language.spanish)
                Text("EN").tag(Language.english)
            }
            .pickerStyle(.segmented)
            .frame(width: 110)
            .onChange(of: model.language) { Task { await model.refresh() } }
        }
        .padding(12)
        .background(NidoTheme.soft)
    }
}

@main
struct NidoTodayApp: App {
    var body: some Scene {
        WindowGroup("NIDO — Today") {
            RootView()
        }
    }
}

#else

@main
struct NidoTodayApp {
    static func main() {
        print("Today needs SwiftUI. The presentation layer it renders is in NidoTodayFeature and is tested on this platform.")
    }
}

#endif
