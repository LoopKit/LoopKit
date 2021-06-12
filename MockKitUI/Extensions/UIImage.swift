//
//  UIImage.swift
//  MockKitUI
//
//  Created by Pete Schwamb on 5/11/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit

private class FrameworkBundle {
    static let main = Bundle(for: FrameworkBundle.self)
}

extension UIImage {
    convenience init?(frameworkImage name: String) {
        self.init(named: name, in: FrameworkBundle.main, with: nil)
    }
}
