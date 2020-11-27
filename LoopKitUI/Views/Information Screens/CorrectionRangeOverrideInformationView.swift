//
//  CorrectionRangeOverrideInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

public struct CorrectionRangeOverrideInformationView: View {
    let preset: CorrectionRangeOverrides.Preset
    var onExit: (() -> Void)?
    let mode: SettingsPresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.carbTintColor) var carbTintColor
    @Environment(\.glucoseTintColor) var glucoseTintColor
    
    public init(
        preset: CorrectionRangeOverrides.Preset,
        onExit: (() -> Void)? = nil,
        mode: SettingsPresentationMode = .acceptanceFlow
    ) {
        self.preset = preset
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        GlucoseTherapySettingInformationView(
            therapySetting: preset.therapySetting,
            onExit: onExit,
            mode: mode,
            text: AnyView(section(for: preset))
        )
    }
    
    private func section(for preset: CorrectionRangeOverrides.Preset) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            header(for: preset)
            description(for: preset)
            .foregroundColor(.secondary)
        }
    }
    
    private func header(for preset: CorrectionRangeOverrides.Preset)  -> some View {
           HStack {
               icon(for: preset)
               titleText(for: preset)
               .bold()
               .font(.headline)
           }
    }
    
    private func titleText(for preset: CorrectionRangeOverrides.Preset) -> Text {
        switch preset {
        case .preMeal:
            return Text(LocalizedString("Pre-meal temp adjust range", comment: "Title for pre-meal range information section"))
        case .workout:
            return Text(LocalizedString("Workout temp adjust range", comment: "Title for workout range information section"))
        }
    }
    
    private func description(for preset: CorrectionRangeOverrides.Preset) -> some View {
        switch preset {
        case .preMeal:
            return VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedString("Your pre-meal temp adjust range should be the glucose value (or range of values) you want Loop to target by the time you take your first bite of your meal.", comment: "Information about pre-meal range"))
                Text(LocalizedString("This will typically be", comment: "Information about pre-meal range relative to correction range")) + Text(LocalizedString(" lower ", comment: "Information about pre-meal range relative to correction range")).bold().italic() + Text(LocalizedString("than your correction range", comment: "Information about pre-meal range relative to correction range"))
            }
            .fixedSize(horizontal: false, vertical: true) // prevent text from being cut off
        case .workout:
            return VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedString("Workout temp adjust is the glucose value or range of values you want Loop to target during activity.", comment: "Information about workout range"))
                Text(LocalizedString("This will typically be", comment: "Information about workout range relative to correction range")) + Text(LocalizedString(" higher ", comment: "Information about workout range relative to correction range")).bold().italic() + Text(LocalizedString("than your correction range", comment: "Information about workout range relative to correction range"))
            }
            .fixedSize(horizontal: false, vertical: true) // prevent text from being cut off
        }
    }
    
    private func icon(for preset: CorrectionRangeOverrides.Preset) -> some View {
        return preset.icon(usingCarbTintColor: carbTintColor, orGlucoseTintColor: glucoseTintColor)
    }
}

struct CorrectionRangeOverrideInformationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CorrectionRangeOverrideInformationView(preset: .preMeal)
        }
        .colorScheme(.light)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
        .previewDisplayName("Pre-Meal SE light")
        NavigationView {
            CorrectionRangeOverrideInformationView(preset: .workout)
        }
        .colorScheme(.light)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
        .previewDisplayName("Workout SE light")
        NavigationView {
            CorrectionRangeOverrideInformationView(preset: .preMeal)
        }
        .preferredColorScheme(.dark)
        .colorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
        .previewDisplayName("Pre-Meal 11 Pro dark")
        NavigationView {
            CorrectionRangeOverrideInformationView(preset: .workout)
        }
        .preferredColorScheme(.dark)
        .colorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
        .previewDisplayName("Workout 11 Pro dark")
    }
}
