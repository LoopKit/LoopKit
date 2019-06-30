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
