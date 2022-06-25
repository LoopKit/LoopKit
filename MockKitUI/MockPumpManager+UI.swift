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
    
    public static var onboardingImage: UIImage? { return UIImage(named: "Pump Simulator", in: Bundle(for: MockPumpManagerSettingsViewController.self), compatibleWith: nil) }

    public var smallImage: UIImage? { return UIImage(named: "Pump Simulator", in: Bundle(for: MockPumpManagerSettingsViewController.self), compatibleWith: nil) }
    
    public static func setupViewController(initialSettings settings: PumpManagerSetupSettings, bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> SetupUIResult<PumpManagerViewController, PumpManagerUI> {
        let mockPumpManager = MockPumpManager()
        mockPumpManager.setMaximumTempBasalRate(settings.maxBasalRateUnitsPerHour)
        mockPumpManager.syncBasalRateSchedule(items: settings.basalSchedule.items, completion: { _ in })
        return .createdAndOnboarded(mockPumpManager)
    }

    public func settingsViewController(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> PumpManagerViewController {
        let settings = MockPumpManagerSettingsViewController(pumpManager: self, supportedInsulinTypes: allowedInsulinTypes)
        let nav = PumpManagerSettingsNavigationViewController(rootViewController: settings)
        return nav
    }
    
    public func deliveryUncertaintyRecoveryViewController(colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> (UIViewController & CompletionNotifying) {
        return DeliveryUncertaintyRecoveryViewController(appName: appName, uncertaintyStartedAt: Date()) {
            self.state.deliveryCommandsShouldTriggerUncertainDelivery = false
            self.state.deliveryIsUncertain = false
        }
    }

    public func hudProvider(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowedInsulinTypes: [InsulinType]) -> HUDProvider? {
        return MockHUDProvider(pumpManager: self, allowedInsulinTypes: allowedInsulinTypes)
    }

    public static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> BaseHUDView? {
        return MockHUDProvider.createHUDView(rawValue: rawValue)
    }
    
    
}

public enum MockPumpStatusBadge: DeviceStatusBadge {
    case timeSyncNeeded
    
    public var image: UIImage? {
        switch self {
        case .timeSyncNeeded:
            return UIImage(systemName: "clock.fill")
        }
    }
    
    public var state: DeviceStatusBadgeState {
        switch self {
        case .timeSyncNeeded:
            return .warning
        }
    }
}


// MARK: - PumpStatusIndicator
extension MockPumpManager {
    public var pumpStatusHighlight: DeviceStatusHighlight? {
        return buildPumpStatusHighlight(for: state)
    }

    public var pumpLifecycleProgress: DeviceLifecycleProgress? {
        return buildPumpLifecycleProgress(for: state)
    }

    public var pumpStatusBadge: DeviceStatusBadge? {
        return isClockOffset ? MockPumpStatusBadge.timeSyncNeeded : nil
    }
}
