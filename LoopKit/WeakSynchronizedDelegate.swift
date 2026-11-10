//
//  WeakSynchronizedDelegate.swift
//  LoopKit
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

/// Holds a device manager's delegate weakly, and delivers the manager's calls to it one at a time, in the
/// order they were made.
public final class WeakSynchronizedDelegate<Delegate>: @unchecked Sendable {

    private let lock = UnfairLock()
    private weak var _delegate: AnyObject?
    private var last: Task<Void, Never>?

    public init() {}

    public var delegate: Delegate? {
        get {
            return lock.withLock {
                return _delegate as? Delegate
            }
        }
        set {
            lock.withLock {
                _delegate = newValue as AnyObject
            }
        }
    }

    /// Runs `block` once every block passed to `notify` before it has finished. Await the returned task to
    /// wait for the block itself.
    @discardableResult
    public func notify(_ block: @escaping (_ delegate: Delegate?) async -> Void) -> Task<Void, Never> {
        return lock.withLock {
            let previous = last
            let delegate = _delegate as? Delegate
            let task = Task {
                await previous?.value
                await block(delegate)
            }
            last = task
            return task
        }
    }

    public func notifyDelayed(by interval: TimeInterval, _ block: @escaping (_ delegate: Delegate?) async -> Void) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(max(0, interval) * 1_000_000_000))
            notify(block)
        }
    }

    /// Runs `block` now, without waiting for earlier notifications, and returns its result. For questions
    /// the manager asks its delegate.
    public func call<ReturnType>(_ block: (_ delegate: Delegate?) async -> ReturnType) async -> ReturnType {
        return await block(delegate)
    }
}
