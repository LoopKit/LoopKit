//
//  Guardrail.swift
//  LoopKit
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm


public enum SafetyClassification: Equatable, Hashable {
    public enum Threshold: Equatable {
        case minimum
        case belowRecommended
        case belowWarning
        case aboveRecommended
        case aboveWarning
        case maximum
    }

    case withinRecommendedRange
    case outsideRecommendedRange(Threshold)

    public static func captionForCrossedThresholds(_ thresholds: [Threshold], isRange: Bool) -> String {
        if thresholds.count > 1 {
            return LocalizedString("Some of the values you have entered are outside of what is typically recommended for most people.", comment: "Descriptive text for guardrail high value warning for schedule interface")
        } else {
            switch thresholds[0] {
            case .aboveRecommended, .aboveWarning, .maximum:
                if isRange {
                    return LocalizedString("A value you have entered is higher than what is typically recommended for most people.", comment: "Descriptive text for guardrail high value warning for schedule interface")
                } else {
                    return LocalizedString("The value you have entered is higher than what is typically recommended for most people.", comment: "Descriptive text for guardrail high value warning")
                }
            case .belowRecommended, .belowWarning, .minimum:
                if isRange {
                    return LocalizedString("A value you have entered is lower than what is typically recommended for most people.", comment: "Descriptive text for guardrail low value warning for schedule interface")
                } else {
                    return LocalizedString("The value you have entered is lower than what is typically recommended for most people.", comment: "Descriptive text for guardrail low value warning")
                }
            }
        }
    }
}

public struct Guardrail<Value: Comparable> {
    public let absoluteBounds: ClosedRange<Value>
    public let warningBounds: ClosedRange<Value>?
    public let recommendedBounds: ClosedRange<Value>
    public let startingSuggestion: Value?

    public init(absoluteBounds: ClosedRange<Value>, warningBounds: ClosedRange<Value>? = nil, recommendedBounds: ClosedRange<Value>, startingSuggestion: Value? = nil) {
        precondition(absoluteBounds.lowerBound <= recommendedBounds.lowerBound, "The minimum value must be less than or equal to the smallest recommended value")
        precondition(absoluteBounds.upperBound >= recommendedBounds.upperBound, "The maximum value must be greater than or equal to the greatest recommended value")
        
        if let warningBounds {
            precondition(absoluteBounds.lowerBound <= warningBounds.lowerBound, "The minimum value must be less than or equal to the smallest warning value")
            precondition(warningBounds.lowerBound <= recommendedBounds.lowerBound, "The smallest warning value must be less than or equal to the smallest recommended value")
            precondition(warningBounds.upperBound >= recommendedBounds.upperBound, "The greatest warning value must be greater than or equal to the greatest warning value")
            precondition(absoluteBounds.upperBound >= warningBounds.upperBound, "The maximum value must be greater than or equal to the greatest warning value")
        }
        
        if let startingSuggestion = startingSuggestion {
            precondition(recommendedBounds.contains(startingSuggestion))
        }
        self.absoluteBounds = absoluteBounds
        self.warningBounds = warningBounds
        self.recommendedBounds = recommendedBounds
        self.startingSuggestion = startingSuggestion
    }

    public func classification(for value: Value) -> SafetyClassification {
        let lowerWarning = warningBounds?.lowerBound ?? recommendedBounds.lowerBound
        let upperWarning = warningBounds?.upperBound ?? absoluteBounds.upperBound
        
        switch value {
        case ...absoluteBounds.lowerBound where absoluteBounds.lowerBound != recommendedBounds.lowerBound:
            return .outsideRecommendedRange(.minimum)
        case ..<lowerWarning where lowerWarning != recommendedBounds.lowerBound:
            return .outsideRecommendedRange(.belowWarning)
        case ..<recommendedBounds.lowerBound:
            return .outsideRecommendedRange(.belowRecommended)
        case ...recommendedBounds.upperBound:
            return .withinRecommendedRange
        case ..<upperWarning:
            return .outsideRecommendedRange(.aboveRecommended)
        case ..<absoluteBounds.upperBound where upperWarning != absoluteBounds.upperBound:
            return .outsideRecommendedRange(.aboveWarning)
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

extension Guardrail where Value == LoopQuantity {
    public init(absoluteBounds: ClosedRange<Double>, warningBounds: ClosedRange<Double>? = nil, recommendedBounds: ClosedRange<Double>, unit: LoopUnit, startingSuggestion: Double? = nil) {
        let absoluteBoundsWithUnit = LoopQuantity(unit: unit, doubleValue: absoluteBounds.lowerBound)...LoopQuantity(unit: unit, doubleValue: absoluteBounds.upperBound)
        var warningBoundsWithUnit: ClosedRange<LoopQuantity>? = nil
        if let warningBounds {
            warningBoundsWithUnit = LoopQuantity(unit: unit, doubleValue: warningBounds.lowerBound)...LoopQuantity(unit: unit, doubleValue: warningBounds.upperBound)
        }
        let recommendedBoundsWithUnit = LoopQuantity(unit: unit, doubleValue: recommendedBounds.lowerBound)...LoopQuantity(unit: unit, doubleValue: recommendedBounds.upperBound)
        let startingSuggestionQuantity: LoopQuantity?
        if let startingSuggestion = startingSuggestion {
            startingSuggestionQuantity = LoopQuantity(unit: unit, doubleValue: startingSuggestion)
        } else {
            startingSuggestionQuantity = nil
        }
        self.init(absoluteBounds: absoluteBoundsWithUnit, warningBounds: warningBoundsWithUnit, recommendedBounds: recommendedBoundsWithUnit, startingSuggestion: startingSuggestionQuantity)
    }

    /// if fractionDigits is nil, defaults to the unit maxFractionDigits
    public func allQuantities(forUnit unit: LoopUnit, usingFractionDigits fractionDigits: Int? = nil) -> [LoopQuantity] {
        allValues(forUnit: unit, usingFractionDigits: fractionDigits ?? unit.maxFractionDigits)
            .map { LoopQuantity(unit: unit, doubleValue: $0) }
    }

    /// if fractionDigits is nil, defaults to the unit maxFractionDigits
    public func allValues(forUnit unit: LoopUnit, usingFractionDigits fractionDigits: Int? = nil) -> [Double] {
        unit.allValues(from: absoluteBounds.lowerBound, through: absoluteBounds.upperBound, usingFractionDigits: fractionDigits ?? unit.maxFractionDigits)
    }
}


