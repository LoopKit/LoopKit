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
    private var captionOverride: Text?

    public init(
        title: Text,
        threshold: SafetyClassification.Threshold,
        caption: Text? = nil
    ) {
        self.title = title
        self.crossedThresholds = .one(threshold)
        self.captionOverride = caption
    }

    public init(
        title: Text,
        thresholds: [SafetyClassification.Threshold],
        caption: Text? = nil
    ) {
        precondition(!thresholds.isEmpty)
        self.title = title
        self.crossedThresholds = .oneOrMore(thresholds)
        self.captionOverride = caption
    }

    public var body: some View {
        WarningView(title: title, caption: caption, severity: severity)
    }

    private var severity: WarningSeverity {
        switch crossedThresholds {
        case .one(let threshold):
            return threshold.severity
        case .oneOrMore(let thresholds):
            return thresholds.lazy.map({ $0.severity }).max()!
        }
    }

    private var caption: Text {
        if let caption = captionOverride {
            return caption
        }

        switch crossedThresholds {
        case .one(let threshold):
            // Chose to use premeal range override because it's not a schedule
            switch threshold {
            case .minimum, .belowRecommended:
                return Text(TherapySetting.preMealCorrectionRangeOverride.guardrailCaptionForLowValue)
            case .aboveRecommended, .maximum:
                return Text(TherapySetting.preMealCorrectionRangeOverride.guardrailCaptionForHighValue)
            }
        case .oneOrMore(let thresholds):
            // Chose to use correction range because it's a schedule
            if thresholds.count == 1 {
                switch thresholds.first! {
                case .minimum, .belowRecommended:
                    return Text(TherapySetting.glucoseTargetRange.guardrailCaptionForLowValue)
                case .aboveRecommended, .maximum:
                    return Text(TherapySetting.glucoseTargetRange.guardrailCaptionForHighValue)
                }
            } else {
                return Text(LocalizedString("Some of the values you have entered are outside of what is typically recommended for most people.", comment: "Caption for guardrail warning when more than one threshold is crossed"))
            }
        }
    }
}

fileprivate extension SafetyClassification.Threshold {
    var severity: WarningSeverity {
        switch self {
        case .belowRecommended, .aboveRecommended:
            return .default
        case .minimum, .maximum:
            return .critical
        }
    }
}
