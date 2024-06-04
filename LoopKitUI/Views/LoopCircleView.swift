//
//  LoopCircleView.swift
//  LoopKitUI
//
//  Created by Arwain Karlin on 5/8/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

public struct LoopCircleView: View {
    private class _Dummy {}
    
    @Environment(\.isEnabled) private var isEnabled
    
    let closedLoop: Bool
    let freshness: LoopCompletionFreshness
    
    public init(closedLoop: Bool, freshness: LoopCompletionFreshness) {
        self.closedLoop = closedLoop
        self.freshness = freshness
    }
    
    public var body: some View {
        let loopColor = getLoopColor(freshness: freshness)
        
        Circle()
            .trim(from: closedLoop ? 0 : 0.2, to: 1)
            .stroke(!isEnabled ? Color(UIColor.systemGray3) : loopColor, lineWidth: 8)
            .rotationEffect(Angle(degrees: -126))
            .frame(width: 36, height: 36)
    }
    
    func getLoopColor(freshness: LoopCompletionFreshness) -> Color {
        switch freshness {
        case .fresh:
            return Color("Fresh", bundle: Bundle(for: _Dummy.self))
        case .aging:
            return Color("Warning", bundle: Bundle(for: _Dummy.self))
        case .stale:
            return Color.red
        }
    }
}
