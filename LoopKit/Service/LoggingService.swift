//
//  LoggingService.swift
//  LoopKit
//
//  Created by Darin Krauss on 6/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log

public protocol Logging {

    /// Log a message for the specific subsystem, category, type, and optional arguments. Modeled after OSLog, but
    /// captures all of the necessary data in one function call per message. Note that like OSLog, the message may
    /// contain "%{public}" and "%{private}" string substitution qualifiers that should be observed based upon the
    /// OSLog rules. That is, scalar values are considered public by default, while strings and objects are considered
    /// private by default. The explicitly specified qualifiers override these defaults.
    ///
    /// - Parameters:
    ///   - message: The message to log with optional string substitution. Note that like OSLog, it make contain "%{public}"
    ///     and "%{private}" string substitution qualifiers that should be observed based upon the OSLog rules.
    ///   - subsystem: The subsystem logging the message. Typical the reverse dot notation identifier of the framework.
    ///   - category: The category for the message. Typically the class or extension name.
    ///   - type: The type of the message. One of OSLogType.
    ///   - args: Optional arguments to be substituted into the string.
    func log(_ message: StaticString, subsystem: String, category: String, type: OSLogType, _ args: [CVarArg])

}

public protocol LoggingService: Logging, Service {}

