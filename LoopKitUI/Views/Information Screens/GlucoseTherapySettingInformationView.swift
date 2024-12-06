//
//  GlucoseTherapySettingInformationView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

public struct GlucoseTherapySettingInformationView<Content: View>: View {
    var text: Content?
    let onExit: (() -> Void)?
    let mode: SettingsPresentationMode
    let therapySetting: TherapySetting
    let preferredUnit: LoopUnit
    let appName: String
    
    @Environment(\.presentationMode) var presentationMode

    public init(
        therapySetting: TherapySetting,
        preferredUnit: LoopUnit? = nil,
        onExit: (() -> Void)?,
        mode: SettingsPresentationMode = .acceptanceFlow,
        appName: String,
        text: Content? = nil
    ){
        self.therapySetting = therapySetting
        self.preferredUnit = preferredUnit ?? .milligramsPerDeciliter
        self.onExit = onExit
        self.mode = mode
        self.appName = appName
        self.text = text
    }
    
    public init(
        therapySetting: TherapySetting,
        preferredUnit: LoopUnit? = nil,
        onExit: (() -> Void)?,
        mode: SettingsPresentationMode = .acceptanceFlow,
        appName: String,
        text: Content? = nil
    ) where Content == EmptyView {
        self.therapySetting = therapySetting
        self.preferredUnit = preferredUnit ?? .milligramsPerDeciliter
        self.onExit = onExit
        self.mode = mode
        self.appName = appName
        self.text = text
    }
    
    public var body: some View {
        InformationView(
            title: Text(self.therapySetting.title),
            informationalContent: {
                illustration
                bodyText
            },
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var illustration: some View {
        Image(frameworkImage: illustrationImageName)
            .renderingMode(.original)
            .resizable()
            .aspectRatio(contentMode: ContentMode.fit)
    }
    
    private var bodyText: some View {
        VStack(alignment: .leading, spacing: 25) {
            if let text {
                text
            } else {
                Text(therapySetting.descriptiveText(appName: appName))
            }
            
            Text(therapySetting.guardrailInformationText)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private var illustrationImageName: String {
        return "\(therapySetting) \(preferredUnit.hkUnit.description.replacingOccurrences(of: "/", with: ""))"
    }
}

fileprivate extension TherapySetting {
    // TODO: pass in preferredUnit instead of having both units.
    var guardrailInformationText: String {
        switch self {
        case .glucoseTargetRange:
            return lowHighText(for: Guardrail.correctionRange)
        case .preMealCorrectionRangeOverride:
            return lowHighText(lowerBoundString: LocalizedString("your Glucose Safety Limit", comment: "Lower bound pre-meal information text"),
                               upperBoundString: Guardrail.premealCorrectionRangeMaximum.bothUnitsString)
        case .workoutCorrectionRangeOverride:
            return lowHighText(
                lowerBoundString: String(format: LocalizedString("%1$@ or your Glucose Safety Limit, whichever is higher", comment: "Lower bound workout information text format (1: app name)"), Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.lowerBound.bothUnitsString),
                upperBoundString: Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.upperBound.bothUnitsString)
        case .suspendThreshold:
            return lowHighText(for: Guardrail.suspendThreshold)
        case .basalRate, .deliveryLimits, .insulinModel, .carbRatio, .insulinSensitivity, .none:
            fatalError("Unexpected")
        }
    }
       
    func lowHighText(for guardrail: Guardrail<LoopQuantity>) -> String {
        return lowHighText(lowerBoundString: guardrail.absoluteBounds.lowerBound.bothUnitsString,
                           upperBoundString: guardrail.absoluteBounds.upperBound.bothUnitsString)
    }

    func lowHighText(lowerBoundString: String, upperBoundString: String) -> String {
        return String(format: LocalizedString("It can be set as low as %1$@. It can be set as high as %2$@.",
                                              comment: "Guardrail info text format"), lowerBoundString, upperBoundString)
    }
}
