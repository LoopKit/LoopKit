//
//  LabeledValueView.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct LabeledValueView: View {
    public static let NoValueString: String = "–"
    var label: String
    var value: String?
    var highlightValue: Bool
    
    public init(label: String, value: String?, highlightValue: Bool = false) {
        self.label = label
        self.value = value
        self.highlightValue = highlightValue
    }
    
    public var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Text(value ?? LabeledValueView.NoValueString)
                .foregroundColor(highlightValue ? .accentColor : .secondary)
        }
    }
}

struct LabeledValueView_Previews: PreviewProvider {
    static var previews: some View {
        LabeledValueView(label: "Glucose", value: "80 mg/dL", highlightValue: true)
    }
}

