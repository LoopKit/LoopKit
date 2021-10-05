//
//  VersionCheckService.swift
//  LoopKit
//
//  Created by Rick Pasetto on 9/8/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation

// Note: order is important for VersionUpdate.  Later version updates are more critical than earlier ones.  Do not reorder!
public enum VersionUpdate: Comparable, CaseIterable {
    /// No version update needed.
    case noneNeeded
    /// The version is unsupported; the app needs to be updated to the latest "supported" version.  Not a critical update.
    case supportedNeeded
    /// The app must be updated immediately.
    case criticalNeeded
}

extension VersionUpdate {
    public var localizedDescription: String {
        switch self {
        case .noneNeeded:
            return NSLocalizedString("No Update Needed", comment: "Description of no software update needed")
        case .supportedNeeded:
            return NSLocalizedString("Supported Update Needed", comment: "Description of supported software update needed")
        case .criticalNeeded:
            return NSLocalizedString("Critical Update Needed", comment: "Description of critical software update needed")
        }
    }
}

public protocol VersionCheckService: Service {

    /**
     Check whether the given app version for the given `bundleIdentifier` needs an update.

     - Parameter bundleIdentifier: The calling app's `bundleIdentifier` (a.k.a. `CFBundleIdentifier`) string.
     - Parameter currentVersion: The current version to check.
     - Parameter completion: The completion function to call with any success result (or `nil` if not known) or failure.  
     */
    func checkVersion(bundleIdentifier: String, currentVersion: String, completion: @escaping (Result<VersionUpdate?, Error>) -> Void)
}
