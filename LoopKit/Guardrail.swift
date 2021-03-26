//
//  Guardrail.swift
//  LoopKit
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit


public enum SafetyClassification: Equatable {
    public enum Threshold: Equatable {
        case minimum
        case belowRecommended
        case aboveRecommended
        case maximum
    }

    case withinRecommendedRange
    case outsideRecommendedRange(Threshold)
}

public struct Guardrail<Value: Comparable> {
    public let absoluteBounds: ClosedRange<Value>
    public let recommendedBounds: ClosedRange<Value>
    public let startingSuggestion: Value?

    public init(absoluteBounds: ClosedRange<Value>, recommendedBounds: ClosedRange<Value>, startingSuggestion: Value? = nil) {
        precondition(absoluteBounds.lowerBound <= recommendedBounds.lowerBound, "The minimum value must be less than or equal to the smallest recommended value")
        precondition(absoluteBounds.upperBound >= recommendedBounds.upperBound, "The maximum value must be greater than or equal to the greatest recommended value")
        if let startingSuggestion = startingSuggestion {
            precondition(recommendedBounds.contains(startingSuggestion))
        }
        self.absoluteBounds = absoluteBounds
        self.recommendedBounds = recommendedBounds
        self.startingSuggestion = startingSuggestion
    }

    public func classification(for value: Value) -> SafetyClassification {
        switch value {
        case ...absoluteBounds.lowerBound where absoluteBounds.lowerBound != recommendedBounds.lowerBound:
            return .outsideRecommendedRange(.minimum)
        case ..<recommendedBounds.lowerBound:
            return .outsideRecommendedRange(.belowRecommended)
        case ...recommendedBounds.upperBound:
            return .withinRecommendedRange
        case ..<absoluteBounds.upperBound:
            return .outsideRecommendedRange(.aboveRecommended)
        case absoluteBounds.upperBound...:
            return .outsideRecommendedRange(.maximum)
        default:
            preconditionFailure("Unreachable")
        }
    }
}

extension Guardrail where Value: Strideable {
    public func allValues(stridingBy increment: Value.Stride) -> StrideThrough<Value> {
        stride(from: absoluteBounds.lowerBound, through: absoluteBounds.upperBound, by: increment)
    }
}

extension Guardrail where Value == HKQuantity {
    public init(absoluteBounds: ClosedRange<Double>, recommendedBounds: ClosedRange<Double>, unit: HKUnit, startingSuggestion: Double? = nil) {
        let absoluteBoundsWithUnit = HKQuantity(unit: unit, doubleValue: absoluteBounds.lowerBound)...HKQuantity(unit: unit, doubleValue: absoluteBounds.upperBound)
        let recommendedBoundsWithUnit = HKQuantity(unit: unit, doubleValue: recommendedBounds.lowerBound)...HKQuantity(unit: unit, doubleValue: recommendedBounds.upperBound)
        let startingSuggestionQuantity: HKQuantity?
        if let startingSuggestion = startingSuggestion {
            startingSuggestionQuantity = HKQuantity(unit: unit, doubleValue: startingSuggestion)
        } else {
            startingSuggestionQuantity = nil
        }
        self.init(absoluteBounds: absoluteBoundsWithUnit, recommendedBounds: recommendedBoundsWithUnit, startingSuggestion: startingSuggestionQuantity)
    }

    public func allQuantities(stridingBy increment: HKQuantity, unit: HKUnit) -> [HKQuantity] {
        allValues(stridingBy: increment, unit: unit)
            .map { HKQuantity(unit: unit, doubleValue: $0) }
    }

    public func allValues(stridingBy increment: HKQuantity, unit: HKUnit) -> [Double] {
        Array(stride(
            from: absoluteBounds.lowerBound.doubleValue(for: unit, withRounding: true),
            through: absoluteBounds.upperBound.doubleValue(for: unit, withRounding: true),
            by: increment.doubleValue(for: unit, withRounding: true)
        ))
    }
}
