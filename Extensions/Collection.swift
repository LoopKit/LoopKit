//
//  Collection.swift
//  LoopKit
//
//  Created by Michael Pangburn on 2/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

/// Returns the cartesian product of a sequence and a collection.
///
/// O(1), but O(_n_*_m_) on iteration.
/// - Note: Don't mind the scary return type; it's just a lazy sequence.
func product<S: Sequence, C: Collection>(_ s: S, _ c: C) -> LazySequence<FlattenSequence<LazyMapSequence<S, LazyMapSequence<C, (S.Element, C.Element)>>>> {
    return s.lazy.flatMap { first in
        c.lazy.map { second in
            (first, second)
        }
    }
}

extension Collection {
    /// Returns a sequence containing adjacent pairs of elements in the ordered collection.
    func adjacentPairs() -> Zip2Sequence<Self, SubSequence> {
        return zip(self, dropFirst())
    }
}

extension Collection {
    func chunked(into size: Int) -> [SubSequence] {
        precondition(size > 0, "Chunk size must be greater than zero")
        var start = startIndex
        return stride(from: 0, to: count, by: size).map {_ in
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            defer { start = end }
            return self[start..<end]
        }
    }
}

extension RandomAccessCollection {
    /// Returns all unique pair combinations of elements in the collection.
    ///
    /// O(1), but O(*n*²) on iteration.
    /// - Note: Don't mind the scary return type; it's just a lazy sequence.
    func allPairs() -> LazyMapSequence<LazyFilterSequence<FlattenSequence<LazyMapSequence<Indices, LazyMapSequence<Indices, (Index, Index)>>>>, (Element, Element)> {
        return product(indices, indices).filter(<).map {
            (self[$0], self[$1])
        }
    }
}

extension RangeReplaceableCollection where Index: Hashable {
    /// Removes the elements at all of the given indices.
    ///
    /// O(_n_*_m_)
    mutating func removeAll<S: Sequence>(at indices: S) where S.Element == Index {
        let arranged = Set(indices).sorted(by: >)
        for index in arranged {
            remove(at: index)
        }
    }
}

// Source:  https://github.com/apple/swift/blob/master/stdlib/public/core/CollectionAlgorithms.swift#L476
extension Collection {
    /// Returns the index of the first element in the collection that matches
    /// the predicate.
    ///
    /// The collection must already be partitioned according to the predicate.
    /// That is, there should be an index `i` where for every element in
    /// `collection[..<i]` the predicate is `false`, and for every element
    /// in `collection[i...]` the predicate is `true`.
    ///
    /// - Parameter predicate: A predicate that partitions the collection.
    /// - Returns: The index of the first element in the collection for which
    ///   `predicate` returns `true`.
    ///
    /// - Complexity: O(log *n*), where *n* is the length of this collection if
    ///   the collection conforms to `RandomAccessCollection`, otherwise O(*n*).
    func partitioningIndex(
        where predicate: (Element) throws -> Bool
    ) rethrows -> Index {
        var n = count
        var l = startIndex

        while n > 0 {
            let half = n / 2
            let mid = index(l, offsetBy: half)
            if try predicate(self[mid]) {
                n = half
            } else {
                l = index(after: mid)
                n -= half + 1
            }
        }
        return l
    }
}
