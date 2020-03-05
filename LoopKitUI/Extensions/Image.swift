//
//  Image.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

private class FrameworkBundle {
    static let main = Bundle(for: FrameworkBundle.self)
}

public extension Image {
    init(frameworkImage name: String) {
        self.init(name, bundle: FrameworkBundle.main)
    }
}
