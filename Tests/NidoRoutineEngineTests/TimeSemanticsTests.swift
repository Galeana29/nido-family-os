import XCTest
import Foundation
@testable import NidoDomain

final class TimeSemanticsTests:XCTestCase {
    func testOperationalDayUsesLocalPrimaryWakeDate() throws { let tz=try XCTUnwrap(TimeZone(identifier:"America/Vancouver")); var c=Calendar(identifier:.gregorian);c.timeZone=tz;let w=try XCTUnwrap(c.date(from:DateComponents(year:2026,month:8,day:18,hour:6,minute:58))); XCTAssertEqual(OperationalDay.id(openedByPrimaryWake:w,timeZone:tz).anchorDate,LocalDate(year:2026,month:8,day:18)) }
    func testSpringForwardElapsedDurationUsesInstants() throws { let tz=try XCTUnwrap(TimeZone(identifier:"America/Vancouver")); var c=Calendar(identifier:.gregorian);c.timeZone=tz;let before=try XCTUnwrap(c.date(from:DateComponents(year:2026,month:3,day:8,hour:1,minute:30)));let after=before.addingTimeInterval(120*60);XCTAssertEqual(OperationalDay.elapsedMinutes(from:before,to:after),120);XCTAssertEqual(c.component(.hour,from:after),4) }
    func testFallBackRepeatedHourDoesNotChangeInstantIdentity(){let a=Date(timeIntervalSince1970:1_783_240_200);let b=a.addingTimeInterval(3600);XCTAssertNotEqual(a,b);XCTAssertEqual(OperationalDay.elapsedMinutes(from:a,to:b),60)}
}
