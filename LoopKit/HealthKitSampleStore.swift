//
//  HealthKitSampleStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


extension Notification.Name {
    public static let StoreAuthorizationStatusDidChange = Notification.Name(rawValue: "com.loudnate.LoopKit.AuthorizationStatusDidChangeNotification")
}


open class HealthKitSampleStore {

    /// All the sample types we need permission to read
    open var readTypes: Set<HKSampleType> {
        return Set()
    }

    /// All the sample types we need permission to share
    open var shareTypes: Set<HKSampleType> {
        return Set()
    }

    /// The health store used for underlying queries
    public let healthStore = HKHealthStore()

    public init?() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return nil
        }
    }

    /// True if the user has explicitly denied access to any required share types
    public var sharingDenied: Bool {
        for type in shareTypes {
            if healthStore.authorizationStatus(for: type) == .sharingDenied {
                return true
            }
        }

        return false
    }

    /// True if the store requires authorization
    public var authorizationRequired: Bool {
        for type in readTypes.union(shareTypes) {
            if healthStore.authorizationStatus(for: type) == .notDetermined {
                return true
            }
        }

        return false
    }

    /**
     Initializes the HealthKit authorization flow for all required sample types

     - parameter completion: A closure called after authorization is completed. This closure takes two arguments:
        - success: Whether the authorization to share was successful
        - error:   An error object explaining why the authorization was unsuccessful
     */
    open func authorize(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        let parentHandler = completion

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes, completion: { (completed, error) -> Void in

            let success = completed && !self.sharingDenied
            var authError = error

            if !success && authError == nil {
                authError = NSError(
                    domain: HKErrorDomain,
                    code: HKError.errorAuthorizationDenied.rawValue,
                    userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString("com.loudnate.LoopKit.sharingDeniedErrorDescription", tableName: "LoopKit", value: "Authorization Denied", comment: "The error description describing when Health sharing was denied"),
                        NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString("com.loudnate.LoopKit.sharingDeniedErrorRecoverySuggestion", tableName: "LoopKit", value: "Please re-enable sharing in Health", comment: "The error recovery suggestion when Health sharing was denied")
                    ]
                )
            }

            parentHandler(success, authError)

            NotificationCenter.default.post(name: .StoreAuthorizationStatusDidChange, object: self)
        })
    }

    /**
     Queries the preferred unit for the authorized share types. If more than one unit is retrieved,
     then the completion contains just one of them.

     - parameter completion: A closure called after the query is completed. This closure takes two arguments:
        - unit:  The retrieved unit
        - error: An error object explaining why the retrieval was unsuccessful
     */
    public func preferredUnit(_ completion: @escaping (_ unit: HKUnit?, _ error: Error?) -> Void) {
        let postAuthHandler = {
            let quantityTypes = self.shareTypes.flatMap { (sampleType) -> HKQuantityType? in
                return sampleType as? HKQuantityType
            }

            self.healthStore.preferredUnits(for: Set(quantityTypes)) { (quantityToUnit, error) -> Void in
                completion(quantityToUnit.values.first, error)
            }
        }

        if authorizationRequired || sharingDenied {
            authorize({ (success, error) -> Void in
                if error != nil {
                    completion(nil, error)
                } else {
                    postAuthHandler()
                }
            })
        } else {
            postAuthHandler()
        }
    }

}
