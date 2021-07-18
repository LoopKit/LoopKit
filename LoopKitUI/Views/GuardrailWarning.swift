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

    private var therapySetting: TherapySetting
    private var title: Text
    private var crossedThresholds: CrossedThresholds
    private var captionOverride: Text?

    public init(
        therapySetting: TherapySetting,
        title: Text,
        threshold: SafetyClassification.Threshold,
        caption: Text? = nil
    ) {
        self.therapySetting = therapySetting
        self.title = title
        self.crossedThresholds = .one(threshold)
        self.captionOverride = caption
    }

    public init(
        therapySetting: TherapySetting,
        title: Text,
        thresholds: [SafetyClassification.Threshold],
        caption: Text? = nil
    ) {
        precondition(!thresholds.isEmpty)
        self.therapySetting = therapySetting
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
            return captionForThreshold(threshold)
        case .oneOrMore(let thresholds):
            if thresholds.count == 1, let threshold = thresholds.first {
                return captionForThreshold(threshold)
            } else {
                return captionForThresholds()
            }
        }
    }

    private func captionForThreshold(_ threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum, .belowRecommended:
            return Text(therapySetting.guardrailCaptionForLowValue)
        case .aboveRecommended, .maximum:
            return Text(therapySetting.guardrailCaptionForHighValue)
        }
    }

    private func captionForThresholds() -> Text {
        return Text(therapySetting.guardrailCaptionForOutsideValues)
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
