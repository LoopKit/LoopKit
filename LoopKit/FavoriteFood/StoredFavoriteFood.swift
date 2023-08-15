//
//  StoredFavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 8/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct StoredFavoriteFood: FavoriteFood, Identifiable {
    public var id: String
    
    public var name: String
    public var carbsQuantity: HKQuantity
    public var foodType: String
    public var absorptionTime: TimeInterval
    
    public init(id: String = UUID().uuidString, name: String, carbsQuantity: HKQuantity, foodType: String, absorptionTime: TimeInterval) {
        self.id = id
        self.name = name
        self.carbsQuantity = carbsQuantity
        self.foodType = foodType
        self.absorptionTime = absorptionTime
    }
}

extension StoredFavoriteFood: Equatable {
    public static func == (lhs: StoredFavoriteFood, rhs: StoredFavoriteFood) -> Bool {
        return lhs.id == rhs.id
    }
}

extension StoredFavoriteFood: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            carbsQuantity: HKQuantity(unit: .gram(), doubleValue: try container.decode(Double.self, forKey: .carbsQuantity)),
            foodType: try container.decode(String.self, forKey: .foodType),
            absorptionTime: try container.decode(TimeInterval.self, forKey: .absorptionTime)
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(carbsQuantity.doubleValue(for: .gram()), forKey: .carbsQuantity)
        try container.encode(foodType, forKey: .foodType)
        try container.encode(absorptionTime, forKey: .absorptionTime)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case carbsQuantity
        case foodType
        case absorptionTime
    }
}
