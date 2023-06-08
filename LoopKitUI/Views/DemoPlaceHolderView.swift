//
//  DemoPlaceHolderView.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2023-05-18.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct DemoPlaceHolderView: View {
    var appName: String
    
    public init(appName: String) {
        self.appName = appName
    }
    
    public var body: some View {
        ZStack {
            Color.accentColor.opacity(0.1).ignoresSafeArea()

            VStack {
                Image(frameworkImage: "DemoPlaceholderImage")
                    .resizable()
                    .aspectRatio(contentMode: ContentMode.fit)
                    .padding(.trailing, 80)
                                
                VStack(alignment: .center, spacing: 30) {
                    Text("Nothing to See Here!")
                        .font(.title2)
                        .bold()
                    
                    Text("This section of the \(appName) app is unavailable in this simulator.")
                        .multilineTextAlignment(.center)
                    
                    Text("Tap back to continue exploring the rest of the \(appName) interface.")
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.leading, 0)
        }
    }
}

struct DemoPlaceHolderView_Previews: PreviewProvider {
    static var previews: some View {
        DemoPlaceHolderView(appName: "Loop")
    }
}
