//
//  UnfairLock.swift
//  LoopKit Example
//
//  Created by Pete Schwamb on 3/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

// Source: http://www.russbishop.net/the-law

import Foundation

public class UnfairLock {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>

    public init() {
        _lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock())
    }

    deinit {
        _lock.deallocate()
    }

    public func withLock<ReturnValue>(_ f: () throws -> ReturnValue) rethrows -> ReturnValue {
        os_unfair_lock_lock(_lock)
        defer { os_unfair_lock_unlock(_lock) }
        return try f()
    }

    public func assertOwned() {
        os_unfair_lock_assert_owner(_lock)
    }

    public func assertNotOwned() {
        os_unfair_lock_assert_not_owner(_lock)
    }
}
