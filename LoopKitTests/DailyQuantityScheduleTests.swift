//
//  DailyQuantityScheduleTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 5/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit

class DailyQuantityScheduleCodableTests: XCTestCase {
    func testCodableDouble() throws {
        try assertDailyQuantityScheduleCodable { Double.random(in: Double(Int.min)...Double(Int.max)) }
    }

    func testCodableInt() throws {
        try assertDailyQuantityScheduleCodable { Int.random(in: Int.min...Int.max) }
    }

    private func assertDailyQuantityScheduleCodable<T>(factory: () -> T) throws where T: RawRepresentable & Codable & Equatable {
        let original = dailyQuantitySchedule(factory: factory)
        let data = try PropertyListEncoder().encode(original)
        let decoded = try PropertyListDecoder().decode(DailyQuantitySchedule<T>.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    private func dailyQuantitySchedule<T>(factory: () -> T) -> DailyQuantitySchedule<T> {
        return DailyQuantitySchedule<T>(unit: .internationalUnitsPerHour, dailyItems: dailyItems(factory), timeZone: TimeZone.current)!
    }

    private func dailyItems<T>(_ factory: () -> T) -> [RepeatingScheduleValue<T>] {
        return Array(0..<24).map { RepeatingScheduleValue<T>(startTime: .hours(Double($0)), value: factory()) }
    }
}

extension Int: RawRepresentable {
    public typealias RawValue = Int

    public init?(rawValue: RawValue) {
        self = rawValue
    }

    public var rawValue: RawValue {
        return self
    }
}
