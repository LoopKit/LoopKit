//
//  ExpandablePicker.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public protocol Labeled {
    var label: String { get }
}

public struct ExpandablePicker<SelectionType: Hashable & Labeled>: View {
    @State var pickerShouldExpand = false
    var selectedValue: Binding<SelectionType>
    let label: String
    let items: [SelectionType]
    
    
    public init (
        with items: [SelectionType],
        selectedValue: Binding<SelectionType>,
        label: String = ""
    ) {
        self.items = items
        self.selectedValue = selectedValue
        self.label = label
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(label)
                Spacer()
                Text(selectedValue.wrappedValue.label)
                .foregroundColor(.gray)
            }
            .padding(.vertical, 5)
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.pickerShouldExpand.toggle()
            }
            if pickerShouldExpand {
                HStack(alignment: .center) {
                    Picker(selection: selectedValue, label: Text("")) {
                        ForEach(items, id: \.self) { item in
                            Text(item.label)
                       }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
            }
        }
    }
}
