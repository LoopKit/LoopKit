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

    init(pumpManager: MockPumpManager) {
        self.pumpManager = pumpManager
        self.lastPumpManagerStatus = pumpManager.status
        super.init()
        pumpManager.addStateObserver(self, queue: .main)
    }

    var visible: Bool = false

    var hudViewsRawState: HUDViewsRawState {
        var rawValue: HUDViewsRawState = [
            "pumpReservoirCapacity": pumpManager.pumpReservoirCapacity
        ]

        if let pumpBatteryChargeRemaining = lastPumpManagerStatus.pumpBatteryChargeRemaining {
            rawValue["pumpBatteryChargeRemaining"] = pumpBatteryChargeRemaining
        }

        rawValue["reservoirUnitsRemaining"] = pumpManager.state.reservoirUnitsRemaining

        return rawValue
    }

    func createHUDViews() -> [BaseHUDView] {
        reservoirView = ReservoirVolumeHUDView.instantiate()
        updateReservoirView()

        batteryView = BatteryLevelHUDView.instantiate()
        updateBatteryView()

        return [reservoirView, batteryView].compactMap { $0 }
    }

    static func createHUDViews(rawValue: HUDViewsRawState) -> [BaseHUDView] {
        guard let pumpReservoirCapacity = rawValue["pumpReservoirCapacity"] as? Double else {
            return []
        }

        let reservoirVolumeHUDView = ReservoirVolumeHUDView.instantiate()
        if let reservoirUnitsRemaining = rawValue["reservoirUnitsRemaining"] as? Double {
            let reservoirLevel = (reservoirUnitsRemaining / pumpReservoirCapacity).clamped(to: 0...1)
            reservoirVolumeHUDView.level = reservoirLevel
            reservoirVolumeHUDView.setReservoirVolume(volume: reservoirUnitsRemaining, at: Date())
        }

        let batteryPercentage = rawValue["pumpBatteryChargeRemaining"] as? Double
        let batteryLevelHUDView = BatteryLevelHUDView.instantiate()
        batteryLevelHUDView.batteryLevel = batteryPercentage

        return [reservoirVolumeHUDView, batteryLevelHUDView]
    }

    func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction? {
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
