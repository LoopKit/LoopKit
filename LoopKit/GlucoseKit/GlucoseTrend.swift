//
//  GlucoseTrend.swift
//  Loop
//
//  Created by Nate Racklyeft on 8/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public enum GlucoseTrend: Int, CaseIterable {
    case upUpUp       = 1
    case upUp         = 2
    case up           = 3
    case flat         = 4
    case down         = 5
    case downDown     = 6
    case downDownDown = 7

    public var symbol: String {
        switch self {
        case .upUpUp:
            return "⇈"
        case .upUp:
            return "↑"
        case .up:
            return "↗︎"
        case .flat:
            return "→"
        case .down:
            return "↘︎"
        case .downDown:
            return "↓"
        case .downDownDown:
            return "⇊"
        }
    }
    
    public var arrows: String {
        switch self {
        case .upUpUp:
            return "↑↑"
        case .upUp:
            return "↑"
        case .up:
            return "↗︎"
        case .flat:
            return "→"
        case .down:
            return "↘︎"
        case .downDown:
            return "↓"
        case .downDownDown:
            return "↓↓"
        }
    }

    public var localizedDescription: String {
        switch self {
        case .upUpUp:
            return LocalizedString("Rising very fast", comment: "Glucose trend up-up-up")
        case .upUp:
            return LocalizedString("Rising fast", comment: "Glucose trend up-up")
        case .up:
            return LocalizedString("Rising", comment: "Glucose trend up")
        case .flat:
            return LocalizedString("Flat", comment: "Glucose trend flat")
        case .down:
            return LocalizedString("Falling", comment: "Glucose trend down")
        case .downDown:
            return LocalizedString("Falling fast", comment: "Glucose trend down-down")
        case .downDownDown:
            return LocalizedString("Falling very fast", comment: "Glucose trend down-down-down")
        }
    }
}
