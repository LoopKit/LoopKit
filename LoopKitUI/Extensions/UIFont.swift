//
//  UIFont.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-01-17.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension UIFont {
    public static var titleFontGroupedInset: UIFont {
        return UIFont.systemFont(ofSize: 28, weight: UIFont.Weight.semibold)
    }
    
    public static var sectionHeaderFontGroupedInset: UIFont {
        return UIFont.systemFont(ofSize: 19, weight: UIFont.Weight.semibold)
    }
    
    public static var descriptiveText: UIFont {
        return UIFont.systemFont(ofSize: 13)
    }
}
