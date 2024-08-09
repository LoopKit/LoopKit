//
//  LoopCircleView.swift
//  LoopKitUI
//
//  Created by Arwain Karlin on 5/8/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct LoopCircleView: View {
    @Environment(\.loopStatusColorPalette) private var loopStatusColors
    @Environment(\.isEnabled) private var isEnabled
    
    private let animating: Bool
    private let closedLoop: Bool
    private let freshness: LoopCompletionFreshness
    
    public init(closedLoop: Bool, freshness: LoopCompletionFreshness, animating: Bool = false) {
        self.closedLoop = closedLoop
        self.freshness = freshness
        self.animating = animating
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .trim(from: closedLoop ? 0 : 0.2, to: 1)
                .stroke(!isEnabled ? Color(UIColor.systemGray3) : loopColor, lineWidth: 8)
                .scaleEffect(animating && closedLoop ? 0.7 : 1)
                .rotationEffect(Angle(degrees: closedLoop ? -90 : -126))
                .frame(width: 36, height: 36)
                .animation(animating && closedLoop ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: animating)
                .animation(.default, value: closedLoop)
            
            VStack {
                Text(animating.description)
                Text(closedLoop.description)
                Text(freshness.description)
            }
            .font(.footnote)
        }
    }
    
    private var loopColor: Color {
        switch freshness {
        case .fresh:
            return Color(uiColor: loopStatusColors.normal)
        case .aging:
            return Color(uiColor: loopStatusColors.warning)
        case .stale:
            return Color(uiColor: loopStatusColors.error)
        }
    }
}

extension LoopCompletionFreshness {
    var description: String {
        switch self {
        case .fresh:
            return "fresh"
        case .aging:
            return "aging"
        case .stale:
            return "stale"
        }
    }
}
