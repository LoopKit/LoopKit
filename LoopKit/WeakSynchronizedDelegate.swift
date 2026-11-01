//
//  WeakSynchronizedDelegate.swift
//  LoopKit
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public class WeakSynchronizedDelegate<Delegate> {

    private let lock = UnfairLock()
    private weak var _delegate: AnyObject?
    private var _queue: DispatchQueue
    private var lastOrderedTask: Task<Void, Never>?

    public init(queue: DispatchQueue = .main) {
        _queue = queue
    }

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

    public var queue: DispatchQueue! {
        get {
            return lock.withLock {
                return _queue
            }
        }
        set {
            lock.withLock {
                _queue = newValue ?? .main
            }
        }
    }
    
    public func notify(_ block: @escaping (_ delegate: Delegate?) -> Void) {
        var delegate: Delegate?
        var queue: DispatchQueue!

        lock.withLock {
            delegate = _delegate as? Delegate
            queue = _queue
        }

        queue.async {
            block(delegate)
        }
    }
    
    /// Calls an async delegate method in order: each block starts only after the previous one passed here has finished.
    public func notifyInOrder(_ block: @escaping (_ delegate: Delegate?) async -> Void) {
        lock.withLock {
            let delegate = _delegate as? Delegate
            let previous = lastOrderedTask
            lastOrderedTask = Task {
                await previous?.value
                await block(delegate)
            }
        }
    }

    public func notifyDelayed(by interval: TimeInterval, _ block: @escaping (_ delegate: Delegate?) -> Void) {
        var delegate: Delegate?
        var queue: DispatchQueue!

        lock.withLock {
            delegate = _delegate as? Delegate
            queue = _queue
        }

        queue.asyncAfter(deadline: .now() + interval) {
            block(delegate)
        }
    }

    public func call<ReturnType>(_ block: (_ delegate: Delegate?) -> ReturnType) -> ReturnType {
        var delegate: Delegate?
        var queue: DispatchQueue!

        lock.withLock {
            delegate = _delegate as? Delegate
            queue = _queue
        }

        return queue.sync {
            block(delegate)
        }
    }
}
