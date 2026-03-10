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

    private var therapySetting: TherapySetting
    private var title: Text
    private var crossedThresholds: [SafetyClassification.Threshold]
    private var captionOverride: Text?

    public init(
        therapySetting: TherapySetting,
        title: Text,
        threshold: SafetyClassification.Threshold,
        caption: Text? = nil
    ) {
        self.therapySetting = therapySetting
        self.title = title
        self.crossedThresholds = [threshold]
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
        self.crossedThresholds = thresholds
        self.captionOverride = caption
    }

    public var body: some View {
        WarningView(title: title, caption: caption, severity: severity)
    }

    private var severity: WarningSeverity {
        return crossedThresholds.map { $0.severity }.max()!
    }

    private var caption: Text {
        if let caption = captionOverride {
            return caption
        }

        return Text(SafetyClassification.captionForCrossedThresholds(crossedThresholds, isRange: therapySetting.isRange));
    }
}

extension SafetyClassification.Threshold {
    public var severity: WarningSeverity {
        switch self {
        case .belowRecommended, .aboveRecommended:
            return .default
        case .belowWarning, .aboveWarning:
            return .critical
        case .minimum, .maximum:
            return .critical
        }
    }
}
