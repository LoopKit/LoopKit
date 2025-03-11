//
//  BasalDisplayState.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2025-03-06.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

public enum BasalDisplayState: Equatable {
    case basalTempManual(Double)
    case basalScheduled
    case basalTempAutoAbove
    case basalTempAutoBelow
    case basalTempAutoNoDelivery
    
    public var imageName: String? {
        switch self {
        case .basalScheduled: return "arrow.right.square.fill"
        case .basalTempAutoAbove: return "arrow.up.square.fill"
        case .basalTempAutoBelow, .basalTempAutoNoDelivery: return "arrow.down.square.fill"
        default:
            return nil
        }
    }
}
