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
    let pickerRange: ClosedRange<Date>
    
    public init (with date: Binding<Date>, pickerRange: ClosedRange<Date>? = nil) {
        _date = date
        
        let today = Date()
        self.pickerRange = pickerRange ?? today.addingTimeInterval(-.hours(12))...today.addingTimeInterval(.hours(12))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedString("Date", comment: "Date of logged dose"))
                .bold()
                Spacer()
                Text(dateFormatter.string(from: date))
                .foregroundColor(.gray)
                
            }
            .padding()
            .frame(minWidth: 0, maxWidth: .infinity).onTapGesture {
                self.dateShouldExpand.toggle()
            }
            
            if dateShouldExpand {
                DatePicker("", selection: $date, in: pickerRange, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd, H:mm"
        formatter.timeZone = TimeZone.current
        return formatter
    }
}
