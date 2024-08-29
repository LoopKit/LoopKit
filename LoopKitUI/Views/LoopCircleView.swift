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
    
    private var reversingAnimation: Animation {
        if animating && closedLoop {
            return .easeInOut(duration: 1).repeatForever(autoreverses: true)
        } else {
            return .easeInOut(duration: 1)
        }
    }
    
    public var body: some View {
        Circle()
            .trim(from: closedLoop ? 0 : 0.2, to: 1)
            .stroke(loopColor, lineWidth: 8)
            .rotationEffect(Angle(degrees: closedLoop ? -90 : -126))
            .animation(.default, value: freshness)
            .animation(.default, value: closedLoop)
            .scaleEffect(animating && closedLoop ? 0.75 : 1)
            .animation(reversingAnimation, value: UUID())
            .frame(width: 36, height: 36)
    }
    
    private var loopColor: Color {
        if !isEnabled {
            return Color(UIColor.systemGray3)
        } else {
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
}
