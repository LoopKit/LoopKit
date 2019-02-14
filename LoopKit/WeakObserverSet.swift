//
//  WeakObserverSet.swift
//  RileyLink
//
//  Created by Pete Schwamb on 11/18/18.
//  Copyright © 2018 Pete Schwamb. All rights reserved.
//

import Foundation

public class WeakObserverSet<Observer>: Sequence {

    public struct Iterator: IteratorProtocol {
        let enumerator: NSEnumerator

        init(_ enumerator: NSEnumerator) {
            self.enumerator = enumerator
        }

        public mutating func next() -> Observer? {
            return enumerator.nextObject() as? Observer
        }
    }

    private var observers: NSHashTable<NSObject>

    public init() {
        self.observers = NSHashTable<NSObject>.weakObjects()
    }

    public func add(_ observer: Observer) {
        guard let observerObject = observer as? NSObject else {
            fatalError("Could not add \(observer); must conform to NSObject")
        }
        observers.add(observerObject)
    }

    public func remove(_ observer: Observer) {
        guard let observerObject = observer as? NSObject else {
            fatalError("Could not remove \(observer); must conform to NSObject")
        }
        observers.remove(observerObject)
    }

    public func makeIterator() -> Iterator {
        return Iterator(observers.objectEnumerator())
    }
}
