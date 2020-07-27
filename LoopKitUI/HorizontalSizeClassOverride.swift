//
//  HorizontalSizeClassOverride.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 6/5/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public protocol HorizontalSizeClassOverride {
    var horizontalOverride: UserInterfaceSizeClass { get }
}

public extension HorizontalSizeClassOverride {
    var horizontalOverride: UserInterfaceSizeClass {
        if UIScreen.main.bounds.height <= 640 {
            return .compact
        } else {
            return .regular
        }
    }
}
