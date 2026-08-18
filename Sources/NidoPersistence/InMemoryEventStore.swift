import Foundation
import NidoDomain

/// A complete, correct `EventStore` that happens to forget everything when the process exits.
///
/// It exists so the rest of the system can be built and tested at full speed while ADR 0011 is still
/// open, and so the conformance suite has something to prove itself against. When a real store lands
/// it has to pass exactly the same tests as this one.
public actor InMemoryEventStore: EventStore {
    private var storage: [EventID: LoggedEvent] = [:]
    private var pending: Set<EventID> = []

    public init(events: [LoggedEvent] = []) {
        for event in events { storage[event.id] = event }
    }

    public func append(_ events: [LoggedEvent]) async throws {
        for event in events {
            guard storage[event.id] == nil else { continue }
            storage[event.id] = event
            pending.insert(event.id)
        }
    }

    @discardableResult
    public func receive(_ events: [LoggedEvent]) async throws -> MergeReport {
        let report = LedgerReconciler.merge(Array(storage.values), events)
        for event in report.events { storage[event.id] = event }
        return report
    }

    public func allEvents() async throws -> [LoggedEvent] {
        LedgerProjection.inCanonicalOrder(Array(storage.values))
    }

    public func events(in interval: DateInterval) async throws -> [LoggedEvent] {
        try await allEvents().filter { interval.contains($0.startedAt) }
    }

    public func event(id: EventID) async throws -> LoggedEvent? {
        storage[id]
    }

    public func ledger() async throws -> EventLedger {
        EventLedger(events: try await allEvents())
    }

    public func pendingUploads() async throws -> [LoggedEvent] {
        LedgerProjection.inCanonicalOrder(pending.compactMap { storage[$0] })
    }

    public func markUploaded(_ ids: [EventID]) async throws {
        for id in ids { pending.remove(id) }
    }
}
