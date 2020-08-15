//
//  ExpandableDatePicker.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 8/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct ExpandableDatePicker: View {
    @State var date: Date = Date()
    let pickerRange: ClosedRange<Date>
    let text: String
    var onUpdate: (Date) -> Void
    
    public init (
        with date: Date,
        pickerRange: ClosedRange<Date>? = nil,
        text: String = "",
        onUpdate: @escaping (Date) -> Void
    ) {
        let today = Date()
        self.pickerRange = pickerRange ?? today.addingTimeInterval(-.hours(6))...today.addingTimeInterval(.hours(6))
        self.text = text
        self.onUpdate = onUpdate
        self.date = date
    }
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // ANNA TOOD: fix buggy animations
            DatePicker(
                "",
                selection: $date,
                in: Date().addingTimeInterval(-.hours(6))...Date().addingTimeInterval(.hours(6)),
                displayedComponents: [.date, .hourAndMinute]
            )
            .pickerStyle(WheelPickerStyle())
            Text("Date")
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd, H:mm"
        formatter.timeZone = TimeZone.current
        return formatter
    }
}
