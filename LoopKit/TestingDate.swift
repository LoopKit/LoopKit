//
//  TestingDate.swift
//  LoopKit
//
//  Created by Pete Schwamb on 11/1/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


public enum TestingDate {

    private static var testingDate: TestingDate? = nil

    case fixed(Date)
    case relative(TimeInterval)

    public static func setFixedTestingDate(_ date: Date) {
        self.testingDate = .fixed(date)
    }

    public static func setRelativeTestingDate(_ date: Date) {
        self.testingDate = .relative(date.timeIntervalSinceNow)
    }

    public static func currentTestingDate() -> Date {
        guard let testingDate else {
            return Date()
        }

        switch testingDate {
        case .fixed(let date):
            return date
        case .relative(let timeInterval):
            return Date().addingTimeInterval(timeInterval)
        }
    }
}


