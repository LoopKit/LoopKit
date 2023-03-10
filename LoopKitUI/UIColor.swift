//
//  UIColor.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
import UIKit

private class LocalBundle {
    /// Returns the resource bundle associated with the current Swift module.
    static var main: Bundle = {
        if let mainResourceURL = Bundle.main.resourceURL,
           let bundle = Bundle(url: mainResourceURL.appendingPathComponent("LoopKitUI_LoopKitUI.bundle"))
        {
            return bundle
        }
        return Bundle(for: LocalBundle.self)
    }()
}

private func BundleColor(_ name: String, compatibleWith traitCollection: UITraitCollection? = nil) -> UIColor? {
    return UIColor(named: name, in: LocalBundle.main, compatibleWith: traitCollection)
}

extension UIColor {
    @nonobjc static let lightenedInsulin = BundleColor("Lightened Insulin") ?? systemOrange
    
    @nonobjc static let darkenedInsulin = BundleColor("Darkened Insulin") ?? systemOrange
    
    static func interpolatingBetween(_ first: UIColor, _ second: UIColor, biasTowardSecondColor bias: CGFloat = 0.5) -> UIColor {
        let (r1, g1, b1, a1) = first.components
        let (r2, g2, b2, a2) = second.components
        return UIColor(
            red: (r2 - r1) * bias + r1,
            green: (g2 - g1) * bias + g1,
            blue: (b2 - b1) * bias + b1,
            alpha: (a2 - a1) * bias + a1
        )
    }

    var components: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r, g, b, a: CGFloat
        (r, g, b, a) = (0, 0, 0, 0)
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (red: r, green: g, blue: b, alpha: a)
    }
}
