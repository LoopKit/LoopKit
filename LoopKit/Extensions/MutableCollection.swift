//
//  MutableCollection.swift
//  LoopKit Example
//
//  Created by Michael Pangburn on 4/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

extension MutableCollection {
    public mutating func mutateEach(_ body: (inout Element) throws -> Void) rethrows {
        var index = startIndex
        while index != endIndex {
            try body(&self[index])
            formIndex(after: &index)
        }
    }
}
