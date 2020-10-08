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
        try assertCodable(DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 110.3),
                                                             RepeatingScheduleValue(startTime: .hours(5), value: 100.5),
                                                             RepeatingScheduleValue(startTime: .hours(18), value: 120.5)],
                                                timeZone: TimeZone(identifier: "America/New_York")!)!,
                          encodesJSON: """
{
  "unit" : "mg/dL",
  "valueSchedule" : {
    "items" : [
      {
        "startTime" : 0,
        "value" : 110.3
      },
      {
        "startTime" : 18000,
        "value" : 100.5
      },
      {
        "startTime" : 64800,
        "value" : 120.5
      }
    ],
    "referenceTimeInterval" : 0,
    "repeatInterval" : 86400,
    "timeZone" : {
      "identifier" : "America/New_York"
    }
  }
}
"""
        )
    }

    func testCodableDoubleRange() throws {
        try assertCodable(DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.2, maxValue: 111.2)),
                                                             RepeatingScheduleValue(startTime: .hours(6), value: DoubleRange(minValue: 90.5, maxValue: 101.2)),
                                                             RepeatingScheduleValue(startTime: .hours(19), value: DoubleRange(minValue: 110.2, maxValue: 121.2))],
                                                timeZone: TimeZone(identifier: "America/Chicago")!)!,
                          encodesJSON: """
{
  "unit" : "mg/dL",
  "valueSchedule" : {
    "items" : [
      {
        "startTime" : 0,
        "value" : {
          "maxValue" : 111.2,
          "minValue" : 100.2
        }
      },
      {
        "startTime" : 21600,
        "value" : {
          "maxValue" : 101.2,
          "minValue" : 90.5
        }
      },
      {
        "startTime" : 68400,
        "value" : {
          "maxValue" : 121.2,
          "minValue" : 110.2
        }
      }
    ],
    "referenceTimeInterval" : 0,
    "repeatInterval" : 86400,
    "timeZone" : {
      "identifier" : "America/Chicago"
    }
  }
}
"""
        )
    }

    func testCodableInt() throws {
        try assertCodable(DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 112),
                                                             RepeatingScheduleValue(startTime: .hours(7), value: 102),
                                                             RepeatingScheduleValue(startTime: .hours(20), value: 122)],
                                                timeZone: TimeZone(identifier: "America/Los_Angeles")!)!,
                          encodesJSON: """
{
  "unit" : "mg/dL",
  "valueSchedule" : {
    "items" : [
      {
        "startTime" : 0,
        "value" : 112
      },
      {
        "startTime" : 25200,
        "value" : 102
      },
      {
        "startTime" : 72000,
        "value" : 122
      }
    ],
    "referenceTimeInterval" : 0,
    "repeatInterval" : 86400,
    "timeZone" : {
      "identifier" : "America/Los_Angeles"
    }
  }
}
"""
        )
    }

    func assertCodable<T>(_ original: DailyQuantitySchedule<T>, encodesJSON string: String) throws where T: RawRepresentable & Codable & Equatable {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(DailyQuantitySchedule<T>.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()
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
