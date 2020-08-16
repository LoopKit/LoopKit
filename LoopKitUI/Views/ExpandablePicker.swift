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
    @State var pickerIndex: Int = 0
    var onUpdate: (Int) -> Void
    let label: String
    
    let items: [String]
    
    public init (
        with items: [String],
        onUpdate: @escaping (Int) -> Void,
        label: String = ""
    ) {
        self.items = items
        self.onUpdate = onUpdate
        self.label = label
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(label)
                Spacer()
                Text(items[pickerIndex])
                .foregroundColor(.gray)
            }
            .padding(.vertical, 5)
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.pickerShouldExpand.toggle()
            }
            if pickerShouldExpand {
                HStack {
                    Picker(selection: $pickerIndex.onChange(onUpdate), label: Text("")) {
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

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        return Binding(
            get: { self.wrappedValue },
            set: { selection in
                self.wrappedValue = selection
                handler(selection)
        })
    }
}

