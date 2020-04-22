//
//  SettingDescription.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct SettingDescription: View {
    var text: Text

    public init(text: Text) {
        self.text = text
    }

    public var body: some View {
        HStack(spacing: 16) {
            text
                .font(.callout)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)

            Button(
                action: {
                    // TODO: Open a link to a support article
                },
                label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 25))
                        .foregroundColor(.accentColor)
                }
            )
        }
    }
}

struct SettingDescription_Previews: PreviewProvider {
    static var previews: some View {
        SettingDescription(text: Text(verbatim: "When your glucose is predicted to go below this value, the app will recommend a basal rate of 0 U and will not recommend a bolus."))
            .padding(.horizontal)
    }
}
