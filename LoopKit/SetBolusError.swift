//
//  SetBolusError.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


public enum SetBolusError: Error {
    case certain(LocalizedError)
    case uncertain(LocalizedError)
}


extension SetBolusError: LocalizedError {
    public func errorDescriptionWithUnits(_ units: Double) -> String {
        let format: String

        switch self {
        case .certain:
            format = LocalizedString("%1$@ U bolus failed", comment: "Describes a certain bolus failure (1: size of the bolus in units)")
        case .uncertain:
            format = LocalizedString("%1$@ U bolus may not have succeeded", comment: "Describes an uncertain bolus failure (1: size of the bolus in units)")
        }

        return String(format: format, NumberFormatter.localizedString(from: NSNumber(value: units), number: .decimal))
    }

    public var failureReason: String? {
        switch self {
        case .certain(let error):
            return error.failureReason
        case .uncertain(let error):
            return error.failureReason
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .certain:
            return LocalizedString("It is safe to retry", comment: "Recovery instruction for a certain bolus failure")
        case .uncertain:
            return LocalizedString("Check your pump before retrying", comment: "Recovery instruction for an uncertain bolus failure")
        }
    }
}
