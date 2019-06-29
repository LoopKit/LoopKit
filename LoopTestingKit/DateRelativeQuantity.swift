//
//  DateRelativeQuantity.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


protocol DateRelativeQuantity {
    var dateOffset: TimeInterval { get set }
    mutating func shift(by offset: TimeInterval)
}

extension DateRelativeQuantity {
    mutating func shift(by offset: TimeInterval) {
        dateOffset += offset
    }
}
