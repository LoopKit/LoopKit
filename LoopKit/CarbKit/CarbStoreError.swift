//
//  CarbStoreError.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation

extension CarbStore.CarbStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return LocalizedString("com.loudnate.CarbKit.deleteCarbEntryUnownedErrorDescription", value: "Authorization Denied", comment: "The description of an error returned when attempting to delete a sample not shared by the current app")
        case .notConfigured:
            return nil
        case .healthStoreError(let error):
            return error.localizedDescription
        case .coreDataError(let error):
            return error.localizedDescription
        case .noData:
            return LocalizedString("No values found", comment: "Describes an error for no data found in a CarbStore request")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return LocalizedString("com.loudnate.carbKit.sharingDeniedErrorRecoverySuggestion", value: "This sample can be deleted from the Health app", comment: "The error recovery suggestion when attempting to delete a sample not shared by the current app")
        case .notConfigured:
            return nil
        case .healthStoreError:
            return nil
        case .coreDataError:
            return nil
        case .noData:
            return LocalizedString("Ensure carb data exists for the specified date", comment: "Recovery suggestion for a no data error")
        }
    }
}
