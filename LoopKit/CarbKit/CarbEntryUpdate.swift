//
//  CarbEntryUpdate.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm


/// New content for a stored carb entry, which keeps its identity.
public struct CarbEntryUpdate: CarbEntry, Equatable {
    public let date: Date
    public let quantity: LoopQuantity
    public let startDate: Date
    public let foodType: String?
    public let absorptionTime: TimeInterval?
    public let favoriteFoodID: String?

    public init(date: Date = Date(), quantity: LoopQuantity, startDate: Date, foodType: String?, absorptionTime: TimeInterval?, favoriteFoodID: String? = nil) {
        self.date = date
        self.quantity = quantity
        self.startDate = startDate
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.favoriteFoodID = favoriteFoodID
    }
}
