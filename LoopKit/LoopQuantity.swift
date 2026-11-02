//
//  LoopQuantity.swift
//  LoopKit
//
//  Created by Cameron Ingham on 11/8/24.
//

import Foundation

public struct LoopQuantity: Hashable, Equatable, Comparable, Sendable {

    public let unit: LoopUnit
    private let value: Double
    
    public init(unit: LoopUnit, doubleValue value: Double) {
        self.unit = unit
        self.value = value
    }
    
    public func `is`(compatibleWith unit: LoopUnit) -> Bool {
        self.unit.conversionFactor(toUnit: unit) != nil
    }
    
    /**
     @method        doubleValueForUnit:
     @abstract      Returns the quantity value converted to the given unit.
     @discussion    Throws an exception if the receiver's value cannot be converted to one of the requested unit.
     */
    public func doubleValue(for unit: LoopUnit) -> Double {
        guard let conversionFactor = self.unit.conversionFactor(toUnit: unit) else {
            fatalError("Conversion Error: \(self.unit.unitString) is not compatible with \(unit.unitString).")
        }
        
        if self.unit == unit {
            return value
        } else {
            return value * conversionFactor
        }
    }

    /**
     @method        compare:
     @abstract      Returns an NSComparisonResult value that indicates whether the receiver is greater than, equal to, or
                    less than a given quantity.
     @discussion    Throws an exception if the unit of the given quantity is not compatible with the receiver's unit.
     */
    public func compare(_ quantity: LoopQuantity) -> ComparisonResult {
        if value == quantity.doubleValue(for: unit) {
            return .orderedSame
        } else if value > quantity.doubleValue(for: unit) {
            return .orderedDescending
        } else {
            return .orderedAscending
        }
    }
    
    public static func <(lhs: LoopQuantity, rhs: LoopQuantity) -> Bool {
        return lhs.compare(rhs) == .orderedAscending
    }
    
    public static func == (lhs: LoopQuantity, rhs: LoopQuantity) -> Bool {
        guard lhs.unit != rhs.unit else {
            return lhs.value == rhs.value
        }
        
        guard rhs.is(compatibleWith: lhs.unit) else {
            return false
        }
        
        return lhs.doubleValue(for: lhs.unit) == rhs.doubleValue(for: lhs.unit)
    }
}

