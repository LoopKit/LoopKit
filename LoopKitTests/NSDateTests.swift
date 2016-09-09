//
//  NSDateTests.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
@testable import LoopKit

class NSDateTests: XCTestCase {

    func testDateCeiledToInterval() {
        let calendar = Calendar.current

        let five01 = calendar.nextDate(after: Date(), matching: DateComponents(hour: 5, minute: 0, second: 1), matchingPolicy: .nextTime)!

        let five05 = calendar.nextDate(after: five01, matching: DateComponents(hour: 5, minute: 5, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(five05, five01.dateCeiledToTimeInterval(TimeInterval(minutes: 5)))

        let six = calendar.nextDate(after: five01, matching: DateComponents(hour: 6, minute: 0, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(six, five01.dateCeiledToTimeInterval(TimeInterval(minutes: 60)))

        XCTAssertEqual(five05, five05.dateCeiledToTimeInterval(TimeInterval(minutes: 5)))

        let five47 = calendar.nextDate(after: five01, matching: DateComponents(hour: 5, minute: 47, second: 58), matchingPolicy: .nextTime)!

        let five50 = calendar.nextDate(after: five01, matching: DateComponents(hour: 5, minute: 50, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(five50, five47.dateCeiledToTimeInterval(TimeInterval(minutes: 5)))

        let twentyThree59 = calendar.nextDate(after: five01, matching: DateComponents(hour: 23, minute: 59, second: 0), matchingPolicy: .nextTime)!

        let tomorrowMidnight = calendar.nextDate(after: five01, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(tomorrowMidnight, twentyThree59.dateCeiledToTimeInterval(TimeInterval(minutes: 5)))

        XCTAssertEqual(five01, five01.dateCeiledToTimeInterval(TimeInterval(0)))
    }

    func testDateFlooredToInterval() {
        let calendar = Calendar.current

        let five01 = calendar.nextDate(after: Date(), matching: DateComponents(hour: 5, minute: 0, second: 1), matchingPolicy: .nextTime)!

        let five = calendar.nextDate(after: five01, matching: DateComponents(hour: 5, minute: 0, second: 0), matchingPolicy: .nextTime, direction: .backward)!

        XCTAssertEqual(five, five01.dateFlooredToTimeInterval(TimeInterval(minutes: 5)))

        let five59 = calendar.nextDate(after: five01, matching: DateComponents(hour: 5, minute: 59, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(five, five59.dateFlooredToTimeInterval(TimeInterval(minutes: 60)))

        let five55 = calendar.nextDate(after: five01, matching: DateComponents(hour: 5, minute: 55, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(five55, five59.dateFlooredToTimeInterval(TimeInterval(minutes: 5)))


        XCTAssertEqual(five, five.dateFlooredToTimeInterval(TimeInterval(minutes: 5)))
        
        XCTAssertEqual(five01, five01.dateFlooredToTimeInterval(TimeInterval(0)))
    }
}
