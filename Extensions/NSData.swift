//
//  NSData.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/26/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension Data {
    var hexadecimalString: String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
