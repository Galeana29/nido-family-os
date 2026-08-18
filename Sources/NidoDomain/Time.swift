import Foundation

/// Wall-clock intent as authored in a routine template, e.g. bedtime 19:30.
///
/// Template meaning is local wall clock, never a stored absolute instant: an anchor of 19:30 stays
/// 19:30 across a DST change, while elapsed offsets stay elapsed. See `docs/architecture/time-semantics.md`.
public struct WallClock: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Parses `HH:mm`. Returns nil rather than trapping so fixture/template input can be validated.
    public init?(_ text: String) {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var minutesFromMidnight: Int { hour * 60 + minute }

    public var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static func < (lhs: WallClock, rhs: WallClock) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }
}

/// Converts wall-clock template intent into instants on one operational day.
public struct DayClock {
    public let day: LocalDate
    public let timeZone: TimeZone
    private let calendar: Calendar

    public init(day: LocalDate, timeZone: TimeZone) {
        self.day = day
        self.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    /// Instant for a wall clock on this day's anchor date.
    ///
    /// A wall clock inside a spring-forward gap does not exist locally; it resolves forward to the
    /// first instant that does, so a routine anchored in the gap still lands on a real time.
    public func instant(_ wallClock: WallClock) -> Date {
        var probe = wallClock.minutesFromMidnight
        while probe < 24 * 60 {
            if let date = date(hour: probe / 60, minute: probe % 60) { return date }
            probe += 1
        }
        return date(hour: 0, minute: 0) ?? Date(timeIntervalSince1970: 0)
    }

    /// Wall clock for an instant, for rendering and for comparing against template intent.
    public func wallClock(of instant: Date) -> WallClock {
        let components = calendar.dateComponents([.hour, .minute], from: instant)
        return WallClock(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    private func date(hour: Int, minute: Int) -> Date? {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }
}
