//
//  GuidePage.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct GuidePage<Content>: View where Content: View {
    
    let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    self.content()
                }
                .padding()
                .frame(minHeight: geometry.size.height)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
    }
}

struct GuidePage_Previews: PreviewProvider {
    static var previews: some View {
        GuidePage() {
            Text("content")
            Text("more content")
            Image(systemName: "circle")
        }
    }
}
