//
//  WeakSet.swift
//  LoopKit
//
//  Created by Michael Pangburn
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public struct Weak<Value> {
    // Rather than constrain `Value` to `AnyObject`, we store the value privately as `AnyObject`.
    // This allows us to hold weak references to class-constrained protocol types,
    // which as types do not themselves conform to `AnyObject`.
    private weak var _value: AnyObject?

    public var value: Value? {
        return _value as? Value
    }

    public init(_ value: Value) {
        // All Swift values are implicitly convertible to `AnyObject`,
        // so this runtime check is the tradeoff for supporting class-constrained protocol types.
        precondition(Mirror(reflecting: value).displayStyle == .class, "Weak references can only be held of class types.")
        _value = value as AnyObject
    }
}

/// A set that holds weak references to its members.
///
/// `Element` must be a class or class-constrained protocol type.
public struct WeakSet<Element> {
    private var storage: [ObjectIdentifier: Weak<Element>]

    public init<S: Sequence>(_ sequence: S) where S.Element == Element {
        let keysAndValues = sequence.map { (key: ObjectIdentifier($0 as AnyObject), value: Weak($0)) }
        storage = Dictionary(keysAndValues, uniquingKeysWith: { $1 })
    }

    public mutating func cleanupDeallocatedElements() {
        for (id, element) in storage where element.value == nil {
            storage.removeValue(forKey: id)
        }
    }
}

extension WeakSet: SetAlgebra {
    public init() {
        storage = [:]
    }

    public var isEmpty: Bool {
        return storage.values.allSatisfy { $0.value == nil }
    }

    public func contains(_ member: Element) -> Bool {
        let id = ObjectIdentifier(member as AnyObject)
        return storage[id] != nil
    }

    @discardableResult
    public mutating func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        let id = ObjectIdentifier(newMember as AnyObject)
        if let existingMember = storage[id]?.value {
            return (inserted: false, memberAfterInsert: existingMember)
        } else {
            storage[id] = Weak(newMember)
            return (inserted: true, memberAfterInsert: newMember)
        }
    }

    @discardableResult
    public mutating func update(with newMember: Element) -> Element? {
        let id = ObjectIdentifier(newMember as AnyObject)
        let previousMember = storage.removeValue(forKey: id)
        storage[id] = Weak(newMember)
        return previousMember?.value
    }

    @discardableResult
    public mutating func remove(_ member: Element) -> Element? {
        let id = ObjectIdentifier(member as AnyObject)
        return storage.removeValue(forKey: id)?.value
    }

    public mutating func formUnion(_ other: WeakSet<Element>) {
        for (id, element) in other.storage where storage[id] == nil {
            // Ignore deallocated elements
            if element.value != nil {
                storage[id] = element
            }
        }
    }

    public func union(_ other: WeakSet<Element>) -> WeakSet<Element> {
        var result = self
        result.formUnion(other)
        return result
    }

    public mutating func formIntersection(_ other: WeakSet<Element>) {
        for id in storage.keys where other.storage[id] == nil {
            storage.removeValue(forKey: id)
        }
    }

    public func intersection(_ other: WeakSet<Element>) -> WeakSet<Element> {
        var result = self
        result.formIntersection(other)
        return result
    }

    public mutating func formSymmetricDifference(_ other: WeakSet<Element>) {
        for (id, element) in other.storage {
            if storage[id] == nil {
                // Ignore deallocated elements
                if element.value != nil {
                    storage[id] = element
                }
            } else {
                storage.removeValue(forKey: id)
            }
        }
    }

    public func symmetricDifference(_ other: WeakSet<Element>) -> WeakSet<Element> {
        var result = self
        result.formSymmetricDifference(other)
        return result
    }
}

extension WeakSet: Sequence {
    public struct Iterator: IteratorProtocol {
        private var base: Dictionary<ObjectIdentifier, Weak<Element>>.Iterator

        fileprivate init(_ base: Dictionary<ObjectIdentifier, Weak<Element>>.Iterator) {
            self.base = base
        }

        public mutating func next() -> Element? {
            while let element = base.next()?.value {
                if let value = element.value {
                    return value
                }
            }

            return nil
        }
    }

    public func makeIterator() -> Iterator {
        return Iterator(storage.makeIterator())
    }
}

extension WeakSet: Equatable {
    public static func == (lhs: WeakSet, rhs: WeakSet) -> Bool {
        return lhs.identifiers() == rhs.identifiers()
    }

    private func identifiers() -> Set<ObjectIdentifier> {
        let ids = storage.compactMap { (id, element) -> ObjectIdentifier? in
            // Ignore deallocated elements
            guard element.value != nil else {
                return nil
            }
            return id
        }

        return Set(ids)
    }
}

extension WeakSet: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
