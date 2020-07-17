//
//  GlucoseTrend.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-15.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension GlucoseTrend {
    public var image: UIImage? {
        switch self {
        case .upUpUp:
            return UIImage(frameworkImage: "arrow.double.up.circle")
        case .upUp:
            return UIImage(systemName: "arrow.up.circle")
        case .up:
            return UIImage(systemName: "arrow.up.right.circle")
        case .flat:
            return UIImage(systemName: "arrow.right.circle")
        case .down:
            return UIImage(systemName: "arrow.down.right.circle")
        case .downDown:
            return UIImage(systemName: "arrow.down.circle")
        case .downDownDown:
            return UIImage(frameworkImage: "arrow.double.down.circle")
        }
    }
}
