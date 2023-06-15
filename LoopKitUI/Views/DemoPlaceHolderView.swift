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
        VStack(alignment: .center, spacing: 30) {
            Spacer()
            
            Image(systemName: "minus.circle")
                .font(Font.system(size: 76, weight: .bold))
            
            Text("Nothing to See Here!")
                .font(.title2)
                .bold()
            
            Text("This section of the \(appName) app is unavailable in this simulator.")
                .multilineTextAlignment(.center)
            
            Text("Tap back to continue exploring the rest of the \(appName) interface.")
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DemoPlaceHolderView_Previews: PreviewProvider {
    static var previews: some View {
        DemoPlaceHolderView(appName: "Loop")
    }
}
