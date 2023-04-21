//
//  FloatingPoint.swift
//  LoopKit
//
//  Created by Michael Pangburn on 7/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

extension Double {
    public func matchingOrTruncatedValue(from supportedValues: [Double], withinDecimalPlaces precision: Int) -> Double {
        let nearestSupportedValue = roundedToNearest(of: supportedValues)
        return abs(nearestSupportedValue - self) <= pow(10.0, Double(-precision))
            ? nearestSupportedValue
            : truncating(toOneOf: supportedValues)
    }
}

extension FloatingPoint {
    /// Precondition: - `supportedValues` is sorted in ascending order.
    public func roundedToNearest(of supportedValues: [Self]) -> Self {
        guard !supportedValues.isEmpty else {
            return self
        }

        let splitPoint = supportedValues.partitioningIndex(where: { $0 > self })
        switch splitPoint {
        case supportedValues.startIndex:
            return supportedValues.first!
        case supportedValues.endIndex:
            return supportedValues.last!
        default:
            let (lesser, greater) = (supportedValues[splitPoint - 1], supportedValues[splitPoint])
            return (self - lesser) <= (greater - self) ? lesser : greater
        }
    }

    /// Precondition: - `supportedValues` is sorted in ascending order.
    public func truncating(toOneOf supportedValues: [Self]) -> Self {
        guard !supportedValues.isEmpty else {
            return self
        }

        let splitPoint = supportedValues.partitioningIndex(where: { $0 > self })
        return splitPoint == supportedValues.startIndex
            ? supportedValues.first!
            : supportedValues[splitPoint - 1]
    }
}
