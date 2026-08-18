import XCTest
import Foundation
@testable import NidoDomain

final class TimeSemanticsTests:XCTestCase {
    func testOperationalDayUsesLocalPrimaryWakeDate() throws { let tz=try XCTUnwrap(TimeZone(identifier:"America/Vancouver")); var c=Calendar(identifier:.gregorian);c.timeZone=tz;let w=try XCTUnwrap(c.date(from:DateComponents(year:2026,month:8,day:18,hour:6,minute:58))); XCTAssertEqual(OperationalDay.id(openedByPrimaryWake:w,timeZone:tz).anchorDate,LocalDate(year:2026,month:8,day:18)) }
    func testSpringForwardElapsedDurationUsesInstants() throws { let tz=try XCTUnwrap(TimeZone(identifier:"America/Vancouver")); var c=Calendar(identifier:.gregorian);c.timeZone=tz;let before=try XCTUnwrap(c.date(from:DateComponents(year:2026,month:3,day:8,hour:1,minute:30)));let after=before.addingTimeInterval(120*60);XCTAssertEqual(OperationalDay.elapsedMinutes(from:before,to:after),120);XCTAssertEqual(c.component(.hour,from:after),4) }
    func testFallBackAmbiguousWallClockIsTwoDistinctInstants() throws {
        // 2026-11-01 America/Vancouver: 02:00 PDT falls back to 01:00 PST, so the 01:30 wall clock occurs twice.
        let tz=try XCTUnwrap(TimeZone(identifier:"America/Vancouver"))
        var c=Calendar(identifier:.gregorian);c.timeZone=tz
        let firstOneThirty=Date(timeIntervalSince1970:1_793_521_800)   // 08:30Z = 01:30 PDT (UTC-7)
        let secondOneThirty=Date(timeIntervalSince1970:1_793_525_400)  // 09:30Z = 01:30 PST (UTC-8)
        XCTAssertEqual(c.component(.hour,from:firstOneThirty),1);XCTAssertEqual(c.component(.minute,from:firstOneThirty),30)
        XCTAssertEqual(c.component(.hour,from:secondOneThirty),1);XCTAssertEqual(c.component(.minute,from:secondOneThirty),30)
        XCTAssertNotEqual(firstOneThirty,secondOneThirty)
        XCTAssertEqual(OperationalDay.elapsedMinutes(from:firstOneThirty,to:secondOneThirty),60)
    }
}
