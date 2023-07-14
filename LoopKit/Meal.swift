//
//  Meal.swift
//  LoopKit
//
//  Created by Noah Brauner on 7/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct Meal: Identifiable {
    public var id = UUID().uuidString
    
    public var carbsQuantity: HKQuantity
    public var foodType: String
    public var absorptionTime: TimeInterval
    
    public var name: String
    
    public init(carbsQuantity: HKQuantity, foodType: String, absorptionTime: TimeInterval, name: String) {
        self.carbsQuantity = carbsQuantity
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.name = name
    }
    
    private let quantityFormatter = QuantityFormatter(for: .gram())
    
    public var carbsString: String {
        guard let string = quantityFormatter.string(from: carbsQuantity) else {
            assertionFailure("Unable to format \(String(describing: carbsQuantity)) into gram format")
            return ""
        }
        return string
    }
    
    private let absorptionFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.collapsesLargestUnit = true
        formatter.unitsStyle = .full
        formatter.allowsFractionalUnits = true
        formatter.allowedUnits = [.hour, .minute]
        return formatter
    }()
    
    public var absorptionTimeString: String {
        guard let string = absorptionFormatter.string(from: absorptionTime) else {
            assertionFailure("Unable to format \(String(describing: absorptionTime)) into absorption time format")
            return ""
        }
        return string
    }
}

extension Meal: Equatable {
    public static func == (lhs: Meal, rhs: Meal) -> Bool {
        return lhs.id == rhs.id
    }
}
