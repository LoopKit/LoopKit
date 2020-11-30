//
//  LabeledNumberInput.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct LabeledNumberInput: View {
    @Binding var value: Double?
    var label: String
    var placeholder: String
    var allowFractions: Bool
    
    private var numberFormatter: NumberFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = allowFractions ? .decimal : .none
        return numberFormatter
    }
    
    // seems like the TextField doesn't update the formatted binding until return to tapped. This is the workaround.
    private var valueString: Binding<String> {
        Binding<String>(
            get: { () -> String in
                guard let value = self.value else {
                    return ""
                }
                return self.numberFormatter.string(from: NSNumber(value: value.rawValue)) ?? ""
            },
            set: {
                if let value = self.numberFormatter.number(from: $0) {
                    self.value = value.doubleValue
                }
            }
        )
    }
    
    public init(value: Binding<Double?>, label: String, placeholder: String? = nil, allowFractions: Bool = false) {
        _value = value
        self.label = label
        self.placeholder = placeholder ?? LocalizedString("Value", comment: "Placeholder text until value is entered")
        self.allowFractions = allowFractions
    }
        
    public var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 5) {
                TextField(self.placeholder, text: self.valueString)
                    .font(.largeTitle)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(self.allowFractions ? .decimalPad : .numberPad)
                    .frame(width: geometry.size.width/2, alignment: .trailing)
                    .accessibility(label: Text(String(format: LocalizedString("Enter %1$@ value", comment: "Format string for accessibility label for value entry. (1: value label)"), label)))
                Text(self.label)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 7)
                    .frame(width: geometry.size.width/2, alignment: .leading)
            }
        }
    }
}

struct LabeledNumberInput_Previews: PreviewProvider {
    static var previews: some View {
        LabeledNumberInput(
            value: .constant(nil),
            label: "mg/dL",
            allowFractions: true)
    }
}
