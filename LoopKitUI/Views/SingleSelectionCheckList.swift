//
//  SingleSelectionCheckList.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2022-09-09.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct SingleSelectionCheckList<Item: Hashable>: View {
    let header: String?
    let footer: String?
    let items: [Item]
    @Binding var selectedItem: Item

    public init(header: String? = nil,
                footer: String? = nil,
                items: [Item],
                selectedItem: Binding<Item>,
                formatter: ((Item) -> Item)? = nil) {
        self.header = header
        self.footer = footer
        self.items = items
        _selectedItem = selectedItem
    }

    public var body: some View {
        Section(header: header.map { Text($0) }, footer: footer.map { Text($0) }) {
            ForEach(items, id:\.self) { item in
                CheckSelectionRow<Item>(item: item,
                                        selectedItem: self.$selectedItem)
            }
        }
    }
}

struct CheckSelectionRow<Item>: View where Item: Hashable {
    var item: Item
    @Binding var selectedItem: Item

    var isSelected: Bool {
        selectedItem == item
    }

    var body: some View {
        HStack {
            Button(action: { selectedItem = item } ) {
                Text(String(describing: item))
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

struct SingleSelectionCheckList_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }

    struct PreviewWrapper: View {
        enum Shape: String, CaseIterable {
            case square = "Square"
            case circle = "Circle"
            case triangle = "Triangle"
            case rectangle = "Rectangle"
        }
        @State var selectedFruit: Shape = .square

        var body: some View {
            SingleSelectionCheckList<Shape>(items: Shape.allCases,
                                            selectedItem: $selectedFruit)
        }
    }
}
