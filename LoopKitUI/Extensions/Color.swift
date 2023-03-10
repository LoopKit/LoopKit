//
//  Color.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 1/3/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI

private class LocalBundle {
    /// Returns the resource bundle associated with the current Swift module.
    static var main: Bundle = {
        if let mainResourceURL = Bundle.main.resourceURL,
           let bundle = Bundle(url: mainResourceURL.appendingPathComponent("LoopKitUI_LoopKitUI.bundle"))
        {
            return bundle
        }
        return Bundle(for: LocalBundle.self)
    }()
}

extension Color {
    init?(frameworkColor name: String) {
        self.init(name, bundle: LocalBundle.main)
    }
}

