//
//  WeakSynchronizedSet.swift
//  LoopKit
//
//  Created by Michael Pangburn
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


/// A set-like collection of weak types, providing closure-based iteration on a client-specified queue
/// Mutations and iterations are thread-safe
public class WeakSynchronizedSet<Element> {
    private typealias Identifier = ObjectIdentifier
    private typealias ElementContainer = ElementDispatchContainer<Element>

    private class ElementDispatchContainer<Element> {
        private weak var _element: AnyObject?
        weak var queue: DispatchQueue?

        var element: Element? {
            return _element as? Element
        }

        init(element: Element, queue: DispatchQueue) {
            // All Swift values are implicitly convertible to `AnyObject`,
            // so this runtime check is the tradeoff for supporting class-constrained protocol types.
            precondition(Mirror(reflecting: element).displayStyle == .class, "Weak references can only be held of class types.")

            self._element = element as AnyObject
            self.queue = queue
        }

        func call(_ body: @escaping (_ element: Element) -> Void) {
            guard let queue = self.queue, let element = self.element else {
                return
            }

            queue.async {
                body(element)
            }
        }
    }

    private let elements: Locked<[Identifier: ElementContainer]>

    public init() {
        elements = Locked([:])
    }

    /// Adds an element and its calling queue
    ///
    /// - Parameters:
    ///   - element: The element
    ///   - queue: The queue to use when performing calls with the element
    public func insert(_ element: Element, queue: DispatchQueue) {
        insert(ElementDispatchContainer(element: element, queue: queue))
    }

    /// Prunes any element references that have been deallocated
    /// - Returns: A reference to the instance for easy chaining
    @discardableResult public func cleanupDeallocatedElements() -> Self {
        elements.mutate { (storage) in
            storage = storage.compactMapValues { $0.element == nil ? nil : $0 }
        }
        return self
    }

    /// Whether the element is in the set
    ///
    /// - Parameter element: The element
    /// - Returns: True if the element is in the set
    public func contains(_ element: Element) -> Bool {
        let id = identifier(for: element)
        return elements.value[id] != nil
    }

    /// The total number of element in the set
    ///
    /// Deallocated references are counted, so calling `cleanupDeallocatedElements` is advised to maintain accuracy of this value
    public var count: Int {
        return elements.value.count
    }

    /// Calls the given closure on each element in the set, on the queue specified when the element was added
    ///
    /// The order of calls is not defined
    ///
    /// - Parameter body: The closure to execute
    public func forEach(_ body: @escaping (Element) -> Void) {
        // Hold the lock while we iterate, since each call is dispatched out
        elements.mutate { (elements) in
            elements.forEach { (pair) in
                pair.value.call(body)
            }
        }
    }

    /// Removes the specified element from the set
    ///
    /// - Parameter element: The element
    public func removeElement(_ element: Element) {
        removeValue(forKey: identifier(for: element))
    }
}

extension WeakSynchronizedSet {
    private func identifier(for element: Element) -> ObjectIdentifier {
        return ObjectIdentifier(element as AnyObject)
    }

    private func identifier(for elementContainer: ElementContainer) -> ObjectIdentifier? {
        guard let element = elementContainer.element else {
            return nil
        }
        return identifier(for: element)
    }

    @discardableResult
    private func insert(_ newMember: ElementContainer) -> (inserted: Bool, memberAfterInsert: ElementContainer?) {
        guard let id = identifier(for: newMember) else {
            return (inserted: false, memberAfterInsert: nil)
        }
        var result: (inserted: Bool, memberAfterInsert: ElementContainer?)!
        elements.mutate { (storage) in
            if let existingMember = storage[id] {
                result = (inserted: false, memberAfterInsert: existingMember)
            } else {
                storage[id] = newMember
                result = (inserted: true, memberAfterInsert: newMember)
            }
        }
        return result
    }

    @discardableResult
    private func removeValue(forKey key: Identifier) -> ElementContainer? {
        var previousMember: ElementContainer?
        elements.mutate { (storage) in
            previousMember = storage.removeValue(forKey: key)
        }
        return previousMember
    }
}
