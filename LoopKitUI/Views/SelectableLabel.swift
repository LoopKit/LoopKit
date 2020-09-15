//
//  SelectableLabel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct SelectableLabel: View {
    var label: String
    @Binding var selectedLabel: String?
    
    public init(label: String, selectedLabel: Binding<String?>) {
        self.label = label
        _selectedLabel = selectedLabel
    }
    
    public var body: some View {
        Button(action: { self.selectedLabel = self.label }) {
            HStack {
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
                if selectedLabel == label {
                    Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

struct SelectableLabel_Previews: PreviewProvider {
    static var previews: some View {
        return SelectableLabel(label: "Test", selectedLabel: .constant("Test"))
    }
}
