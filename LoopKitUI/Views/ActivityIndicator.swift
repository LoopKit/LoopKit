//
//  ActivityIndicator.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ActivityIndicator: UIViewRepresentable {

    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style
    let color: UIColor?
    
    public init(isAnimating: Binding<Bool>, style: UIActivityIndicatorView.Style, color: UIColor? = nil) {
        self._isAnimating = isAnimating
        self.style = style
        self.color = color
    }

    public func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        let activityIndicator = UIActivityIndicatorView(style: style)
        activityIndicator.color = color
        return activityIndicator
    }

    public func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}
