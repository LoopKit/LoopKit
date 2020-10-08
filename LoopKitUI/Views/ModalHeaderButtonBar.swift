//
//  ModalHeaderButtonBar.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


struct ModalHeaderButtonBar<Leading: View, Center: View, Trailing: View>: View {
    var leading: Leading
    var center: Center
    var trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    leading
                    Spacer()
                }

                center

                HStack {
                    Spacer()
                    trailing
                }
            }
            .padding()
            .background(Color(.defaultNavigationBar))
            .cornerRadius(10, corners: [.topLeft, .topRight])

            Divider()
        }
    }
}

extension UIColor {
    static let defaultNavigationBar = UIColor(dynamicProvider: { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 40/255, green: 41/255, blue: 40/255, alpha: 1)
        } else {
            return UIColor(red: 248/255, green: 248/255, blue: 248/255, alpha: 1)
        }
    })
}
