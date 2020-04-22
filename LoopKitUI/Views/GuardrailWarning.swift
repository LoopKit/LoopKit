//
//  GuardrailWarning.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit


public struct GuardrailWarning: View {
    var title: Text
    var threshold: SafetyClassification.Threshold

    public init(title: Text, threshold: SafetyClassification.Threshold) {
        self.threshold = threshold
        self.title = title
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(accentColor)

                    title
                        .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                        .bold()
                        .fixedSize()
                        .animation(nil)
                }

                caption
                    .font(.callout)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(nil)
            }

            Spacer()
        }
    }

    private var accentColor: Color {
        switch threshold {
            case .minimum, .maximum:
                return .severeWarning
            case .belowRecommended, .aboveRecommended:
                return .warning
        }
    }

    private var caption: Text {
        switch threshold {
        case .minimum:
            return Text("The value you have chosen is the lowest possible and outside what Tidepool recommends.", comment: "Warning for entering a setting's minimum value")
        case .belowRecommended:
            return Text("The value you have chosen is lower than Tidepool recommends.", comment: "Warning for entering a low setting value")
        case .aboveRecommended:
            return Text("The value you have chosen is higher than Tidepool recommends.", comment: "Warning for entering a high setting value")
        case .maximum:
            return Text("The value you have chosen is the highest possible and outside what Tidepool recommends.", comment: "Warning for entering a setting's highest value")
        }
    }
}
