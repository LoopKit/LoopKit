//
//  Color.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 1/3/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI

private class FrameworkBundle {
    static let main = Bundle(for: FrameworkBundle.self)
}

extension Color {
    init?(frameworkColor name: String) {
        self.init(name, bundle: FrameworkBundle.main)
    }
}

