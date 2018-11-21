//
//  MockPumpManager+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit


final class MockHUDProvider: HUDProvider {
    var managerIdentifier: String {
        return MockPumpManager.managerIdentifier
    }

    var delegate: HUDProviderDelegate?

    private var pumpManager: MockPumpManager

    private var lastPumpManagerStatus: PumpManagerStatus

    private weak var reservoirView: ReservoirVolumeHUDView?

    private weak var batteryView: BatteryLevelHUDView?

    init(pumpManager: MockPumpManager) {
        self.pumpManager = pumpManager
        self.lastPumpManagerStatus = pumpManager.status
        pumpManager.addStateObserver(self)
    }

    var hudViewsRawState: HUDViewsRawState {
        var rawValue: HUDViewsRawState = [
            "pumpReservoirCapacity": pumpManager.pumpReservoirCapacity
        ]

        if let pumpBatteryChargeRemaining = lastPumpManagerStatus.pumpBatteryChargeRemaining {
            rawValue["pumpBatteryChargeRemaining"] = pumpBatteryChargeRemaining
        }

        if let reservoirUnitsRemaining = pumpManager.reservoirUnitsRemaining {
            rawValue["reservoirUnitsRemaining"] = reservoirUnitsRemaining
        }

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
            reservoirVolumeHUDView.reservoirLevel = reservoirLevel
            reservoirVolumeHUDView.setReservoirVolume(volume: reservoirUnitsRemaining, at: Date())
        }

        let batteryPercentage = rawValue["pumpBatteryChargeRemaining"] as? Double
        let batteryLevelHUDView = BatteryLevelHUDView.instantiate()
        batteryLevelHUDView.batteryLevel = batteryPercentage

        return [reservoirVolumeHUDView, batteryLevelHUDView]
    }

    func didTapOnHudView(_ view: BaseHUDView) -> HUDTapAction? {
        return nil
    }

    private func updateReservoirView() {
        if let reservoirVolume = pumpManager.reservoirUnitsRemaining {
            let reservoirLevel = (reservoirVolume / pumpManager.pumpReservoirCapacity).clamped(to: 0...1)
            reservoirView?.reservoirLevel = reservoirLevel
            reservoirView?.setReservoirVolume(volume: reservoirVolume, at: Date())
        }
    }

    private func updateBatteryView() {
        batteryView?.batteryLevel = lastPumpManagerStatus.pumpBatteryChargeRemaining
    }
}

extension MockHUDProvider: MockPumpManagerStateObserver {
    func mockPumpManager(_ manager: MockPumpManager, didUpdateReservoirUnitsRemaining units: Double) {
        updateReservoirView()
    }

    func pumpManager(_ pumpManager: PumpManager, didUpdateStatus status: PumpManagerStatus) {
        lastPumpManagerStatus = status
        updateBatteryView()
    }
}

extension MockPumpManager: PumpManagerUI {
    public static func setupViewController() -> (UIViewController & PumpManagerSetupViewController) {
        return MockPumpManagerSetupViewController.instantiateFromStoryboard()
    }

    public func settingsViewController() -> UIViewController {
        return MockPumpManagerSettingsViewController(pumpManager: self)
    }

    public var smallImage: UIImage? {
        return nil
    }

    public func hudProvider() -> HUDProvider? {
        return MockHUDProvider(pumpManager: self)
    }

    public static func createHUDViews(rawValue: [String : Any]) -> [BaseHUDView] {
        return MockHUDProvider.createHUDViews(rawValue: rawValue)
    }
}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension MockPumpManager {
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        completion(.success(maximumBasalRatePerHour: maximumBasalRatePerHour, maximumBolus: maximumBolus))
    }

    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return "Continue"
    }

    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }

    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return false
    }
}

// MARK: - SingleValueScheduleTableViewControllerSyncSource
extension MockPumpManager {
    public func syncScheduleValues(for viewController: SingleValueScheduleTableViewController, completion: @escaping (RepeatingScheduleValueResult<Double>) -> Void) {
        completion(.success(scheduleItems: [RepeatingScheduleValue(startTime: 0, value: 1.0)], timeZone: .current))
    }

    public func syncButtonTitle(for viewController: SingleValueScheduleTableViewController) -> String {
        return "Continue"
    }

    public func syncButtonDetailText(for viewController: SingleValueScheduleTableViewController) -> String? {
        return nil
    }

    public func singleValueScheduleTableViewControllerIsReadOnly(_ viewController: SingleValueScheduleTableViewController) -> Bool {
        return false
    }
}
