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
            separator = avoidLineBreaking ? "\u{00a0}" : " "
        case .short:
            fallthrough
        @unknown default:
            separator = avoidLineBreaking ? "\u{2060}" : ""
        }
        
        let unit = avoidLineBreaking ? unit.replacingOccurrences(of: "/", with: "\u{2060}/\u{2060}") : unit
        
        return String(
            format: NSLocalizedString("%1$@%2$@%3$@", comment: "String format for value with units (1: value, 2: separator, 3: units)"),
            stringValue,
            separator,
            unit
        )
    }
}
