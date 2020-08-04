//
//  View+KeyboardAware.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


// NOTE: In iOS 14, keyboard management is handled automatically in SwiftUI.
extension View {
    public func onKeyboardStateChange(perform updateForKeyboardState: @escaping (_ keyboardHeight: Keyboard.State) -> Void) -> some View {
        onReceive(Keyboard.shared.$state, perform: updateForKeyboardState)
    }

    public func keyboardAware() -> some View {
        modifier(KeyboardAware())
    }
}

fileprivate struct KeyboardAware: ViewModifier {
    @State var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .edgesIgnoringSafeArea(keyboardHeight > 0 ? .bottom : [])
            .onKeyboardStateChange { state in
                if state.height == 0 {
                    // Only animate the transition as the keyboard comes up; animating the opposite direction is jittery.
                    self.keyboardHeight = 0
                } else {
                    withAnimation(.easeInOut(duration: state.animationDuration)) {
                        self.keyboardHeight = state.height
                    }
                }
            }
    }
}
