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
    
    public init(label: String) {
        self.label = label
    }
    
    public var body: some View {
        Text(label)
            .font(.footnote)
            .foregroundColor(.secondary)
    }
}

struct DescriptiveText_Previews: PreviewProvider {
    static var previews: some View {
        DescriptiveText(label: "Descriptive text is typically lengthly and provides additional details to potentially terse labeled values.")
    }
}
