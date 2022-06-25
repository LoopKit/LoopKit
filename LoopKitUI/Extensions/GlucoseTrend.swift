//
//  GlucoseTrend.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-15.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
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
    
    public var filledImage: Image {
        switch self {
        case .upUpUp:
            return Image(frameworkImage: "arrow.double.up.fill")
        case .upUp:
            return Image(systemName: "arrow.up.circle.fill")
        case .up:
            return Image(systemName: "arrow.up.right.circle.fill")
        case .flat:
            return Image(systemName: "arrow.right.circle.fill")
        case .down:
            return Image(systemName: "arrow.down.right.circle.fill")
        case .downDown:
            return Image(systemName: "arrow.down.circle.fill")
        case .downDownDown:
            return Image(frameworkImage: "arrow.double.down.fill")
        }
    }
    
}
