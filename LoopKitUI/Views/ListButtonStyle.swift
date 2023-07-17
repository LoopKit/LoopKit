//
//  ListButtonStyle.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/13/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ListButtonStyle: ButtonStyle {
    public init() { }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                Color(UIColor.tertiarySystemFill)
                    .opacity(configuration.isPressed ? 0.5 : 0)
            )
    }
}
