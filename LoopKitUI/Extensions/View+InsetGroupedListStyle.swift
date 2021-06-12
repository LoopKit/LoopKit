//
//  View+InsetGroupedListStyle.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


extension View {

    public func insetGroupedListStyle() -> some View {
        modifier(CustomInsetGroupedListStyle())
    }
}

fileprivate struct CustomInsetGroupedListStyle: ViewModifier, HorizontalSizeClassOverride {

    @ViewBuilder func body(content: Content) -> some View {
        // For compact sizes (e.g. iPod Touch), don't inset, in order to more efficiently utilize limited real estate
        if horizontalOverride == .compact {
            content
                .listStyle(GroupedListStyle())
                .environment(\.horizontalSizeClass, horizontalOverride)
        } else {
            content
                .listStyle(InsetGroupedListStyle())
                .environment(\.horizontalSizeClass, horizontalOverride)
        }
    }
}
