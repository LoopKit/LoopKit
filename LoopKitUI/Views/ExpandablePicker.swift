//
//  ExpandablePicker.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ExpandablePicker: View {
    @State var pickerShouldExpand = false
    var pickerIndex: Binding<Int>
    let label: String
    let items: [String]
    
    
    public init (
        with items: [String],
        pickerIndex: Binding<Int>,
        label: String = ""
    ) {
        self.items = items
        self.pickerIndex = pickerIndex
        self.label = label
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(label)
                Spacer()
                Text(items[pickerIndex.wrappedValue])
                .foregroundColor(.gray)
            }
            .padding(.vertical, 5)
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.pickerShouldExpand.toggle()
            }
            if pickerShouldExpand {
                HStack(alignment: .center) {
                    Picker(selection: self.pickerIndex, label: Text("")) {
                        ForEach(0 ..< self.items.count) {
                            Text(self.items[$0])
                       }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .labelsHidden()
                }
            }
        }
    }
}
