//
//  CriticalEventLog.swift
//  LoopKit
//
//  Created by Darin Krauss on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol CriticalEventLog {

    /// The name for the critical event log export.
    var exportName: String { get }

    /// Calculate the progress total unit count for the critical event log export for the specified date range.
    ///
    /// - Parameters:
    ///   - startDate: The start date for the critical events to export.
    ///   - endDate: The end date for the critical events to export. Optional. If not specified, default to now.
    /// - Returns: An progress total unit count, or an error.
    func exportProgressTotalUnitCount(startDate: Date, endDate: Date?) -> Result<Int64, Error>

    /// Export the critical event log for the specified date range.
    ///
    /// - Parameters:
    ///   - startDate: The start date for the critical events to export.
    ///   - endDate: The end date for the critical events to export.
    ///   - stream: The output stream to write the critical event log to. Typically writes JSON UTF-8 text.
    ///   - progressor: The estimated duration progress to use to check if cancelled and report progress.
    /// - Returns: Any error that occurs during the export, or nil if successful.
    func export(startDate: Date, endDate: Date, to stream: OutputStream, progress: Progress) -> Error?
}

public enum CriticalEventLogError: Error {

    /// The export was cancelled either by the user or the OS.
    case cancelled
}

public let criticalEventLogExportProgressUnitCountPerFetch: Int64 = 250
