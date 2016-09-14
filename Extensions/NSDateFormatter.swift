//
//  NSDateFormatter.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 11/25/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension DateFormatter {
    static func ISO8601Strict() -> Self {
        let dateFormatter = self.init()

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        return dateFormatter
    }

    static func ISO8601LocalTime() -> Self {
        let dateFormatter = self.init()

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        return dateFormatter
    }

    static func localTime() -> Self {
        let timeFormatter = self.init()

        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        return timeFormatter
    }
}
