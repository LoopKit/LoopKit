//
//  ConfigurationPageScrollView.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 12/30/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import SwiftUI

// ConfigurationPageScrollView is a ScrollView (not List) based configuration page.
// The optional action area is pinned to the bottom, but does not overlay any content

public struct ConfigurationPageScrollView<Content: View, ActionArea: View>: View {

    var content: Content
    var actionArea: ActionArea?

    public init(@ViewBuilder content: () -> Content, @ViewBuilder actionArea: () -> ActionArea?) {
        self.content = content()
        self.actionArea = actionArea()
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    content
                    Spacer()
                    actionArea
                }
                .frame(minHeight: geometry.size.height)
            }
            .background(Color(.systemGroupedBackground))
            .background(ignoresSafeAreaEdges: .bottom)
        }
    }
}
