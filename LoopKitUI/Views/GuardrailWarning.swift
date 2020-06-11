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
    private enum CrossedThresholds {
        case one(SafetyClassification.Threshold)
        case oneOrMore([SafetyClassification.Threshold])
    }

    private var title: Text
    private var crossedThresholds: CrossedThresholds
    private var customCaption: (_ crossedThresholds: [SafetyClassification.Threshold]) -> Text?

    public init(title: Text, threshold: SafetyClassification.Threshold) {
        self.title = title
        self.crossedThresholds = .one(threshold)
        self.customCaption = { _ in nil }
    }

    public init(
        title: Text,
        thresholds: [SafetyClassification.Threshold],
        customCaption: @escaping (_ crossedThresholds: [SafetyClassification.Threshold]) -> Text? = { _ in nil }
    ) {
        precondition(!thresholds.isEmpty)
        self.title = title
        self.crossedThresholds = .oneOrMore(thresholds)
        self.customCaption = customCaption
    }

    public var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(warningColor)

                    title
                        .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                        .bold()
                        .fixedSize()
                        .animation(nil)
                }

                caption
                    .font(.callout)
                    .foregroundColor(Color(.secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(nil)
            }

            Spacer()
        }
    }

    private var warningColor: Color {
        switch crossedThresholds {
        case .one(let threshold):
            return color(for: threshold)
        case .oneOrMore(let thresholds):
            return color(for: thresholds.max(by: { $0.severity < $1.severity })!)
        }
    }

    private func color(for threshold: SafetyClassification.Threshold) -> Color {
        switch threshold {
        case .minimum, .maximum:
            return .severeWarning
        case .belowRecommended, .aboveRecommended:
            return .warning
        }
    }

    private var caption: Text {
        switch crossedThresholds {
        case .one(let threshold):
            switch threshold {
            case .minimum, .belowRecommended:
                return Text("The value you have chosen is lower than Tidepool generally recommends.", comment: "Warning for entering a low setting value")
            case .aboveRecommended, .maximum:
                return Text("The value you have chosen is higher than Tidepool generally recommends.", comment: "Warning for entering a high setting value")
            }
        case .oneOrMore(let thresholds):
            if let caption = customCaption(thresholds) {
                return caption
            }

            if thresholds.count == 1 {
                switch thresholds.first! {
                case .minimum, .belowRecommended:
                        return Text("A value you have chosen is lower than Tidepool generally recommends.", comment: "Warning for entering a low setting value in a schedule interface")
                case .aboveRecommended, .maximum:
                        return Text("A value you have chosen is higher than Tidepool generally recommends.", comment: "Warning for entering a high setting value in a schedule interface")
                }
            } else {
                return Text("Some of the values you have entered are outside of what Tidepool generally recommends.")
            }
        }
    }
}

fileprivate extension SafetyClassification.Threshold {
    var severity: Int {
        switch self {
        case .belowRecommended, .aboveRecommended:
            return 1
        case .minimum, .maximum:
            return 2
        }
    }
}
