//
//  Color.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

extension Color {
    public static let destructive = red

    public static let severeWarning = red
    public static let warning = Color(UIColor(dynamicProvider: { traitCollection in
        return traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.902, green: 0.494, blue: 0.039, alpha: 1)
            : UIColor(red: 0.863, green: 0.455, blue: 0, alpha: 1)
    }))
    
    public static let instructionalContent = Color.secondary
}
