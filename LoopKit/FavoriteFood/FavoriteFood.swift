//
//  FavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 7/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

public protocol FavoriteFood {
    var name: String { get }
    var carbsQuantity: HKQuantity { get }
    var foodType: String { get }
    var absorptionTime: TimeInterval { get }
}

extension FavoriteFood {
    public var title: String {
        return name + " " + foodType
    }
    
    public var absorptionTimeString: String {
        if Int(absorptionTime.hours) == 0 {
            return "\(Int(absorptionTime.minutes)) min"
        }
        else if absorptionTime.minutes.truncatingRemainder(dividingBy: 60) == 0 {
            return "\(Int(absorptionTime.hours)) hr"
        }
        else {
            let totalHours = floor(absorptionTime.hours) + absorptionTime.minutes.truncatingRemainder(dividingBy: 60) / 60.0
            return String(format: "%.1f hr", totalHours)
        }
    }
    
    public func carbsString(for unit: HKUnit) -> String {
        guard let string = QuantityFormatter(for: unit).string(from: carbsQuantity) else {
            assertionFailure("Unable to format \(String(describing: carbsQuantity)) into gram format")
            return ""
        }
        return string
    }
}
