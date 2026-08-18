import XCTest
import Foundation
@testable import NidoDomain

final class DomainPayloadTests:XCTestCase {
    func testLoggedEventPayloadRoundTripsThroughCodable() throws {
        let t=Date(timeIntervalSince1970:1_000)
        let event=LoggedEvent(householdID:HouseholdID(),type:.breastfeedStarted,startedAt:t,source:.app,createdAt:t,modifiedAt:t,payload:.breastfeed(context:.comfort,planned:false))
        let decoded=try JSONDecoder().decode(LoggedEvent.self,from:try JSONEncoder().encode(event))
        XCTAssertEqual(decoded,event)
        guard case .breastfeed(let context,let planned)=decoded.payload else { return XCTFail("payload lost in round trip") }
        XCTAssertEqual(context,.comfort); XCTAssertFalse(planned)
    }
    func testMealRatedPayloadCarriesQuantityRating() throws {
        let t=Date(timeIntervalSince1970:2_000)
        let event=LoggedEvent(householdID:HouseholdID(),type:.mealRated,startedAt:t,source:.watch,createdAt:t,modifiedAt:t,payload:.mealRated(rating:.small,foods:["banana"],behaviors:[.distracted],notes:nil))
        let decoded=try JSONDecoder().decode(LoggedEvent.self,from:try JSONEncoder().encode(event))
        guard case .mealRated(let rating,let foods,let behaviors,let notes)=decoded.payload else { return XCTFail("payload lost in round trip") }
        XCTAssertEqual(rating,.small); XCTAssertEqual(foods,["banana"]); XCTAssertEqual(behaviors,[.distracted]); XCTAssertNil(notes)
    }
    func testPayloadDefaultsToNoneSoDetailIsNeverMandatory() {
        let t=Date(timeIntervalSince1970:3_000)
        let event=LoggedEvent(householdID:HouseholdID(),type:.napStarted,startedAt:t,source:.widget,createdAt:t,modifiedAt:t)
        XCTAssertEqual(event.payload,.none)
    }
}
