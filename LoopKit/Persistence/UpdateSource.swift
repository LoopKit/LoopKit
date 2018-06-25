//
//  UpdateSource.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//


/// Categorizes the source of a data update
///
/// - changedInApp: Data was added, modified, or deleted by the current app process
/// - queriedByHealthKit: Data was added or deleted in the Health database
public enum UpdateSource: Int {
    case changedInApp
    case queriedByHealthKit
}
