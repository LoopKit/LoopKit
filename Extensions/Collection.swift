//
//  Collection.swift
//  LoopKit
//
//  Created by Michael Pangburn on 2/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

extension Collection {
    func adjacentPairs() -> Zip2Sequence<Self, SubSequence> {
        return zip(self, dropFirst())
    }
}
