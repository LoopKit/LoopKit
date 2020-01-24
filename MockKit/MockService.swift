//
//  MockService.swift
//  MockKit
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import LoopKit

public final class MockService: Service {
    
    public static let serviceIdentifier = "MockService"
    
    public static let localizedTitle = "Simulator"
    
    public weak var serviceDelegate: ServiceDelegate?
    
    public var remoteData: Bool
    
    public var logging: Bool
    
    public var analytics: Bool
    
    public var history: [String]
    
    private var dateFormatter = ISO8601DateFormatter()
    
    public init() {
        self.remoteData = true
        self.logging = true
        self.analytics = true
        
        self.history = []
    }
    
    public init?(rawState: RawStateValue) {
        self.remoteData = rawState["remoteData"] as? Bool ?? false
        self.logging = rawState["logging"] as? Bool ?? false
        self.analytics = rawState["analytics"] as? Bool ?? false
        
        self.history = []
    }
    
    public var rawState: RawStateValue {
        return [
            "remoteData": remoteData,
            "logging": logging,
            "analytics": analytics
        ]
    }
    
    public func completeCreate() {}
    
    public func completeUpdate() {
        serviceDelegate?.serviceDidUpdateState(self)
    }
    
    public func completeDelete() {}
    
    private func record(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        history.append("\(timestamp): \(message)")
    }
    
}

extension MockService: AnalyticsService {
    
    public func recordAnalyticsEvent(_ name: String, withProperties properties: [AnyHashable: Any]?, outOfSession: Bool) {
        if analytics {
            record("[AnalyticsService] \(name) \(String(describing: properties)) \(outOfSession)")
        }
    }
    
}

extension MockService: LoggingService {
    
    public func log(_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg]) {
        if logging {
            // Since this is only stored in memory, do not worry about public/private qualifiers
            let messageWithoutQualifiers = message.description.replacingOccurrences(of: "%{public}", with: "%").replacingOccurrences(of: "%{private}", with: "%")
            let messageWithArguments = String(format: messageWithoutQualifiers, arguments: args)
            
            record("[LoggingService] \(messageWithArguments)")
        }
    }
    
}

extension MockService: RemoteDataService {
    
    public func uploadCarbData(deleted: [DeletedCarbEntry], stored: [StoredCarbEntry], completion: @escaping (Result<Bool, Error>) -> Void) {
        if remoteData {
            record("[RemoteDataService] Upload carb data")
        }
        completion(.success(false))
    }
    
    public func uploadDoseData(_ stored: [DoseEntry], completion: @escaping (Result<Bool, Error>) -> Void) {
        if remoteData {
            record("[RemoteDataService] Upload dose data")
        }
        completion(.success(false))
    }

    public func uploadDosingDecisionData(_ stored: [StoredDosingDecision], completion: @escaping (Result<Bool, Error>) -> Void) {
        if remoteData {
            record("[RemoteDataService] Upload dosing decision data")
        }
        completion(.success(false))
    }

    public func uploadGlucoseData(_ stored: [StoredGlucoseSample], completion: @escaping (Result<Bool, Error>) -> Void) {
        if remoteData {
            record("[RemoteDataService] Upload glucose data")
        }
        completion(.success(false))
    }
    
    public func uploadPumpEventData(_ stored: [PersistedPumpEvent], completion: @escaping (Result<Bool, Error>) -> Void) {
        if remoteData {
            record("[RemoteDataService] Upload pump event data")
        }
        completion(.success(false))
    }
    
    public func uploadSettingsData(_ stored: [StoredSettings], completion: @escaping (Result<Bool, Error>) -> Void) {
        if remoteData {
            record("[RemoteDataService] Upload settings data")
        }
        completion(.success(false))
    }
    
}
