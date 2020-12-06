//
//  MockPumpManager+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit
import LoopKitUI
import MockKit


extension MockPumpManager: PumpManagerUI {
    private var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    }
    
    public var smallImage: UIImage? { return UIImage(named: "Pump Simulator", in: Bundle(for: MockPumpManagerSettingsViewController.self), compatibleWith: nil) }
    
    public static func setupViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying & PumpManagerSetupViewController) {
        return MockPumpManagerSetupViewController.instantiateFromStoryboard()
    }

    public func settingsViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying) {
        let settings = MockPumpManagerSettingsViewController(pumpManager: self)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }
    
    public func deliveryUncertaintyRecoveryViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying) {
        return DeliveryUncertaintyRecoveryViewController(appName: appName, uncertaintyStartedAt: Date()) {
            self.state.deliveryCommandsShouldTriggerUncertainDelivery = false
            self.state.deliveryIsUncertain = false
        }
    }

    public func hudProvider(insulinTintColor: Color, guidanceColors: GuidanceColors) -> HUDProvider? {
        return MockHUDProvider(pumpManager: self)
    }

    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView? {
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
        syncBasalRateSchedule(items: viewController.scheduleItems) { result in
            switch result {
            case .success(let schedule):
                completion(.success(scheduleItems: schedule.items, timeZone: schedule.timeZone))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
