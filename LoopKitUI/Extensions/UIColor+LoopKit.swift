//
//  UIColor.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import UIKit

extension UIColor {
    @nonobjc static let COBTintColor: UIColor = {
        return UIColor(dynamicProvider: { (traitCollection) in
            // If we're in accessibility mode, return the system color
            guard case .normal = traitCollection.accessibilityContrast else {
                return .systemGreen
            }

            switch traitCollection.userInterfaceStyle {
            case .unspecified, .light:
                return UIColor(red: 99 / 255, green: 218 / 255, blue: 56 / 255, alpha: 1)
            case .dark:
                return UIColor(red: 89 / 255, green: 228 / 255, blue: 51 / 255, alpha: 1)
            @unknown default:
                return UIColor(red: 99 / 255, green: 218 / 255, blue: 56 / 255, alpha: 1)
            }
        })
    }()
    
    @nonobjc static let glucoseTintColor: UIColor = {
        return UIColor(dynamicProvider: { (traitCollection) in
            // If we're in accessibility mode, return the system color
            guard case .normal = traitCollection.accessibilityContrast else {
                return .systemBlue
            }

            switch traitCollection.userInterfaceStyle {
            case .unspecified, .light:
                return UIColor(red: 0 / 255, green: 176 / 255, blue: 255 / 255, alpha: 1)
            case .dark:
                return UIColor(red: 10 / 255, green: 186 / 255, blue: 255 / 255, alpha: 1)
            @unknown default:
                return UIColor(red: 0 / 255, green: 176 / 255, blue: 255 / 255, alpha: 1)
            }
        })
    }()
}
