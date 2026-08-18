import Foundation

/// Persistence for the event ledger, stated without naming a database.
///
/// This is the seam ADR 0011 turns on: SwiftData with managed CloudKit, SwiftData with a custom sync
/// engine, or SQLite with one, all have to satisfy exactly this and pass the same conformance suite.
/// The domain and the resolver never learn which one won.
public protocol EventStore: Sendable {
    /// Records locally produced events and queues them for upload.
    func append(_ events: [LoggedEvent]) async throws
    /// Takes in events that arrived from elsewhere. They are already known upstream, so they are not
    /// queued for upload; the report says what changed and what looks duplicated.
    @discardableResult
    func receive(_ events: [LoggedEvent]) async throws -> MergeReport

    func allEvents() async throws -> [LoggedEvent]
    func events(in interval: DateInterval) async throws -> [LoggedEvent]
    func event(id: EventID) async throws -> LoggedEvent?
    /// The current revision of everything that still stands, ready for the resolver.
    func ledger() async throws -> EventLedger

    /// The outbox: what this device still owes the cloud.
    func pendingUploads() async throws -> [LoggedEvent]
    func markUploaded(_ ids: [EventID]) async throws
}

extension EventStore {
    /// Convenience for the common path: validate a command, record what it produced, return it.
    @discardableResult
    public func apply(_ command: any LoggedEventCommand, now: Date) async throws -> [LoggedEvent] {
        var ledger = try await self.ledgerIncludingSuperseded()
        let produced = try ledger.apply(command, now: now)
        if !produced.isEmpty { try await append(produced) }
        return produced
    }

    /// Command validation needs the whole ledger, including revisions that no longer stand, so a
    /// retried command is still recognised as already applied.
    func ledgerIncludingSuperseded() async throws -> EventLedger {
        EventLedger(events: try await allEvents())
    }
}
