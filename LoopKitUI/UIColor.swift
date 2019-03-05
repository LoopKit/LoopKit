//
//  UIColor.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

private class FrameworkBundle {
    static let main = Bundle(for: FrameworkBundle.self)
}

private func BundleColor(_ name: String, compatibleWith traitCollection: UITraitCollection? = nil) -> UIColor? {
    return UIColor(named: name, in: FrameworkBundle.main, compatibleWith: traitCollection)
}

extension UIColor {
    static let delete = BundleColor("Delete")
    static let invalid = BundleColor("Invalid")
}


