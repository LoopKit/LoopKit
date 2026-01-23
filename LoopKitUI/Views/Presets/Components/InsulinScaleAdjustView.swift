//
//  InsulinScaleAdjustView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/10/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

// Local replacement for missing InsulinMultiplierImpact type
public struct InsulinMultiplierImpact {
    public let basalRate: LoopQuantity?
    public let carbRatio: LoopQuantity?
    public let isf: LoopQuantity?

    public init(basalRate: LoopQuantity?, carbRatio: LoopQuantity?, isf: LoopQuantity?) {
        self.basalRate = basalRate
        self.carbRatio = carbRatio
        self.isf = isf
    }
}

public struct InsulinScaleAdjustView: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.colorPalette) private var colorPalette

    @State private var presentInfoView: Bool

    @Binding var insulinMultiplier: Double
    let guardrail: Guardrail<LoopQuantity>
    
    let impactForInsulinMultiplier: (Double) -> TherapySettings.InsulinMultiplierImpact

    var insulinPercentage: Double {
        (insulinMultiplier * 100).rounded()
    }
    
    public init(presentInfoView: Bool = false, insulinMultiplier: Binding<Double>, guardrail: Guardrail<LoopQuantity>, impactForInsulinMultiplier: @escaping (Double) -> TherapySettings.InsulinMultiplierImpact) {
        self.presentInfoView = presentInfoView
        self._insulinMultiplier = insulinMultiplier
        self.guardrail = guardrail
        self.impactForInsulinMultiplier = impactForInsulinMultiplier
    }

    public var body: some View {
        // Header Section
        VStack(spacing: 16) {
            HStack {
                Text("Overall Insulin Needs")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.vertical)

                Button(action: {
                    presentInfoView = true;
                }) {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.top, -5)


            Text("Set your overall insulin needs")
                .font(.title2)
                .fontWeight(.bold)

            Text("Use the + and - buttons to set whether you need") +
            Text(" more ").fontWeight(.bold) +
            Text("or") +
            Text(" less ").fontWeight(.bold) +
            Text("insulin than usual.")

            adjustInsulinControls

            Divider()

            settingsImpact

        }
        .multilineTextAlignment(.center)
        .sheet(isPresented: $presentInfoView) {
            InsulinScaleInformationView()
        }
    }

    var valueColor: Color {
        switch Guardrail.presetInsulinNeeds.classification(for: .init(unit: .percent, doubleValue: insulinPercentage)) {
        case .withinRecommendedRange:
            return colorPalette.insulinTintColor
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return colorPalette.guidanceColors.critical
            case .belowWarning, .aboveWarning:
                return colorPalette.guidanceColors.critical
            case .belowRecommended, .aboveRecommended:
                return colorPalette.guidanceColors.warning
            }
        }
    }

    private var adjustInsulinControls: some View {
        HStack(spacing: 24) {
            Button(action: {
                decreaseInsulinMultiplier()
            }) {
                Text(Image(systemName: "minus.circle.fill").symbolRenderingMode(.hierarchical))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(colorPalette.insulinTintColor)
            }
            .buttonStyle(BorderlessButtonStyle())


            Text("\(Int(insulinPercentage))%")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(valueColor)

            Button(action: {
                increaseInsulinMultiplier()
            }) {
                Text(Image(systemName: "plus.circle.fill").symbolRenderingMode(.hierarchical))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(colorPalette.insulinTintColor)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
    
    private func decreaseInsulinMultiplier() {
        if insulinPercentage > guardrail.absoluteBounds.lowerBound.doubleValue(for: .percent) {
            insulinMultiplier = insulinPercentage.snap(direction: .down) / 100
        }
    }
    
    private func increaseInsulinMultiplier() {
        if insulinPercentage < guardrail.absoluteBounds.upperBound.doubleValue(for: .percent) {
            insulinMultiplier = insulinPercentage.snap(direction: .up) / 100
        }
    }

    private var settingsImpact: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings Impact")
                    .font(.headline)

                if insulinPercentage < 100 {
                    Text("This adjustment will make your settings weaker.")
                        .fixedSize(horizontal: false, vertical: true)
                } else if (insulinPercentage > 100) {
                    Text("This adjustment will make your settings stronger.")
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No change to insulin settings.")
                }
            }

            exampleSettings

            // Footer Note
            Text("Note: These example values are based on your current settings. Values may be different when you enable the preset.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .multilineTextAlignment(.leading)
    }

    private var sensitivityUnit: LoopUnit {
        switch displayGlucosePreference.unit {
        case .milligramsPerDeciliter:
            return .milligramsPerDeciliterPerInternationalUnit
        case .millimolesPerLiter:
            return .millimolesPerLiterPerInternationalUnit
        default:
            fatalError()
        }
    }


    private var exampleSettings: some View {
        Group {
            let impact = impactForInsulinMultiplier(insulinMultiplier)
            if let basalRate = impact.basalRate, let carbRatio = impact.carbRatio, let isf = impact.isf {
                HStack(spacing: 0) {
                    SettingAdjustmentPreview(
                        value: basalRate,
                        displayUnit: .internationalUnitsPerHour,
                        name: "Basal Rate",
                        highlighted: insulinPercentage != 100
                    )

                    Spacer()

                    SettingAdjustmentPreview(
                        value: carbRatio,
                        displayUnit: .gramsPerUnit,
                        name: "Carb Ratio",
                        highlighted: insulinPercentage != 100
                    )

                    Spacer()

                    SettingAdjustmentPreview(
                        value: isf,
                        displayUnit: displayGlucosePreference.unit.unitDivided(by: .internationalUnit),
                        name: "ISF",
                        highlighted: insulinPercentage != 100
                    )
                }
            }
        }
    }
}

extension Double {
    enum StepDirection { case up, down }
    
    func snap(step: Double = 5, direction: StepDirection) -> Double {
        let value = self / step
        let tolerance = 1e-9 // Smooths out floating point math quirks
        let isExactMultiple = abs(value.rounded() - value) < tolerance
        
        if isExactMultiple {
            return direction == .up ? self + step : self - step
        } else {
            switch direction {
            case .up:
                return ceil(value) * step
            case .down:
                return floor(value) * step
            }
        }
    }
}
