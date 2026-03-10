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
    
    @State private var isPulsing: Bool = false
    
    private let animationAllowed: Bool
    private let closedLoop: Bool
    private let freshness: LoopCompletionFreshness
    private let deviceIssue: Bool
    
    public init(animationAllowed: Bool = false, closedLoop: Bool, freshness: LoopCompletionFreshness, deviceIssue: Bool = false) {
        self.animationAllowed = animationAllowed
        self.closedLoop = closedLoop
        self.freshness = freshness
        self.deviceIssue = deviceIssue
    }
    
    private var pulsingAnimation: Animation {
        shouldPulse ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .easeInOut(duration: 1)
    }
    
    public var body: some View {
        Circle()
            .trim(from: closedLoop ? 0 : 0.25, to: 1)
            .stroke(loopColor, lineWidth: 8)
            .rotationEffect(Angle(degrees: closedLoop ? -90 : -135))
            .scaleEffect(isPulsing ? 0.75 : 1)
            .frame(width: 36, height: 36)
            .animation(pulsingAnimation, value: isPulsing)
            .animation(.default, value: closedLoop)
            .animation(.default, value: freshness)
            .onAppear {
                isPulsing = shouldPulse
            }
            .onChange(of: shouldPulse) { _, newValue in
                isPulsing = newValue
            }
    }
    
    private var loopColor: Color {
        if !isEnabled {
            return Color(UIColor.systemGray3)
        } else if isEnabled && !deviceIssue && freshness == .fresh {
            return Color(uiColor: loopStatusColors.normal)
        } else {
            return Color(uiColor: loopStatusColors.unknown)
        }
    }
    
    private var shouldPulse: Bool {
        isEnabled && closedLoop && animationAllowed && (deviceIssue || freshness == .aging || freshness == .stale)
    }
}
