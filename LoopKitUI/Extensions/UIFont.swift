//
//  UIFont.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-17.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

extension UIFont {
    public static var titleFontGroupedInset: UIFont {
        return UIFontMetrics(forTextStyle: .title1).scaledFont(for: systemFont(ofSize: 28, weight: .semibold))
    }
    
    public static var sectionHeaderFontGroupedInset: UIFont {
        return UIFontMetrics(forTextStyle: .headline).scaledFont(for: systemFont(ofSize: 19, weight: .semibold))
    }
    
    public static var footnote: UIFont {
        return preferredFont(forTextStyle: .footnote)
    }
    
    public static var instructionTitle: UIFont {
        return preferredFont(forTextStyle: .headline)
    }
    
    public static var instructionStep: UIFont {
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: systemFont(ofSize: 14))
    }
    
    public static var instructionNumber: UIFont {
        return preferredFont(forTextStyle: .subheadline)
    }
    
    public static var inputValue: UIFont {
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: systemFont(ofSize: 48))
    }
}
