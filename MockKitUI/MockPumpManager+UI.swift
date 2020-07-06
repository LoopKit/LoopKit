//
//  MockPumpManager+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import LoopKitUI
import MockKit


extension MockPumpManager: PumpManagerUI {
    public var smallImage: UIImage? { return UIImage(named: "Simulator Small", in: Bundle(for: MockPumpManagerSettingsViewController.self), compatibleWith: nil) }

    public static func setupViewController() -> (UIViewController & CompletionNotifying & PumpManagerSetupViewController) {
        return MockPumpManagerSetupViewController.instantiateFromStoryboard()
    }

    public func settingsViewController() -> (UIViewController & CompletionNotifying) {
        let settings = MockPumpManagerSettingsViewController(pumpManager: self)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }

    public func hudProvider() -> HUDProvider? {
        return MockHUDProvider(pumpManager: self)
    }

    public static func createHUDView(rawValue: [String : Any]) -> LevelHUDView? {
        return MockHUDProvider.createHUDView(rawValue: rawValue)
    }
}

// MARK: - DeliveryLimitSettingsTableViewControllerSyncSource
extension MockPumpManager {
    public func syncDeliveryLimitSettings(for viewController: DeliveryLimitSettingsTableViewController, completion: @escaping (DeliveryLimitSettingsResult) -> Void) {
        guard let maximumBasalRatePerHour = viewController.maximumBasalRatePerHour,
            let maximumBolus = viewController.maximumBolus else
        {
            completion(.failure(MockPumpManagerError.missingSettings))
            return
        }
        completion(.success(maximumBasalRatePerHour: maximumBasalRatePerHour, maximumBolus: maximumBolus))
    }

    public func syncButtonTitle(for viewController: DeliveryLimitSettingsTableViewController) -> String {
        return "Save to simulator"
    }

    public func syncButtonDetailText(for viewController: DeliveryLimitSettingsTableViewController) -> String? {
        return nil
    }

    public func deliveryLimitSettingsTableViewControllerIsReadOnly(_ viewController: DeliveryLimitSettingsTableViewController) -> Bool {
        return false
    }
}

// MARK: - BasalScheduleTableViewControllerSyncSource
extension MockPumpManager {
    public func syncScheduleValues(for viewController: BasalScheduleTableViewController, completion: @escaping (SyncBasalScheduleResult<Double>) -> Void) {
        completion(.success(scheduleItems: viewController.scheduleItems, timeZone: .currentFixed))
    }

    public func syncButtonTitle(for viewController: BasalScheduleTableViewController) -> String {
        return "Save to simulator"
    }

    public func syncButtonDetailText(for viewController: BasalScheduleTableViewController) -> String? {
        return nil
    }

    public func basalScheduleTableViewControllerIsReadOnly(_ viewController: BasalScheduleTableViewController) -> Bool {
        return false
    }
}
