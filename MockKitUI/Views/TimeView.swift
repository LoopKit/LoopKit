//
//  TimeView.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2023-06-01.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKitUI

struct TimeView: View {

    @State private var currentDate = Date()

    let timeOffset: TimeInterval

    let timeZone: TimeZone
    
    let label: String

    private let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private var timeToDisplay: Date {
        currentDate.addingTimeInterval(timeOffset)
    }

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeZoneString: String {
        shortTimeFormatter.timeZone = timeZone
        return shortTimeFormatter.string(from: timeToDisplay)
    }
    
    init(timeOffset: TimeInterval = 0, timeZone: TimeZone = .current, label: String = "") {
        self.timeOffset = timeOffset
        self.timeZone = timeZone
        self.label = label
    }

    var body: some View {
        LabeledValueView(label: label, value: timeZoneString).onReceive(timer) { input in
            currentDate = input
        }
    }
}

struct TimeView_Previews: PreviewProvider {
    static var previews: some View {
        TimeView(timeOffset: 0, timeZone: .current, label: "Current Time")
    }
}
