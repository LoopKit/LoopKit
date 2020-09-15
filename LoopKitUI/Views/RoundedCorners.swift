//
//  RoundedCorners.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorners(radius: radius, corners: corners))
    }
}

struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
