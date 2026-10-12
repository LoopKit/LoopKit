//
//  CgmEvent.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm

/// Stored as a string, so a type added later is kept rather than dropped by an older reader.
public struct CgmEventType: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let sensorStart = CgmEventType(rawValue: "sensorStart")
    public static let sensorEnd = CgmEventType(rawValue: "sensorEnd")
    public static let transmitterStart = CgmEventType(rawValue: "transmitterStart")
    public static let transmitterEnd = CgmEventType(rawValue: "transmitterEnd")
    public static let calibration = CgmEventType(rawValue: "calibration")
    /// The device reports a state without reliable glucose, from warmup to a sensor failure; `error`
    /// holds the device's name for the state. Reported by the device when the state changes, not
    /// for communication loss.
    public static let sensorIssue = CgmEventType(rawValue: "sensorIssue")
}

public struct CgmCalibration: Equatable, Sendable {
    /// The value given to the device, usually a fingerstick.
    public var glucose: LoopQuantity
    /// The device's own reading when it was calibrated, if known.
    public var sensorGlucose: LoopQuantity?

    public init(glucose: LoopQuantity, sensorGlucose: LoopQuantity? = nil) {
        self.glucose = glucose
        self.sensorGlucose = sensorGlucose
    }
}

public struct CgmEventError: Equatable, Codable, Sendable {
    /// The device's own code or name for the state, if it has one.
    public var code: String?
    public var message: String?
    /// Whether the error ends the sensor session.
    public var isFatal: Bool

    public init(code: String? = nil, message: String? = nil, isFatal: Bool = false) {
        self.code = code
        self.message = message
        self.isFatal = isFatal
    }
}

public struct PersistedCgmEvent: Equatable {
    public var date: Date
    public var type: CgmEventType
    /// Unique to the hardware the event is about, such as its serial number. Hardware with no
    /// identifier of its own (a G6 sensor) uses that of the transmitter it's attached to.
    public var deviceIdentifier: String
    public var expectedLifetime: TimeInterval?
    public var warmupPeriod: TimeInterval?
    public var failureMessage: String?
    public var calibration: CgmCalibration?
    public var error: CgmEventError?
    /// Device-specific values that have no field of their own.
    public var metadata: [String: String]?

    public init(
        date: Date,
        type: CgmEventType,
        deviceIdentifier: String,
        expectedLifetime: TimeInterval? = nil,
        warmupPeriod: TimeInterval? = nil,
        failureMessage: String? = nil,
        calibration: CgmCalibration? = nil,
        error: CgmEventError? = nil,
        metadata: [String: String]? = nil
    ) {
        self.date = date
        self.type = type
        self.deviceIdentifier = deviceIdentifier
        self.expectedLifetime = expectedLifetime
        self.warmupPeriod = warmupPeriod
        self.failureMessage = failureMessage
        self.calibration = calibration
        self.error = error
        self.metadata = metadata
    }
}

/// Fields kept in the `details` attribute as JSON, so new ones need no model migration.
/// Keys a reader doesn't know are ignored.
struct CgmEventDetails: Codable, Equatable {
    var calibration: Calibration?
    var error: CgmEventError?
    var metadata: [String: String]?

    struct Calibration: Codable, Equatable {
        var glucoseMgdl: Double
        var sensorGlucoseMgdl: Double?
    }

    init(event: PersistedCgmEvent) {
        calibration = event.calibration.map {
            Calibration(
                glucoseMgdl: $0.glucose.doubleValue(for: .milligramsPerDeciliter),
                sensorGlucoseMgdl: $0.sensorGlucose?.doubleValue(for: .milligramsPerDeciliter)
            )
        }
        error = event.error
        metadata = event.metadata
    }

    var isEmpty: Bool {
        calibration == nil && error == nil && metadata == nil
    }

    var cgmCalibration: CgmCalibration? {
        calibration.map {
            CgmCalibration(
                glucose: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.glucoseMgdl),
                sensorGlucose: $0.sensorGlucoseMgdl.map { LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: $0) }
            )
        }
    }
}

extension PersistedCgmEvent {
    init?(managedObject: CgmEvent) {
        guard let type = managedObject.type else {
            return nil
        }
        let details = managedObject.details.flatMap { try? JSONDecoder().decode(CgmEventDetails.self, from: $0) }
        self.init(
            date: managedObject.date,
            type: type,
            deviceIdentifier: managedObject.deviceIdentifier,
            expectedLifetime: managedObject.expectedLifetime,
            warmupPeriod: managedObject.warmupPeriod,
            failureMessage: managedObject.failureMessage,
            calibration: details?.cgmCalibration,
            error: details?.error,
            metadata: details?.metadata
        )
    }

    var encodedDetails: Data? {
        let details = CgmEventDetails(event: self)
        guard !details.isEmpty else {
            return nil
        }
        return try? JSONEncoder().encode(details)
    }
}

extension CgmEvent {
    var persistedCgmEvent: PersistedCgmEvent? {
        return PersistedCgmEvent(managedObject: self)
    }
}
