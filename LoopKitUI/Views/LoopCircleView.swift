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
    
    private let animationAllowed: Bool
    private let closedLoop: Bool
    private let freshness: LoopCompletionFreshness
    private let deviceInoperable: Bool
    
    public init(animationAllowed: Bool = false, closedLoop: Bool, freshness: LoopCompletionFreshness, deviceInoperable: Bool = false) {
        self.animationAllowed = animationAllowed
        self.closedLoop = closedLoop
        self.freshness = freshness
        self.deviceInoperable = deviceInoperable
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
            .trim(from: closedLoop ? 0 : 0.25, to: 1)
            .stroke(loopColor, lineWidth: 8)
            .rotationEffect(Angle(degrees: closedLoop ? -90 : -135))
            .animation(.none, value: freshness)
            .animation(.none, value: animating)
            .animation(.default, value: closedLoop)
            .scaleEffect(animating && closedLoop ? 0.75 : 1)
            .animation(reversingAnimation, value: UUID())
            .frame(width: 36, height: 36)
    }
    
    private var animating: Bool {
        if !isEnabled {
            return false
        } else if deviceInoperable {
            return animationAllowed && true
        } else {
            switch freshness {
            case .fresh:
                return false
            case .aging, .stale:
                return animationAllowed && true
            }
        }
    }
    
    private var loopColor: Color {
        if !isEnabled {
            return Color(UIColor.systemGray3)
        } else if deviceInoperable {
            return Color(uiColor: loopStatusColors.unknown)
        } else {
            switch freshness {
            case .fresh:
                return Color(uiColor: loopStatusColors.normal)
            case .aging:
                return Color(uiColor: loopStatusColors.unknown)
            case .stale:
                return Color(uiColor: loopStatusColors.unknown)
            }
        }
    }
}
