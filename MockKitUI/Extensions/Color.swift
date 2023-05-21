//
//  Color.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
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

