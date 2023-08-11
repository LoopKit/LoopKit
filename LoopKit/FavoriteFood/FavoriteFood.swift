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
    
    public func absorptionTimeString(formatter: DateComponentsFormatter) -> String {
        guard let string = formatter.string(from: absorptionTime) else {
            assertionFailure("Unable to format \(String(describing: absorptionTime))")
            return ""
        }
        return string
    }
    
    public func carbsString(formatter: QuantityFormatter) -> String {
        guard let string = formatter.string(from: carbsQuantity) else {
            assertionFailure("Unable to format \(String(describing: carbsQuantity)) into gram format")
            return ""
        }
        return string
    }
}
