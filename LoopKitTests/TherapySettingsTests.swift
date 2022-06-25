//
//  TherapySettingsTests.swift
//  LoopKitTests
//
//  Created by Anna Quinlan on 7/27/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit

class TherapySettingsCodableTests: XCTestCase {
    private let dateFormatter = ISO8601DateFormatter()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    let encodedString = """
    {
      "basalRateSchedule" : {
        "items" : [
          {
            "startTime" : 0,
            "value" : 1
          },
          {
            "startTime" : 28800,
            "value" : 1.125
          },
          {
            "startTime" : 36000,
            "value" : 1.25
          },
          {
            "startTime" : 43200,
            "value" : 1.5
          },
          {
            "startTime" : 50400,
            "value" : 1.25
          },
          {
            "startTime" : 57600,
            "value" : 1.5
          },
          {
            "startTime" : 64800,
            "value" : 1.25
          },
          {
            "startTime" : 75600,
            "value" : 1
          }
        ],
        "referenceTimeInterval" : 0,
        "repeatInterval" : 86400,
        "timeZone" : {
          "identifier" : "GMT-0700"
        }
      },
      "carbRatioSchedule" : {
        "unit" : "g",
        "valueSchedule" : {
          "items" : [
            {
              "startTime" : 0,
              "value" : 10
            },
            {
              "startTime" : 28800,
              "value" : 12
            },
            {
              "startTime" : 36000,
              "value" : 9
            },
            {
              "startTime" : 43200,
              "value" : 10
            },
            {
              "startTime" : 50400,
              "value" : 11
            },
            {
              "startTime" : 57600,
              "value" : 12
            },
            {
              "startTime" : 64800,
              "value" : 8
            },
            {
              "startTime" : 75600,
              "value" : 10
            }
          ],
          "referenceTimeInterval" : 0,
          "repeatInterval" : 86400,
          "timeZone" : {
            "identifier" : "GMT-0700"
          }
        }
      },
      "correctionRangeOverrides" : {
        "preMealRange" : {
          "bloodGlucoseUnit" : "mg/dL",
          "range" : {
            "maxValue" : 90,
            "minValue" : 80
          }
        },
        "workoutRange" : {
          "bloodGlucoseUnit" : "mg/dL",
          "range" : {
            "maxValue" : 140,
            "minValue" : 130
          }
        }
      },
      "defaultRapidActingModel" : "rapidActingAdult",
      "glucoseTargetRangeSchedule" : {
        "rangeSchedule" : {
          "unit" : "mg/dL",
          "valueSchedule" : {
            "items" : [
              {
                "startTime" : 0,
                "value" : {
                  "maxValue" : 110,
                  "minValue" : 100
                }
              },
              {
                "startTime" : 28800,
                "value" : {
                  "maxValue" : 105,
                  "minValue" : 95
                }
              },
              {
                "startTime" : 50400,
                "value" : {
                  "maxValue" : 105,
                  "minValue" : 95
                }
              },
              {
                "startTime" : 57600,
                "value" : {
                  "maxValue" : 110,
                  "minValue" : 100
                }
              },
              {
                "startTime" : 64800,
                "value" : {
                  "maxValue" : 100,
                  "minValue" : 90
                }
              },
              {
                "startTime" : 75600,
                "value" : {
                  "maxValue" : 120,
                  "minValue" : 110
                }
              }
            ],
            "referenceTimeInterval" : 0,
            "repeatInterval" : 86400,
            "timeZone" : {
              "identifier" : "GMT-0700"
            }
          }
        }
      },
      "insulinSensitivitySchedule" : {
        "unit" : "mg/dL",
        "valueSchedule" : {
          "items" : [
            {
              "startTime" : 0,
              "value" : 45
            },
            {
              "startTime" : 28800,
              "value" : 40
            },
            {
              "startTime" : 36000,
              "value" : 35
            },
            {
              "startTime" : 43200,
              "value" : 30
            },
            {
              "startTime" : 50400,
              "value" : 35
            },
            {
              "startTime" : 57600,
              "value" : 40
            }
          ],
          "referenceTimeInterval" : 0,
          "repeatInterval" : 86400,
          "timeZone" : {
            "identifier" : "GMT-0700"
          }
        }
      },
      "maximumBasalRatePerHour" : 3,
      "maximumBolus" : 5,
      "suspendThreshold" : {
        "unit" : "mg/dL",
        "value" : 80
      }
    }
    """
    
    func testInsulinModelEncoding() throws {
        let adult = ExponentialInsulinModelPreset.rapidActingAdult
        let child = ExponentialInsulinModelPreset.rapidActingChild
        
        XCTAssertEqual("""
        "rapidActingAdult"
        """, String(data: try encoder.encode(adult), encoding: .utf8)!)
        XCTAssertEqual("""
        "rapidActingChild"
        """, String(data: try encoder.encode(child), encoding: .utf8)!)
    }

    func testTherapySettingEncoding() throws {
        let original = TherapySettings.test
        let data = try encoder.encode(original)
        XCTAssertEqual(encodedString, String(data: data, encoding: .utf8)!)
    }

    func testTherapySettingDecoding() throws {
        let data = encodedString.data(using: .utf8)!
        let decoded = try decoder.decode(TherapySettings.self, from: data)
        let expected = TherapySettings.test

        XCTAssertEqual(expected, decoded)

        XCTAssertEqual(decoded.basalRateSchedule, expected.basalRateSchedule)
        XCTAssertEqual(decoded.insulinSensitivitySchedule, expected.insulinSensitivitySchedule)
        XCTAssertEqual(decoded.correctionRangeOverrides, expected.correctionRangeOverrides)
        XCTAssertEqual(decoded.maximumBolus, expected.maximumBolus)
        XCTAssertEqual(decoded.maximumBasalRatePerHour, expected.maximumBasalRatePerHour)
        XCTAssertEqual(decoded.suspendThreshold, expected.suspendThreshold)
        XCTAssertEqual(decoded.carbRatioSchedule, expected.carbRatioSchedule)
        XCTAssertEqual(decoded.defaultRapidActingModel, expected.defaultRapidActingModel)
        XCTAssertEqual(decoded.glucoseTargetRangeSchedule, expected.glucoseTargetRangeSchedule)
    }
}

fileprivate extension TherapySettings {
    static var test: TherapySettings {
        let timeZone = TimeZone(secondsFromGMT: -25200)
        let glucoseTargetRangeSchedule =  GlucoseRangeSchedule(
            rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                                                 dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                              RepeatingScheduleValue(startTime: .hours(8), value: DoubleRange(minValue: 95.0, maxValue: 105.0)),
                                                              RepeatingScheduleValue(startTime: .hours(14), value: DoubleRange(minValue: 95.0, maxValue: 105.0)),
                                                              RepeatingScheduleValue(startTime: .hours(16), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                                                              RepeatingScheduleValue(startTime: .hours(18), value: DoubleRange(minValue: 90.0, maxValue: 100.0)),
                                                              RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 110.0, maxValue: 120.0))],
                                                 timeZone: timeZone)!)
        let basalRateSchedule = BasalRateSchedule(
            dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 1.0),
                         RepeatingScheduleValue(startTime: .hours(8), value: 1.125),
                         RepeatingScheduleValue(startTime: .hours(10), value: 1.25),
                         RepeatingScheduleValue(startTime: .hours(12), value: 1.5),
                         RepeatingScheduleValue(startTime: .hours(14), value: 1.25),
                         RepeatingScheduleValue(startTime: .hours(16), value: 1.5),
                         RepeatingScheduleValue(startTime: .hours(18), value: 1.25),
                         RepeatingScheduleValue(startTime: .hours(21), value: 1.0)],
            timeZone: timeZone)!
        let insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 45.0),
                         RepeatingScheduleValue(startTime: .hours(8), value: 40.0),
                         RepeatingScheduleValue(startTime: .hours(10), value: 35.0),
                         RepeatingScheduleValue(startTime: .hours(12), value: 30.0),
                         RepeatingScheduleValue(startTime: .hours(14), value: 35.0),
                         RepeatingScheduleValue(startTime: .hours(16), value: 40.0)],
            timeZone: timeZone)!
        let carbRatioSchedule = CarbRatioSchedule(
            unit: .gram(),

            dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 10.0),
                         RepeatingScheduleValue(startTime: .hours(8), value: 12.0),
                         RepeatingScheduleValue(startTime: .hours(10), value: 9.0),
                         RepeatingScheduleValue(startTime: .hours(12), value: 10.0),
                         RepeatingScheduleValue(startTime: .hours(14), value: 11.0),
                         RepeatingScheduleValue(startTime: .hours(16), value: 12.0),
                         RepeatingScheduleValue(startTime: .hours(18), value: 8.0),
                         RepeatingScheduleValue(startTime: .hours(21), value: 10.0)],
            timeZone: timeZone)!
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 80.0, maxValue: 90.0),
            workout: DoubleRange(minValue: 130.0, maxValue: 140.0),
            unit: .milligramsPerDeciliter)

        return TherapySettings(
            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
            correctionRangeOverrides: correctionRangeOverrides,
            maximumBasalRatePerHour: 3,
            maximumBolus: 5,
            suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 80),
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            carbRatioSchedule: carbRatioSchedule,
            basalRateSchedule: basalRateSchedule,
            defaultRapidActingModel: ExponentialInsulinModelPreset.rapidActingAdult
        )
    }
}
