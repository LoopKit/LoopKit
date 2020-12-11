//
//  ExpandableDatePicker.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ExpandableDatePicker: View {
    @State var dateShouldExpand = false
    @Binding var date: Date
    let placeholderText: String
    let pickerRange: ClosedRange<Date>
    @State var userDidTap: Bool = false
    
    public init (
        with date: Binding<Date>,
        pickerRange: ClosedRange<Date>? = nil,
        placeholderText: String = ""
    ) {
        _date = date
        self.placeholderText = placeholderText
        
        let today = Date()
        self.pickerRange = pickerRange ?? today.addingTimeInterval(-.hours(24))...today
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                dateFieldText
                Spacer()
            }
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.userDidTap = true
                // Hack to refresh binding
                self.date = Date(timeInterval: 0, since: self.date)
                self.dateShouldExpand.toggle()
            }
            if dateShouldExpand {
                DatePicker("", selection: $date, in: pickerRange, displayedComponents: .date)
                .labelsHidden()
            }
        }
    }
    
    private var dateFieldText: some View {
        if userDidTap {
            return Text(dateFormatter.string(from: date))
            // Show the placeholder text if user hasn't interacted with picker
        } else {
            return Text(placeholderText).foregroundColor(Color(UIColor.lightGray))
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter
    }
}
