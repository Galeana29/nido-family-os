import Foundation

public enum OperationalDay {
    public static func id(openedByPrimaryWake wake: Date, timeZone: TimeZone) -> OperationalDayID {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year,.month,.day], from: wake)
        return OperationalDayID(anchorDate: LocalDate(year:c.year!, month:c.month!, day:c.day!))
    }
    public static func elapsedMinutes(from start:Date,to end:Date)->Int { Int(end.timeIntervalSince(start)/60) }
}
