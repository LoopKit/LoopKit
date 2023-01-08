//
//  RemoteDataService.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

/**
 Protocol for a remote data service.
*/
public protocol RemoteDataService: Service {

    /// The maximum number of alert data to upload to the remote data service at one time.
    var alertDataLimit: Int? { get }

    /**
     Upload alert data to the remote data service.

     - Parameter stored: The stored alert data to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadAlertData(_ stored: [SyncAlertObject], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of carb data to upload to the remote data service at one time.
    var carbDataLimit: Int? { get }

    /**
     Upload carb data to the remote data service.

     - Parameter created: The created carb data to upload.
     - Parameter updated: The updated carb data to upload.
     - Parameter deleted: The deleted carb data to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadCarbData(created: [SyncCarbObject], updated: [SyncCarbObject], deleted: [SyncCarbObject], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /**
     Upload overrides to the remote data service.

     - Parameter updated: The updated or new overrides to upload.
     - Parameter deleted: The deleted overrides to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadTemporaryOverrideData(updated: [TemporaryScheduleOverride], deleted: [TemporaryScheduleOverride], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of dose data to upload to the remote data service at one time.
    var doseDataLimit: Int? { get }

    /**
     Upload dose data to the remote data service.

     - Parameter created: The created dose data to upload.
     - Parameter deleted: The deleted dose data to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadDoseData(created: [DoseEntry], deleted: [DoseEntry], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of dosing decision data to upload to the remote data service at one time.
    var dosingDecisionDataLimit: Int? { get }

    /**
     Upload dosing decision data to the remote data service.

     - Parameter stored: The stored dosing decision data to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadDosingDecisionData(_ stored: [StoredDosingDecision], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of glucose data to upload to the remote data service at one time.
    var glucoseDataLimit: Int? { get }

    /**
     Upload glucose data to the remote data service.

     - Parameter stored: The stored glucose data to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadGlucoseData(_ stored: [StoredGlucoseSample], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of pump event data to upload to the remote data service at one time.
    var pumpEventDataLimit: Int? { get }

    /**
     Upload pump event data to the remote data service.

     - Parameter stored: The stored pump event data to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadPumpEventData(_ stored: [PersistedPumpEvent], completion: @escaping (_ result: Result<Bool, Error>) -> Void)

    /// The maximum number of settings data to upload to the remote data service at one time.
    var settingsDataLimit: Int? { get }

    /**
     Upload settings data to the remote data service.

     - Parameter stored: The stored settings data to upload.
     - Parameter completion: The completion function to call with any success or failure.
     */
    func uploadSettingsData(_ stored: [StoredSettings], completion: @escaping (_ result: Result<Bool, Error>) -> Void)
    
    /**
     Validates a push notification originated from this data service.
     - Parameter notification: The push notification dictionary
     - Returns: Success
     */
    func validatePushNotificationSource(_ notification: [String: AnyObject]) -> Result<Void, Error>

}

public extension RemoteDataService {
    var alertDataLimit: Int? { return nil }
    var carbDataLimit: Int? { return nil }
    var doseDataLimit: Int? { return nil }
    var dosingDecisionDataLimit: Int? { return nil }
    var glucoseDataLimit: Int? { return nil }
    var pumpEventDataLimit: Int? { return nil }
    var settingsDataLimit: Int? { return nil }

    func validatePushNotificationSource(_ notification: [String: AnyObject]) -> Result<Void, Error> { return .failure(PushNotificationValidationError.notificationsNotSupported) }
}

enum PushNotificationValidationError: LocalizedError {
    case notificationsNotSupported
    
    var errorDescription: String? {
        switch self {
        case .notificationsNotSupported:
            return "Service does not handle push notifications"
        }
    }
}
