//
//  Data.swift
//  MockKit
//
//  Created by Pete Schwamb on 6/26/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation

extension Data {
    private func toDefaultEndian<T: FixedWidthInteger>(_: T.Type) -> T {
        return self.withUnsafeBytes({ (rawBufferPointer: UnsafeRawBufferPointer) -> T in
            let bufferPointer = rawBufferPointer.bindMemory(to: T.self)
            guard let pointer = bufferPointer.baseAddress else {
                return 0
            }
            return T(pointer.pointee)
        })
    }

    func toBigEndian<T: FixedWidthInteger>(_ type: T.Type) -> T {
        return T(bigEndian: toDefaultEndian(type))
    }
}
