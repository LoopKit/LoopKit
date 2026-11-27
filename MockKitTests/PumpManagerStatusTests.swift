import XCTest
import LoopKit
@testable import MockKit

final class PumpManagerReservoirStatusTests: XCTestCase {
    private final class Observer: PumpManagerStatusObserver {
        var didUpdate: ((PumpManagerStatus, PumpManagerStatus) -> Void)?

        func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
            didUpdate?(status, oldStatus)
        }
    }

    @MainActor
    func testReplacingLowReservoirNotifiesStatusObserversWithoutOtherStatusChanges() async {
        let pump = MockPumpManager()
        // Hold the basal-state date fixed so another status field cannot trigger the notification.
        pump.state.suspendState = .resumed(Date(timeIntervalSinceReferenceDate: 0))
        pump.state.reservoirUnitsRemaining = 2

        let updated = expectation(description: "Current reservoir replaces the low reading")
        let observer = Observer()
        observer.didUpdate = { status, oldStatus in
            XCTAssertEqual(oldStatus.reservoirLevel, .measured(units: 2))
            XCTAssertEqual(status.reservoirLevel, .aboveThreshold(units: 50))
            var otherFields = status
            otherFields.reservoirLevel = oldStatus.reservoirLevel
            XCTAssertEqual(otherFields, oldStatus)
            updated.fulfill()
        }
        pump.addStatusObserver(observer, queue: .main)
        defer { pump.removeStatusObserver(observer) }

        pump.state.reservoirUnitsRemaining = 200
        await fulfillment(of: [updated], timeout: 2)
    }
}
