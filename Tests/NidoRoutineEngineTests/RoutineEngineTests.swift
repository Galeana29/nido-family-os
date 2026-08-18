import XCTest
import Foundation
@testable import NidoDomain
@testable import NidoRoutineEngine

final class RoutineEngineTests:XCTestCase {
    private let tz=TimeZone(identifier:"America/Vancouver")!
    private func date(_ v:String)throws->Date { let f=DateFormatter();f.calendar=Calendar(identifier:.gregorian);f.locale=Locale(identifier:"en_US_POSIX");f.timeZone=tz;f.dateFormat="yyyy-MM-dd HH:mm";return try XCTUnwrap(f.date(from:v)) }
    private func hasStabilityReason(_ r:DependentResolution)->Bool { r.adjustmentReasons.contains{ if case .retainedForStability=$0 {return true}; return false } }
    func testCanonicalNap2WindowIsComputedNotHandWaved() throws { let e=RoutineEngine(); let r=try e.resolveDependent(referenceEnd:try date("2026-08-17 11:31"),minMinutes:195,preferredMinutes:210,maxMinutes:225); XCTAssertEqual(r.timing.earliest,try date("2026-08-17 14:46")); XCTAssertEqual(r.timing.preferred,try date("2026-08-17 15:01")); XCTAssertEqual(r.timing.latest,try date("2026-08-17 15:16")) }
    func testDependencyReferenceIsRecordedAsAdjustmentReason() throws { let ref=OccurrenceID(); let r=try RoutineEngine().resolveDependent(referenceEnd:try date("2026-08-17 11:31"),minMinutes:195,preferredMinutes:210,maxMinutes:225,reference:ref); XCTAssertTrue(r.adjustmentReasons.contains(.dependencyResolved(reference:ref))) }
    func testPreviousPlanIsRetainedForImmaterialJitterAndExplained() throws { let e=RoutineEngine(policy:.init(materialityThresholdMinutes:5)); let p=try date("2026-08-17 15:03"); let r=try e.resolveDependent(referenceEnd:try date("2026-08-17 11:31"),minMinutes:195,preferredMinutes:210,maxMinutes:225,previousPreferred:p); XCTAssertEqual(r.timing.preferred,p); XCTAssertTrue(r.adjustmentReasons.contains(.retainedForStability(deltaMinutes:2))) }
    func testPreviousPlanIsNotRetainedOutsideAllowedWindow() throws { let e=RoutineEngine(policy:.init(materialityThresholdMinutes:60)); let r=try e.resolveDependent(referenceEnd:try date("2026-08-17 11:31"),minMinutes:195,preferredMinutes:210,maxMinutes:225,previousPreferred:try date("2026-08-17 14:45")); XCTAssertEqual(r.timing.preferred,try date("2026-08-17 15:01")); XCTAssertGreaterThanOrEqual(r.timing.preferred,r.timing.earliest); XCTAssertFalse(hasStabilityReason(r)) }
    func testInvalidOffsetsFailDeterministically() { XCTAssertThrowsError(try RoutineEngine().resolveDependent(referenceEnd:Date(timeIntervalSince1970:0),minMinutes:210,preferredMinutes:195,maxMinutes:225)) }
}
