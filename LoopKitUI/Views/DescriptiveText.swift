//
//  DescriptiveText.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct DescriptiveText: View {
    var label: String
    let color: Color
    
    public init(label: String, color: Color = .secondary) {
        self.label = label
        self.color = color
    }
    
    public var body: some View {
        Text(label)
            .font(.footnote)
            .foregroundColor(color)
    }
}

struct DescriptiveText_Previews: PreviewProvider {
    static var previews: some View {
        DescriptiveText(label: "Descriptive text is typically lengthly and provides additional details to potentially terse labeled values.")
    }
}
