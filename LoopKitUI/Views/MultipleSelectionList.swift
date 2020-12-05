//
//  MultipleSelectionList.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2020-02-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct MultipleSelectionList<Item>: View where Item: Hashable {
    var items: [Item]
    @Binding var selectedItems: Set<Item>
    var itemToDisplayableString: (Item) -> String
    
    public init(items: [Item], selectedItems: Binding<Set<Item>>, itemToDisplayableString: @escaping (Item) -> String) {
        self.items = items
        _selectedItems = selectedItems
        self.itemToDisplayableString = itemToDisplayableString
    }
    
    public var body: some View {
        List(items, id:\.self) { item in
            MultipleSelectionRow<Item>(item: item,
                                       selectedItems: self.$selectedItems,
                                       itemToDisplayableString: self.itemToDisplayableString)
        }
        .insetGroupedListStyle()
    }
}

struct MultipleSelectionRow<Item>: View where Item: Hashable {
    var item: Item
    @Binding var selectedItems: Set<Item>
    var itemToDisplayableString: (Item) -> String
    
    var isSelected: Bool {
        selectedItems.contains(item)
    }
    
    var body: some View {
        HStack {
            Button(action: {
                if self.isSelected {
                    self.selectedItems.remove(self.item)
                } else {
                    self.selectedItems.insert(self.item)
                }
            }) {
                Text(self.itemToDisplayableString(item))
                    .foregroundColor(.primary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
    }
}

struct SelectableList_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        static var fruit = ["Orange", "Apple", "Banana", "Peach", "Grape"]
        @State(initialValue: [fruit[1], fruit[3]]) var selectedFruit: Set<String>
        
        var body: some View {
            MultipleSelectionList<String>(items: SelectableList_Previews.PreviewWrapper.fruit,
                                          selectedItems: $selectedFruit,
                                          itemToDisplayableString: { String(describing:$0) })
        }
    }
}
