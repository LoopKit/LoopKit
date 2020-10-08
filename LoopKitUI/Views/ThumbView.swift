//
//  ThumbView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 2/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit


class ThumbView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundColor = .white
        makeRound()
        configureDropShadow()
    }

    private func makeRound() {
        layer.cornerRadius = min(frame.width, frame.height) / 2
    }

    private func configureDropShadow() {
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: -2, height: 0)
    }
}
