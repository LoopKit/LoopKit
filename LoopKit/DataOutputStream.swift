//
//  DataOutputStream.swift
//  LoopKit
//
//  Created by Pete Schwamb on 5/7/2023
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

enum DataOutputStreamError: Error {
    case couldNotEncodeString
}

public protocol DataOutputStream: AnyObject {
    // Writes data to the stream. Errors detected while
    // processing should be thrown.
    func write(_ data: Data) throws

    // Lets the receiver know the stream is finished.
    // If sync is true, block until data is finished processing.
    // If no errors thrown, then data was processed successfully.
    func finish(sync: Bool) throws

    var streamError: Error? { get }
}

extension DataOutputStream {
    // Convenience function to convert String into utf8 Data and write it.
    public func write(_ string: String) throws {
        if let data = string.data(using: .utf8) {
            try write(data)
        } else {
            throw DataOutputStreamError.couldNotEncodeString
        }
    }
}
