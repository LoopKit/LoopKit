//
//  GlucoseTherapySettingInformationView.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct GlucoseTherapySettingInformationView<Content: View>: View {
    var text: Content?
    let onExit: (() -> Void)?
    let mode: SettingsPresentationMode
    let therapySetting: TherapySetting
    let preferredUnit: HKUnit
    let appName: String
    
    @Environment(\.presentationMode) var presentationMode

    public init(
        therapySetting: TherapySetting,
        preferredUnit: HKUnit? = nil,
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
        preferredUnit: HKUnit? = nil,
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
        return "\(therapySetting) \(preferredUnit.description.replacingOccurrences(of: "/", with: ""))"
    }
}

fileprivate let mgdLFormatter = QuantityFormatter(for: .milligramsPerDeciliter)
fileprivate let mmolLFormatter = QuantityFormatter(for: .millimolesPerLiter)

fileprivate extension TherapySetting {
    // TODO: pass in preferredUnit instead of having both units.
    var guardrailInformationText: String {
        switch self {
        case .glucoseTargetRange:
            return lowHighText(for: Guardrail.correctionRange)
        case .preMealCorrectionRangeOverride:
            let mgdlMax = Guardrail.premealCorrectionRangeMaximum.doubleValue(
                for: .milligramsPerDeciliter,
                withRounding: true,
                rule: .down
            )
            let mmolMax = Guardrail.premealCorrectionRangeMaximum.doubleValue(
                for: .millimolesPerLiter,
                withRounding: true,
                rule: .down
            )
            let upperBoundString = bothUnitsString(
                mgdlValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdlMax),
                mmolValue: HKQuantity(unit: .millimolesPerLiter, doubleValue: mmolMax)
            )
            return lowHighText(lowerBoundString: LocalizedString("your Glucose Safety Limit", comment: "Lower bound pre-meal information text"),
                               upperBoundString: upperBoundString)
        case .workoutCorrectionRangeOverride:
            let mgdlMin = Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.lowerBound.doubleValue(
                for: .milligramsPerDeciliter,
                withRounding: true,
                rule: .down
            )
            let mmolMin = Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.lowerBound.doubleValue(
                for: .millimolesPerLiter,
                withRounding: true,
                rule: .down
            )
            let lowerBoundString = bothUnitsString(
                mgdlValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdlMin),
                mmolValue: HKQuantity(unit: .millimolesPerLiter, doubleValue: mmolMin)
            )
            let mgdlMax = Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.upperBound.doubleValue(
                for: .milligramsPerDeciliter,
                withRounding: true,
                rule: .down
            )
            let mmolMax = Guardrail.unconstrainedWorkoutCorrectionRange.absoluteBounds.upperBound.doubleValue(
                for: .millimolesPerLiter,
                withRounding: true,
                rule: .down
            )
            let upperBoundString = bothUnitsString(
                mgdlValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdlMax),
                mmolValue: HKQuantity(unit: .millimolesPerLiter, doubleValue: mmolMax)
            )
            return lowHighText(
                lowerBoundString: String(format: LocalizedString("%1$@ or your Glucose Safety Limit, whichever is higher", comment: "Lower bound workout information text format (1: app name)"), lowerBoundString),
                upperBoundString: upperBoundString)
        case .suspendThreshold:
            return lowHighText(for: Guardrail.suspendThreshold)
        case .basalRate, .deliveryLimits, .insulinModel, .carbRatio, .insulinSensitivity, .none:
            fatalError("Unexpected")
        }
    }

    func bothUnitsString(mgdlValue: HKQuantity, mmolValue: HKQuantity) -> String {
        String(format: "%1$@ (%2$@)",
               mgdLFormatter.string(from: mgdlValue)!,
               mmolLFormatter.string(from: mmolValue)!)
    }


    func lowHighText(for guardrail: Guardrail<HKQuantity>) -> String {
        let mgdlValues = guardrail.absoluteBounds.roundedDisplayValues(for: .milligramsPerDeciliter)
        let mmolValues = guardrail.absoluteBounds.roundedDisplayValues(for: .millimolesPerLiter)

        let lowerBoundString = bothUnitsString(
            mgdlValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdlValues.first!),
            mmolValue: HKQuantity(unit: .millimolesPerLiter, doubleValue: mmolValues.first!)
        )

        let upperBoundString = bothUnitsString(
            mgdlValue: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: mgdlValues.last!),
            mmolValue: HKQuantity(unit: .millimolesPerLiter, doubleValue: mmolValues.last!)
        )

        return lowHighText(lowerBoundString: lowerBoundString, upperBoundString: upperBoundString)
    }

    func lowHighText(lowerBoundString: String, upperBoundString: String) -> String {
        return String(format: LocalizedString("It can be set as low as %1$@. It can be set as high as %2$@.",
                                              comment: "Guardrail info text format"), lowerBoundString, upperBoundString)
    }
}
