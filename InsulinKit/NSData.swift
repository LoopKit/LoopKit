//
//  NSData.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/26/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension NSData {
    var hexadecimalString: String {
        let bytesCollection = UnsafeBufferPointer<UInt8>(start: UnsafePointer<UInt8>(bytes), count: length)

        let string = NSMutableString(capacity: length * 2)

        for byte in bytesCollection {
            string.appendFormat("%02x", byte)
        }

        return string as String
    }
}
