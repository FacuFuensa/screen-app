import XCTest
@testable import ScreenCore

final class TourPlanTests: XCTestCase {
    func testFreshInstallStartsWithPermissions() {
        XCTAssertEqual(TourPlan.firstPending(authorized: false, groupCount: 0, paired: false), .permissions)
    }
    func testAuthorizedWithoutLimitsStartsAtNewLimit() {
        XCTAssertEqual(TourPlan.firstPending(authorized: true, groupCount: 0, paired: false), .newLimit)
    }
    func testLimitsButNoPartnerStartsAtInvite() {
        XCTAssertEqual(TourPlan.firstPending(authorized: true, groupCount: 2, paired: false), .invite)
    }
    func testExistingPairedUserSeesNoTour() {
        XCTAssertNil(TourPlan.firstPending(authorized: true, groupCount: 1, paired: true))
    }
    func testStepsAdvanceInOrderAndEnd() {
        XCTAssertEqual(TourPlan.next(after: .permissions), .newLimit)
        XCTAssertEqual(TourPlan.next(after: .save), .invite)
        XCTAssertEqual(TourPlan.next(after: .invite), .share)
        XCTAssertNil(TourPlan.next(after: .share))
    }
    func testInviteAndShareAreBothStepSeven() {
        XCTAssertEqual(TourStep.invite.number, 7)
        XCTAssertEqual(TourStep.share.number, 7)
        XCTAssertEqual(TourStep.total, 7)
    }
}
