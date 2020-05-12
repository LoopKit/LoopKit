//
//  ActivityIndicator.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/10/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import SwiftUI

public struct ActivityIndicator: UIViewRepresentable {

    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style
    
    public init(isAnimating: Binding<Bool>, style: UIActivityIndicatorView.Style) {
        self._isAnimating = isAnimating
        self.style = style
    }

    public func makeUIView(context: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        return UIActivityIndicatorView(style: style)
    }

    public func updateUIView(_ uiView: UIActivityIndicatorView, context: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}
