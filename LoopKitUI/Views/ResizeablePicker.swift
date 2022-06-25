//
//  ResizeablePicker.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 12/7/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit

public struct ResizeablePicker<SelectionValue>: UIViewRepresentable where SelectionValue: CustomStringConvertible & Hashable {
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

    public func makeCoordinator() -> ResizeablePicker.Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: UIViewRepresentableContext<ResizeablePicker>) -> UIPickerView {
        let picker = UIPickerViewResizeable(frame: .zero)
        
        picker.dataSource = context.coordinator
        picker.delegate = context.coordinator

        return picker
    }

    public func updateUIView(_ view: UIPickerView, context: UIViewRepresentableContext<ResizeablePicker>) {
        context.coordinator.updateData(newData: data)
        view.reloadAllComponents()
        if view.selectedRow(inComponent: 0) != selectedRow {
            view.selectRow(selectedRow, inComponent: 0, animated: false)
        }
    }

    public class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        private var picker: ResizeablePicker
        private var data: [SelectionValue]

        init(_ pickerView: ResizeablePicker) {
            self.picker = pickerView
            self.data = pickerView.data
        }

        func updateData(newData: [SelectionValue]) {
            self.data = newData
        }

        public func numberOfComponents(in pickerView: UIPickerView) -> Int {
            1
        }

        public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            data.count
        }

        public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let text = self.picker.formatter(data[row])
            let result = view as? UILabel ?? UILabel()
            result.text = text
            result.font = UIFont.preferredFont(forTextStyle: .title2)
            result.textAlignment = .center
            result.textColor = UIColor(picker.colorer(data[row]))
            result.accessibilityHint = text
            result.lineBreakMode = .byClipping
            result.adjustsFontSizeToFitWidth = true
            return result
        }
        
        public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            picker.selectedRow = row
            picker.selection.wrappedValue = data[row]
        }
    }
}

class UIPickerViewResizeable: UIPickerView {
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }
}
