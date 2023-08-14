//
//  DatePickerRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/19/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct DatePickerRow: View {
    @Binding var date: Date
    private var datePickerDate: Binding<Date> {
        Binding<Date>(
            get: { self.date },
            set: { validateDate($0) }
        )
    }
    
    @Binding var isFocused: Bool
    
    private let maximumDate: Date
    private let minimumDate: Date
    
    @State var incrementButtonEnabled = true
    @State var decrementButtonEnabled = true
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    private let relativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter
    }()
    
    private let timeStepSize: TimeInterval = .minutes(15)
    
    public init(date: Binding<Date>, isFocused: Binding<Bool>, minimumDate: Date, maximumDate: Date) {
        self._date = date
        self._isFocused = isFocused
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Time")
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: decrementTime) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 24))
                        .opacity(decrementButtonEnabled ? 1 : 0.7)
                }
                .disabled(!decrementButtonEnabled)
                
                let dateTextColor: Color = isFocused ? .accentColor : Color(UIColor.secondaryLabel)
                Text(dateString())
                    .foregroundColor(dateTextColor)
                
                Button(action: incrementTime) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 24))
                        .opacity(incrementButtonEnabled ? 1 : 0.7)
                }
                .disabled(!incrementButtonEnabled)
            }
            
            if isFocused {
                DatePicker(selection: datePickerDate, in: minimumDate...maximumDate, label: { EmptyView() })
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .opacity(isFocused ? 1 : 0)
            }
        }
        .onAppear {
            checkButtonsEnabled()
        }
        .onTapGesture {
            rowTapped()
        }
    }
    
    private func checkButtonsEnabled() {
        let maxOrder = Calendar.current.compare(date, to: maximumDate, toGranularity: .minute)
        incrementButtonEnabled = maxOrder == .orderedAscending
        
        let minOrder = Calendar.current.compare(date, to: minimumDate, toGranularity: .minute)
        decrementButtonEnabled = minOrder == .orderedDescending
    }
    
    private func decrementTime() {
        let potentialDate = date.addingTimeInterval(-timeStepSize)
        if Calendar.current.compare(potentialDate, to: minimumDate, toGranularity: .minute) != .orderedAscending {
            date = potentialDate
        } else {
            date = minimumDate
        }
        checkButtonsEnabled()
    }
    
    private func incrementTime() {
        let potentialDate = date.addingTimeInterval(timeStepSize)
        if Calendar.current.compare(potentialDate, to: maximumDate, toGranularity: .minute) != .orderedDescending {
            date = potentialDate
        } else {
            date = maximumDate
        }
        checkButtonsEnabled()
    }
    
    private func validateDate(_ date: Date) {
        if date >= maximumDate {
            self.date = maximumDate
        }
        else if date <= minimumDate {
            self.date = minimumDate
        }
        else {
            self.date = date
        }
        checkButtonsEnabled()
    }
    
    private func dateString() -> String {
        if Calendar.current.isDateInToday(date) {
            return dateFormatter.string(from: date)
        } else {
            return relativeDateFormatter.string(from: date)
        }
    }
    
    private func rowTapped() {
        withAnimation {
            isFocused.toggle()
        }
    }
}
