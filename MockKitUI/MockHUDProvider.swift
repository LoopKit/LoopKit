//
//  MockHUDProvider.swift
//  MockKitUI
//
//  Created by Michael Pangburn on 3/5/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import LoopKitUI
import MockKit


final class MockHUDProvider: NSObject, HUDProvider {

    var managerIdentifier: String {
        return MockPumpManager.managerIdentifier
    }

    private var pumpManager: MockPumpManager

    private var lastPumpManagerStatus: PumpManagerStatus

    private weak var reservoirView: ReservoirVolumeHUDView?

    private weak var batteryView: BatteryLevelHUDView?

    init(pumpManager: MockPumpManager, allowedInsulinTypes: [InsulinType]) {
        self.pumpManager = pumpManager
        self.lastPumpManagerStatus = pumpManager.status
        super.init()
        pumpManager.addStateObserver(self, queue: .main)
    }

    var visible: Bool = false

    var hudViewRawState: HUDViewRawState {
        var rawValue: HUDViewRawState = [
            "pumpReservoirCapacity": pumpManager.pumpReservoirCapacity
        ]

        if let pumpBatteryChargeRemaining = lastPumpManagerStatus.pumpBatteryChargeRemaining {
            rawValue["pumpBatteryChargeRemaining"] = pumpBatteryChargeRemaining
        }

        rawValue["reservoirUnitsRemaining"] = pumpManager.state.reservoirUnitsRemaining

        return rawValue
    }

    func createHUDView() -> BaseHUDView? {
        reservoirView = ReservoirVolumeHUDView.instantiate()
        updateReservoirView()
    
        return reservoirView
    }

    static func createHUDView(rawValue: HUDViewRawState) -> BaseHUDView? {
        guard let pumpReservoirCapacity = rawValue["pumpReservoirCapacity"] as? Double else {
            return nil
        }

        let reservoirVolumeHUDView = ReservoirVolumeHUDView.instantiate()
        if let reservoirUnitsRemaining = rawValue["reservoirUnitsRemaining"] as? Double {
            let reservoirLevel = (reservoirUnitsRemaining / pumpReservoirCapacity).clamped(to: 0...1)
            reservoirVolumeHUDView.level = reservoirLevel
            reservoirVolumeHUDView.setReservoirVolume(volume: reservoirUnitsRemaining, at: Date())
        }

        return reservoirVolumeHUDView
    }

    func didTapOnHUDView(_ view: BaseHUDView, allowDebugFeatures: Bool) -> HUDTapAction? {
        return nil
    }

    private func updateReservoirView() {
        let reservoirVolume = pumpManager.state.reservoirUnitsRemaining
        let reservoirLevel = (reservoirVolume / pumpManager.pumpReservoirCapacity).clamped(to: 0...1)
        reservoirView?.level = reservoirLevel
        reservoirView?.setReservoirVolume(volume: reservoirVolume, at: Date())
    }

    private func updateBatteryView() {
        batteryView?.batteryLevel = lastPumpManagerStatus.pumpBatteryChargeRemaining
    }
}

extension MockHUDProvider: MockPumpManagerStateObserver {
    func mockPumpManager(_ manager: MockPumpManager, didUpdate state: MockPumpManagerState) {
        updateReservoirView()
    }

    func mockPumpManager(_ manager: MockPumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        lastPumpManagerStatus = status
        updateBatteryView()
    }
}
