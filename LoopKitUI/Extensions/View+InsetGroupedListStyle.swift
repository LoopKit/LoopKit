//
//  View+InsetGroupedListStyle.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/25/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


// NOTE: In iOS 13, the InsetGroupedListStyle is "hacked" by using "GroupedListStyle" with a horizontal size class override.
extension View {

    public func insetGroupedListStyle() -> some View {
        modifier(CustomInsetGroupedListStyle())
    }
}

fileprivate struct CustomInsetGroupedListStyle: ViewModifier, HorizontalSizeClassOverride {

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 14.0, *) {
            content
                .listStyle(InsetGroupedListStyle())
        } else {
            // Fallback on earlier versions
            content
                .listStyle(GroupedListStyle())
                .environment(\.horizontalSizeClass, horizontalOverride)
        }
    }
}
