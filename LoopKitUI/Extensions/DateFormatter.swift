//
//  DateFormatter.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

extension DateFormatter {
    convenience init(dateStyle: Style = .none, timeStyle: Style = .none) {
        self.init()
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
    }
}
