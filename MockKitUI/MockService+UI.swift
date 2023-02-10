//
//  MockService+UI.swift
//  MockKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import LoopKitUI
import MockKit
import HealthKit

extension MockService: ServiceUI {
    public static var image: UIImage? {
        return UIImage(systemName: "icloud.and.arrow.up")
    }
    
    public static func setupViewController(colorPalette: LoopUIColorPalette, pluginHost: PluginHost) -> SetupUIResult<ServiceViewController, ServiceUI> {
        return .userInteractionRequired(ServiceNavigationController(rootViewController: MockServiceTableViewController(service: MockService(), for: .create)))
    }

    public func settingsViewController(colorPalette: LoopUIColorPalette) -> ServiceViewController {
      return ServiceNavigationController(rootViewController: MockServiceTableViewController(service: self, for: .update))
    }
    
}

