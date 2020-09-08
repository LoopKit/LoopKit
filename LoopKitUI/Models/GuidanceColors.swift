//
//  GuidanceColors.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-07-31.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct GuidanceColors {
    public var acceptable: Color
    public var warning: Color
    public var critical: Color
    
    public init(acceptable: Color, warning: Color, critical: Color)
    {
        self.acceptable = acceptable
        self.warning = warning
        self.critical = critical
    }
    
    public init() {
        self.acceptable = .primary
        self.warning = .yellow
        self.critical = .red
    }
}
