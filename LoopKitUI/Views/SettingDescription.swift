//
//  SettingDescription.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public enum TherapySetting: Int {
    case glucoseTargetRange
    case correctionRangeOverrides
    case suspendThreshold
    case basalRate
    case deliveryLimits
    case insulinModel
    case carbRatio
    case insulinSensitivity
    case none
    
    public func helpScreen() -> some View {
        switch self {
        case .glucoseTargetRange:
            return AnyView(CorrectionRangeInformationView(onExit: nil, mode: .modal))
        case .correctionRangeOverrides:
            return AnyView(CorrectionRangeOverrideInformationView(onExit: nil, mode: .modal))
        case .suspendThreshold:
            return AnyView(SuspendThresholdInformationView(onExit: nil, mode: .modal))
        // ANNA TODO: add more once other instructional screens are created
        default:
            return AnyView(Text("To be implemented"))
        }
    }
}

public struct SettingDescription<InformationalContent: View>: View {
    var text: Text
    var informationalContent: InformationalContent
    @State var displayHelpPage: Bool = false

    public init(
        text: Text,
        @ViewBuilder informationalContent: @escaping () -> InformationalContent
    ) {
        self.text = text
        self.informationalContent = informationalContent()
    }

    public var body: some View {
        HStack(spacing: 8) {
            text
                .font(.callout)
                .foregroundColor(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            
            infoButton
            .sheet(isPresented: $displayHelpPage) {
                NavigationView {
                    self.informationalContent
                }
            }
        }
    }
    
    private var infoButton: some View {
        Button(
            action: {
                self.displayHelpPage = true
            },
            label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 25))
                    .foregroundColor(.accentColor)
            }
        )
        .padding(.trailing, 4)
    }
}
