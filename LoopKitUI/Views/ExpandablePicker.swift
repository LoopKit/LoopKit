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
    @Binding var selectedIndex: Int
    let items: [String]
    
    public init (
        with items: [String],
        pickerIndex: Binding<Int>
    ) {
        self.items = items
        _selectedIndex = pickerIndex
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Insulin Model")
                Spacer()
                Text(items[selectedIndex])
            }
            .padding(.vertical, 5)
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.pickerShouldExpand.toggle()
            }
            if pickerShouldExpand {
                HStack {
                    Picker(selection: $selectedIndex, label: Text("")) {
                        ForEach(0 ..< items.count) {
                            Text(self.items[$0])
                       }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(maxWidth: 300, alignment: .center)
                }
            }
        }
    }
}

