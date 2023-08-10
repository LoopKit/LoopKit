//
//  CarbQuantityRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

public struct CarbQuantityRow<Row: Equatable>: View {
    @Binding private var quantity: Double?
    
    private let title: String
    private let preferredCarbUnit: HKUnit
    
    @State private var carbInput: String = ""
    
    @Binding var expandedRow: Row?
    private let row: Row
    
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    public init(quantity: Binding<Double?>, title: String, preferredCarbUnit: HKUnit = .gram(), expandedRow: Binding<Row?>, row: Row) {
        self._quantity = quantity
        self.title = title
        self.preferredCarbUnit = preferredCarbUnit
        self._expandedRow = expandedRow
        self.row = row
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            RowTextField(text: $carbInput, expandedRow: $expandedRow, thisRow: row, maxLength: 5) {
                $0.textAlignment = .right
                $0.keyboardType = .decimalPad
                $0.placeholder = "0"
            }
            
            carbUnitsLabel
        }
        .accessibilityElement(children: .combine)
        .onChange(of: carbInput) { newValue in
            updateQuantity(with: newValue)
        }
        .onChange(of: quantity) { newQuantity in
            updateCarbInput(with: newQuantity)
        }
        .onAppear {
            updateCarbInput(with: quantity)
        }
        .onTapGesture {
            rowTapped()
        }
    }
    
    private var carbUnitsLabel: some View {
        Text(QuantityFormatter(for: preferredCarbUnit).localizedUnitStringWithPlurality())
            .foregroundColor(Color(.secondaryLabel))
    }
    
    // Update quantity based on text field input
    private func updateQuantity(with input: String) {
        let filtered = input.filter { "0123456789.".contains($0) }
        if filtered != input {
            self.carbInput = filtered
        }
        
        if let doubleValue = Double(filtered) {
            quantity = doubleValue
        } else {
            quantity = nil
        }
    }
    
    // Update text field input based on quantity
    private func updateCarbInput(with newQuantity: Double?) {
        if let value = newQuantity {
            carbInput = formatter.string(from: NSNumber(value: value)) ?? ""
        } else {
            carbInput = ""
        }
    }
    
    private func rowTapped() {
        withAnimation {
            expandedRow = nil
        }
    }
}
