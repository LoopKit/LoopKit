//
//  WeakSynchronizedDelegateTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

private protocol TestDelegate: AnyObject {
    func identify() -> Int
}

private class TestDelegateImpl: TestDelegate {
    let id: Int
    init(id: Int) { self.id = id }
    func identify() -> Int { return id }
}

class WeakSynchronizedDelegateTests: XCTestCase {

    private var delegateQueue: DispatchQueue!
    private var other: DispatchQueue!
    private var third: DispatchQueue!

    override func setUp() {
        super.setUp()
        delegateQueue = DispatchQueue(label: "WeakSynchronizedDelegateTests.delegate")
        other = DispatchQueue(label: "WeakSynchronizedDelegateTests.other")
        third = DispatchQueue(label: "WeakSynchronizedDelegateTests.third")
    }

    func testCallRunsBlockOnDelegateQueueWithDelegate() {
        let subject = WeakSynchronizedDelegate<TestDelegate>(queue: delegateQueue)
        let delegate = TestDelegateImpl(id: 42)
        subject.delegate = delegate

        let result = subject.call { $0?.identify() }

        XCTAssertEqual(42, result)
    }

    func testCallWithNoDelegate() {
        let subject = WeakSynchronizedDelegate<TestDelegate>(queue: delegateQueue)

        XCTAssertNil(subject.call { $0?.identify() })
    }

    /// `call` must not hold the lock while the block runs.
    ///
    /// The block waits for another thread to take the lock, so if `call` is still holding it the
    /// wait times out — it cannot pass by simply outlasting a short block.
    func testCallDoesNotHoldLockDuringBlock() {
        let subject = WeakSynchronizedDelegate<TestDelegate>(queue: delegateQueue)
        subject.delegate = TestDelegateImpl(id: 1)

        let lockTaken = DispatchSemaphore(value: 0)
        let finished = expectation(description: "call completes")

        other.async {
            subject.call { _ in
                self.third.async {
                    // Any other member takes the same lock.
                    _ = subject.queue
                    lockTaken.signal()
                }
                XCTAssertEqual(.success, lockTaken.wait(timeout: .now() + 1),
                               "the lock was still held while the block ran")
            }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 5)
    }

    /// The deadlock as it actually presented: work already running on the delegate queue reaches
    /// back into the delegate (taking the lock) while another thread is in `call`.
    func testCallDoesNotDeadlockAgainstBusyDelegateQueue() {
        let subject = WeakSynchronizedDelegate<TestDelegate>(queue: delegateQueue)
        subject.delegate = TestDelegateImpl(id: 1)

        let started = DispatchSemaphore(value: 0)
        let finished = expectation(description: "call completes")

        // Occupy the delegate queue with a block that needs the lock, as `notify` would.
        delegateQueue.async {
            started.signal()
            Thread.sleep(forTimeInterval: 0.1)
            _ = subject.delegate
        }

        started.wait()
        other.async {
            _ = subject.call { $0?.identify() }
            finished.fulfill()
        }

        wait(for: [finished], timeout: 2)
    }
}
