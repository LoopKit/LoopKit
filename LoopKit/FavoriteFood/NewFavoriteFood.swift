//
//  NewFavoriteFood.swift
//  LoopKit
//
//  Created by Noah Brauner on 8/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public struct NewFavoriteFood: FavoriteFood {
    public var name: String
    public var carbsQuantity: LoopQuantity
    public var foodType: String
    public var absorptionTime: TimeInterval

    public init(name: String, carbsQuantity: LoopQuantity, foodType: String, absorptionTime: TimeInterval) {
        self.name = name
        self.carbsQuantity = carbsQuantity
        self.foodType = foodType
        self.absorptionTime = absorptionTime
    }
}
