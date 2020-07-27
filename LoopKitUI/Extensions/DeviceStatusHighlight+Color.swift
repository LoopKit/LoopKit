//
//  DeviceStatusHighlight+Color.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-06.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension DeviceStatusHighlight {
    public var image: UIImage? {
        if let image = UIImage(frameworkImage: imageName) {
            return image
        } else {
            return UIImage(systemName: imageName)
        }
    }
    
    public var color: UIColor {
        switch state {
        case .normal:
            return .systemPurple
        case .warning:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }
}
