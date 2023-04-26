//
//  UUID.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation


extension UUID {
    var data: Data {
        return withUnsafePointer(to: uuid) {
            return Data(bytes: $0, count: MemoryLayout.size(ofValue: uuid))
        }
    }
}
