//
//  ResizeablePicker.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 12/7/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit

struct ResizeablePicker<SelectionValue>: UIViewRepresentable where SelectionValue: CustomStringConvertible & Hashable {
    private let selection: Binding<SelectionValue>
    private var selectedRow: Int = 0
    // TODO: Would be nice if we could just use `ForEach` and Content, but for now, this'll do
    private let data: [SelectionValue]
    private let formatter: (SelectionValue) -> String
    private let colorer: (SelectionValue) -> Color

    public init(selection: Binding<SelectionValue>,
                data: [SelectionValue],
                formatter: @escaping (SelectionValue) -> String = { $0.description },
                colorer: @escaping (SelectionValue) -> Color = { _ in .primary }
    ) {
        self.selection = selection
        self.selectedRow = data.firstIndex(of: selection.wrappedValue) ?? 0
        self.data = data
        self.formatter = formatter
        self.colorer = colorer
    }

    func makeCoordinator() -> ResizeablePicker.Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: UIViewRepresentableContext<ResizeablePicker>) -> UIPickerView {
        let picker = UIPickerViewResizeable(frame: .zero)
        
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIView(_ view: UIPickerView, context: UIViewRepresentableContext<ResizeablePicker>) {
        if view.selectedRow(inComponent: 0) != selectedRow {
            view.selectRow(selectedRow, inComponent: 0, animated: true)
        }
    }

    class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        private var picker: ResizeablePicker

        init(_ pickerView: ResizeablePicker) {
            self.picker = pickerView
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            1
        }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            picker.data.count
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let text = self.picker.formatter(picker.data[row])
            let result = view as? UILabel ?? UILabel()
            result.text = text
            result.font = UIFont.preferredFont(forTextStyle: .title2)
            result.textAlignment = .center
            result.textColor = UIColor(picker.colorer(picker.data[row]))
            result.accessibilityHint = text
            result.lineBreakMode = .byClipping
            result.adjustsFontSizeToFitWidth = true
            return result
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            picker.selectedRow = row
            picker.selection.wrappedValue = picker.data[row]
        }
    }
}

class UIPickerViewResizeable: UIPickerView {
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }
}
