//
//  NumberCircle.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 6/12/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct NumberCircle: View {
    private let number: Int

    @ScaledMetric var size: CGFloat = 21

    public init(_ number: Int) {
        self.number = number
    }

    public var body: some View {
        ZStack {
            Circle()
                .foregroundColor(.accentColor)
                .frame(width: size, height: size)
            Text("\(number)")
                .font(.footnote)
                .foregroundColor(.white)
        }
    }
}
