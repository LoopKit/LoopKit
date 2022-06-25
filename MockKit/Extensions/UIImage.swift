//
//  UIImage.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2021-02-16.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

// TODO: UIKit should not be in MockKit

import UIKit

private class FrameworkBundle {
    static let main = Bundle(for: FrameworkBundle.self)
}

extension UIImage {
    convenience init?(frameworkImage name: String) {
        self.init(named: name, in: FrameworkBundle.main, with: nil)
    }
}
