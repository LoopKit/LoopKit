//
//  DiscoveredFob+UI.swift
//  MockKitUI
//
//  Created by Pete Schwamb on 7/31/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import MockKit
import SwiftUI

extension DiscoveredFob {
    var batteryImageName: String? {
        guard let batteryPercent else {
            return nil
        }
        if batteryPercent < 20 {
            return "battery.0percent"
        } else if batteryPercent < 40 {
            return "battery.25percent"
        } else if batteryPercent < 60 {
            return "battery.50percent"
        } else if batteryPercent < 80 {
            return "battery.75percent"
        } else {
            return "battery.100percent"
        }
    }
}
