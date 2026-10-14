//
//  UIImage.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-15.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
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

extension UIImage {
    convenience init?(frameworkImage name: String) {
        self.init(named: name, in: LocalBundle.main, with: nil)
    }

    public func tintedForTextAttachment(_ color: UIColor, size: CGSize) -> UIImage {
        let tinted = withTintColor(color, renderingMode: .alwaysOriginal)
        return UIGraphicsImageRenderer(size: size).image { _ in
            tinted.draw(in: CGRect(origin: .zero, size: size))
        }
        .withRenderingMode(.alwaysOriginal)
    }
}
