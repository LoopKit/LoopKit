//
//  NSNumberFormatter.swift
//  Loop
//
//  Created by Nate Racklyeft on 9/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


extension NumberFormatter {
    func string(from number: Double) -> String? {
        return string(from: NSNumber(value: number))
    }

    func string(from number: Double, unit: String, style: Formatter.UnitStyle = .medium, avoidLineBreaking: Bool = true) -> String? {
        guard let stringValue = string(from: number) else {
            return nil
        }
        
        let separator: String
        switch style {
        case .long:
            separator = " "
        case .medium:
            separator = avoidLineBreaking ? .nonBreakingSpace : " "
        case .short:
            fallthrough
        @unknown default:
            separator = avoidLineBreaking ? .wordJoiner : ""
        }
        
        let unit = avoidLineBreaking ? unit.replacingOccurrences(of: "/", with: "\(String.wordJoiner)/\(String.wordJoiner)") : unit
        
        return String(
            format: LocalizedString("%1$@%2$@%3$@", comment: "String format for value with units (1: value, 2: separator, 3: units)"),
            stringValue,
            separator,
            unit
        )
    }
}

public extension String {
    static let nonBreakingSpace = "\u{00a0}"
    static let wordJoiner = "\u{2060}"
}
