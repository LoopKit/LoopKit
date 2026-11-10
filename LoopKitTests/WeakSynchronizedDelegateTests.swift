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

private actor Recorder {
    private(set) var entries: [Int] = []
    func append(_ entry: Int) { entries.append(entry) }
}

class WeakSynchronizedDelegateTests: XCTestCase {

    func testNotifyRunsBlocksInOrderWhenAnEarlierBlockSuspends() async {
        let subject = WeakSynchronizedDelegate<TestDelegate>()
        let recorder = Recorder()

        subject.notify { _ in
            try? await Task.sleep(nanoseconds: 50_000_000)
            await recorder.append(1)
        }
        subject.notify { _ in
            await recorder.append(2)
        }
        await subject.notify { _ in
            await recorder.append(3)
        }.value

        let entries = await recorder.entries
        XCTAssertEqual([1, 2, 3], entries)
    }

    func testNotifyPassesTheDelegate() async {
        let subject = WeakSynchronizedDelegate<TestDelegate>()
        let delegate = TestDelegateImpl(id: 42)
        subject.delegate = delegate
        let recorder = Recorder()

        await subject.notify { delegate in
            await recorder.append(delegate?.identify() ?? 0)
        }.value

        let entries = await recorder.entries
        XCTAssertEqual([42], entries)
        withExtendedLifetime(delegate) {}
    }

    func testCallDoesNotWaitForPendingNotifications() async {
        let subject = WeakSynchronizedDelegate<TestDelegate>()
        let delegate = TestDelegateImpl(id: 7)
        subject.delegate = delegate
        let recorder = Recorder()

        let pending = subject.notify { _ in
            try? await Task.sleep(nanoseconds: 200_000_000)
            await recorder.append(1)
        }

        let answer = await subject.call { $0?.identify() }
        let entriesWhenCallReturned = await recorder.entries

        XCTAssertEqual(7, answer)
        XCTAssertEqual([], entriesWhenCallReturned)
        await pending.value
        withExtendedLifetime(delegate) {}
    }

    func testCallFromInsideNotifyDoesNotDeadlock() async {
        let subject = WeakSynchronizedDelegate<TestDelegate>()
        let delegate = TestDelegateImpl(id: 3)
        subject.delegate = delegate
        let recorder = Recorder()

        await subject.notify { _ in
            let answer = await subject.call { $0?.identify() }
            await recorder.append(answer ?? 0)
        }.value

        let entries = await recorder.entries
        XCTAssertEqual([3], entries)
        withExtendedLifetime(delegate) {}
    }

    func testDelegateIsHeldWeakly() {
        let subject = WeakSynchronizedDelegate<TestDelegate>()
        var delegate: TestDelegateImpl? = TestDelegateImpl(id: 1)
        subject.delegate = delegate
        XCTAssertNotNil(subject.delegate)

        delegate = nil

        XCTAssertNil(subject.delegate)
    }
}
