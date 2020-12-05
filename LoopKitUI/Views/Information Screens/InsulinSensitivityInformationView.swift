//
//  InsulinSensitivityInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct InsulinSensitivityInformationView: View {
    var onExit: (() -> Void)?
    var mode: SettingsPresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(
        onExit: (() -> Void)?,
        mode: SettingsPresentationMode = .acceptanceFlow
    ){
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.insulinSensitivity.title),
            informationalContent: {text},
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(LocalizedString("Your Insulin Sensitivity Factor (ISF) is the drop in glucose expected from one unit of insulin.", comment: "Description of insulin sensitivity factor"))
            Text(LocalizedString("You can add different insulin sensitivities for different times of day by using the ➕.", comment: "Description of how to add a ratio"))
        }
        .accentColor(.secondary)
        .foregroundColor(.accentColor)
    }
}

