import UserNotifications
import XCTest
@testable import NitroBrew

final class NotifierTests: XCTestCase {
    func testBannerShownEvenWhenAppIsActive() {
        XCTAssertTrue(NotificationPresenter.presentationOptions.contains(.banner))
        XCTAssertTrue(NotificationPresenter.presentationOptions.contains(.list))
    }

    func testUserNotifierInstallsThePresenterAsCenterDelegate() {
        let notifier = UserNotifier()
        XCTAssertTrue(UNUserNotificationCenter.current().delegate is NotificationPresenter)
        _ = notifier
    }
}
