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
    
    @Binding private var animating: Bool
    @Binding private var closedLoop: Bool
    @Binding private var freshness: LoopCompletionFreshness
    
    public init(closedLoop: Binding<Bool>, freshness: Binding<LoopCompletionFreshness>, animating: Binding<Bool> = .constant(false)) {
        self._closedLoop = closedLoop
        self._freshness = freshness
        self._animating = animating
    }
    
    public init(closedLoop: Bool, freshness: LoopCompletionFreshness, animating: Bool = false) {
        self.init(
            closedLoop: .constant(closedLoop),
            freshness: .constant(freshness),
            animating: .constant(animating)
        )
    }
    
    public var body: some View {
        let loopColor = getLoopColor(freshness: freshness)
        
        Circle()
            .trim(from: closedLoop ? 0 : 0.2, to: 1)
            .stroke(!isEnabled ? Color(UIColor.systemGray3) : loopColor, lineWidth: animating && closedLoop ? 12 : 8)
            .scaleEffect(animating && closedLoop ? 0.7 : 1)
            .animation(.easeInOut(duration: 1).repeat(while: animating && closedLoop, autoreverses: true), value: animating)
            .frame(width: 36, height: 36)
            .rotationEffect(Angle(degrees: closedLoop ? -90 : -126))
            .animation(.default, value: closedLoop)
    }
    
    func getLoopColor(freshness: LoopCompletionFreshness) -> Color {
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

extension Animation {
    func `repeat`(while expression: Bool, autoreverses: Bool = true) -> Animation {
        if expression {
            return self.repeatForever(autoreverses: autoreverses)
        } else {
            return self
        }
    }
}
