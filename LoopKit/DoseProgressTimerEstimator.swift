//
//  DoseProgressTimerEstimator.swift
//  LoopKit
//
//  Created by Pete Schwamb on 3/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


open class DoseProgressTimerEstimator: DoseProgressReporter {

    private let lock = UnfairLock()

    private var observers = WeakSet<DoseProgressObserver>()

    var timer: DispatchSourceTimer?

    let reportingQueue: DispatchQueue

    public init(reportingQueue: DispatchQueue) {
        self.reportingQueue = reportingQueue
    }

    open var progress: DoseProgress {
        fatalError("progress must be implemented in subclasse")
    }

    public func addObserver(_ observer: DoseProgressObserver) {
        lock.withLock {
            let firstObserver = observers.isEmpty
            observers.insert(observer)
            if firstObserver {
                start()
            }
        }
    }

    public func removeObserver(_ observer: DoseProgressObserver) {
        lock.withLock {
            observers.remove(observer)
            if observers.isEmpty {
                stop()
            }
        }
    }

    public func notify() {
        let observersCopy = lock.withLock { observers }

        for observer in observersCopy {
            observer.doseProgressReporterDidUpdate(self)
        }

        if progress.isComplete {
            lock.withLock { stop() }
        }
    }

    private func start() {
        guard self.timer == nil, !progress.isComplete else {
            return
        }

        let (delay, repeating) = timerParameters()

        let timer = DispatchSource.makeTimerSource(queue: reportingQueue)
        timer.schedule(deadline: .now() + delay, repeating: repeating)
        timer.setEventHandler(handler: { [weak self] in
            self?.notify()
        })
        self.timer = timer
        timer.resume()
    }

    open func timerParameters() -> (delay: TimeInterval, repeating: TimeInterval) {
        fatalError("timerParameters must be been implemented in subclasse")
    }

    private func stop() {
        guard let timer = timer else {
            return
        }

        timer.setEventHandler {}
        timer.cancel()
        self.timer = nil
    }

    deinit {
        lock.withLock { stop() }
    }
}
