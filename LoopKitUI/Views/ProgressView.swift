//
//  ProgressView.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

// TODO: SwiftUI now has built in ProgressView to replace this

public struct ProgressView: View {
    
    private let progress: CGFloat
    
    private let barHeight: CGFloat = 8
    
    public init(progress: CGFloat) {
        self.progress = progress
    }
    
    public var body: some View {
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .opacity(0.1)
                    .cornerRadius(self.barHeight/2)
                    .animation(nil)
                Rectangle()
                    .foregroundColor(Color.accentColor)
                    .frame(width: geometry.size.width * self.progress)
                    .cornerRadius(self.barHeight/2)

            }
        }
        .frame(height: barHeight)
    }
}

struct ProgressTestView: View {
    
    @State var showDetail: Bool = false
    @State var madeProgress: Bool = false
    
    var body: some View {
        VStack {
            
            ProgressView(progress: madeProgress ? 0.9 : 0.5)
                .animation(.linear(duration: 2))
                .padding()
                .opacity(showDetail ? 1 : 0)
                .animation(.linear(duration: 0.2))
            Button("Test") {
                self.showDetail.toggle()
                self.madeProgress.toggle()
            }
        }
        .animation(.linear(duration: 0.2))
    }
}


struct ProgressView_Previews: PreviewProvider {
    @State var showDetail: Bool = false
    
    static var previews: some View {
        ProgressTestView()
    }
}
