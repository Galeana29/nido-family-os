import Foundation
import NidoDomain
import NidoRoutineEngine
import NidoScenario

// Runs the canonical imperfect day and prints the resolved plan, then logs a short second nap and
// prints the re-resolution. Seeing the day reflow is how we find out whether the engine thinks the
// way we intended, long before there is an app to look at.

let arguments = CommandLine.arguments
let fixtureURL = arguments.count > 1 ? URL(fileURLWithPath: arguments[1]) : ScenarioLocator.canonicalDayFixture

func fail(_ message: String) -> Never {
    if let data = (message + "\n").data(using: .utf8) { FileHandle.standardError.write(data) }
    exit(1)
}

do {
    let fixture = try ScenarioFixture.load(from: fixtureURL)
    let input = try fixture.makeInput()
    let engine = RoutineEngine()
    let renderer = SnapshotRenderer(template: input.template, timeZone: input.timeZone)

    let resolved = try engine.resolve(input)
    print(renderer.render(resolved))

    // Reality arrives: the second nap runs 33 minutes instead of the planned 75.
    let clock = DayClock(day: input.operationalDay.anchorDate, timeZone: input.timeZone)
    let nap2 = ScenarioFixture.ruleID("nap2")
    let napStart = clock.instant(WallClock(hour: 15, minute: 1))
    let napEnd = clock.instant(WallClock(hour: 15, minute: 34))
    let household = HouseholdID(ScenarioFixture.stableUUID("household"))

    // DO → LOG → RECALCULATE, through the same command layer the Watch would use.
    var ledger = EventLedger(events: input.events)
    try ledger.apply(StartSleepCommand(householdID: household, occurredAt: napStart, source: .watch, ruleID: nap2, sleepType: .nap2), now: napStart)
    try ledger.apply(EndSleepCommand(householdID: household, occurredAt: napEnd, source: .watch, ruleID: nap2, sleepType: .nap2), now: napEnd)
    let shortNap = ledger.effectiveEvents

    let afterShortNap = ResolutionInput(
        operationalDay: input.operationalDay,
        timeZone: input.timeZone,
        mode: input.mode,
        template: input.template,
        careConstraints: input.careConstraints,
        commitments: input.commitments,
        events: shortNap,
        overrides: input.overrides,
        previousPlan: resolved.plan,
        currentTime: napEnd
    )

    print("--- after logging a short second nap (\(Int(napEnd.timeIntervalSince(napStart) / 60)) min) ---")
    print("")
    print(renderer.render(try engine.resolve(afterShortNap)))
} catch {
    fail("scenario runner failed: \(error)")
}
