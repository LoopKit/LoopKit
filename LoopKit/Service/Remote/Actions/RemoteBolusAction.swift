//
//  RemoteBolusAction.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct RemoteBolusAction: Codable {
    
    public let amountInUnits: Double
    
    public init(amountInUnits: Double) {
        self.amountInUnits = amountInUnits
    }
}

extension RemoteBolusAction {
    public func toValidBolusAmount(maximumBolus: Double?) throws -> Double {
        
        guard amountInUnits > 0 else {
            throw RemoteBolusActionError.invalidBolus
        }
        
        guard let maxBolusAmount = maximumBolus else {
            throw RemoteBolusActionError.missingMaxBolus
        }
        
        guard amountInUnits <= maxBolusAmount else {
            throw RemoteBolusActionError.exceedsMaxBolus
        }
        
        return amountInUnits
    }
}

public enum RemoteBolusActionError: LocalizedError {
    
    case invalidBolus
    case missingMaxBolus
    case exceedsMaxBolus
    
    public var errorDescription: String? {
        switch self {
        case .invalidBolus:
            return NSLocalizedString("Invalid Bolus Amount", comment: "Remote command error description: invalid bolus amount.")
        case .missingMaxBolus:
            return NSLocalizedString("Missing maximum allowed bolus in settings", comment: "Remote command error description: missing maximum bolus in settings.")
        case .exceedsMaxBolus:
            return NSLocalizedString("Exceeds maximum allowed bolus in settings", comment: "Remote command error description: bolus exceeds maximum bolus in settings.")
        }
    }
}
