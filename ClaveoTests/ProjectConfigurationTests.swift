import XCTest
@testable import Claveo

final class ProjectConfigurationTests: XCTestCase {
    func testInvalidTabOrderFallsBackToDefault() {
        XCTAssertEqual(
            AppSettings.normalizedTabBarOrder([0, 0]),
            AppSettings.defaultTabBarCustomizationOrder
        )
    }
}
