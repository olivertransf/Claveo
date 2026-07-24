import XCTest
@testable import Claveo

final class TunerLifecycleTests: XCTestCase {
    func testStopInvalidatesAnInFlightStart() {
        var lifecycle = TunerLifecycleGate()

        let startToken = lifecycle.requestStart()
        let stopToken = lifecycle.requestStop()

        XCTAssertNotNil(startToken)
        XCTAssertNotNil(stopToken)
        XCTAssertFalse(lifecycle.isCurrent(startToken!, expectingActive: true))
        XCTAssertTrue(lifecycle.isCurrent(stopToken!, expectingActive: false))
    }

    func testNewStartInvalidatesAnInFlightStop() {
        var lifecycle = TunerLifecycleGate()

        _ = lifecycle.requestStart()
        let stopToken = lifecycle.requestStop()
        let restartToken = lifecycle.requestStart()

        XCTAssertNotNil(stopToken)
        XCTAssertNotNil(restartToken)
        XCTAssertFalse(lifecycle.isCurrent(stopToken!, expectingActive: false))
        XCTAssertTrue(lifecycle.isCurrent(restartToken!, expectingActive: true))
    }

    func testDuplicateTransitionsAreIgnored() {
        var lifecycle = TunerLifecycleGate()

        XCTAssertNotNil(lifecycle.requestStart())
        XCTAssertNil(lifecycle.requestStart())
        XCTAssertNotNil(lifecycle.requestStop())
        XCTAssertNil(lifecycle.requestStop())
    }
}
