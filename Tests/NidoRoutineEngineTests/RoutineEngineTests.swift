import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

final class RoutineEngineTests:XCTestCase {
    private let tz=TimeZone(identifier:"America/Vancouver")!
    private func date(_ v:String)throws->Date { let f=DateFormatter();f.calendar=Calendar(identifier:.gregorian);f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=tz;f.dateFormat="yyyy-MM-dd HH:mm";return try XCTUnwrap(f.date(from:v)) }
    func testCanonicalNap2WindowIsComputedNotHandWaved() throws { let e=RoutineEngine(); let r=try e.resolveDependent(referenceEnd:try date("2026-08-17 11:31"),minMinutes:195,preferredMinutes:210,maxMinutes:225); XCTAssertEqual(r.earliest,try date("2026-08-17 14:46")); XCTAssertEqual(r.preferred,try date("2026-08-17 15:01")); XCTAssertEqual(r.latest,try date("2026-08-17 15:16")) }
    func testPreviousPlanIsRetainedForImmaterialJitter() throws { let e=RoutineEngine(policy:.init(materialityThresholdMinutes:5)); let p=try date("2026-08-17 15:03"); let r=try e.resolveDependent(referenceEnd:try date("2026-08-17 11:31"),minMinutes:195,preferredMinutes:210,maxMinutes:225,previousPreferred:p); XCTAssertEqual(r.preferred,p) }
    func testPreviousPlanIsNotRetainedOutsideAllowedWindow() throws { let e=RoutineEngine(policy:.init(materialityThresholdMinutes:60)); let r=try e.resolveDependent(referenceEnd:try date("2026-08-17 11:31"),minMinutes:195,preferredMinutes:210,maxMinutes:225,previousPreferred:try date("2026-08-17 14:45")); XCTAssertEqual(r.preferred,try date("2026-08-17 15:01")); XCTAssertGreaterThanOrEqual(r.preferred,r.earliest) }
    func testInvalidOffsetsFailDeterministically() { XCTAssertThrowsError(try RoutineEngine().resolveDependent(referenceEnd:Date(timeIntervalSince1970:0),minMinutes:210,preferredMinutes:195,maxMinutes:225)) }
}
