//
//  Keyboard.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/18/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import UIKit


public final class Keyboard: ObservableObject {
    public struct State {
        public var height: CGFloat = 0
        public var animationDuration: TimeInterval = 0.25
    }

    @Published var state = State()
    private var keyboardFrameChangeCancellable: AnyCancellable?

    static let shared = Keyboard()

    private init() {
        keyboardFrameChangeCancellable = NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self, let userInfo = notification.userInfo else {
                    return
                }

                let height: CGFloat
                if let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    height = UIScreen.main.bounds.intersection(keyboardFrame).height
                } else {
                    height = 0
                }

                let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25

                self.state = State(height: height, animationDuration: animationDuration)
            }
    }
}
