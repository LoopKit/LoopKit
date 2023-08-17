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

public struct CarbQuantityRow: View {
    @Binding private var quantity: Double?
    @Binding private var isFocused: Bool
    
    private let title: String
    private let preferredCarbUnit: HKUnit
    
    @State private var carbInput: String = ""
    
    private let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    public init(quantity: Binding<Double?>, isFocused: Binding<Bool>, title: String, preferredCarbUnit: HKUnit = .gram()) {
        self._quantity = quantity
        self._isFocused = isFocused
        self.title = title
        self.preferredCarbUnit = preferredCarbUnit
    }

    public var body: some View {
        HStack(spacing: 2) {
            Text(title)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            RowTextField(text: $carbInput, isFocused: $isFocused, maxLength: 5) {
                $0.textAlignment = .right
                $0.keyboardType = .decimalPad
                $0.placeholder = "0"
            }
            .onTapGesture {
                // so that row does not lose focus on cursor move
                if !isFocused {
                    rowTapped()
                }
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
            isFocused.toggle()
        }
    }
}
