//
//  CarbValue.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public struct CarbValue: SampleValue {
    public let startDate: Date
    public let endDate: Date
    public var quantity: HKQuantity

    public init(startDate: Date, endDate: Date? = nil, quantity: HKQuantity) {
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.quantity = quantity
    }
}

extension CarbValue: Equatable {}

extension CarbValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.quantity = HKQuantity(unit: HKUnit(from: try container.decode(String.self, forKey: .quantityUnit)),
                                   doubleValue: try container.decode(Double.self, forKey: .quantity))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(quantity.doubleValue(for: .gram()), forKey: .quantity)
        try container.encode(HKUnit.gram().unitString, forKey: .quantityUnit)
    }

    private enum CodingKeys: String, CodingKey {
        case startDate
        case endDate
        case quantity
        case quantityUnit
    }
}
