//
//  Double.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//


extension Double: RawRepresentable {
    public typealias RawValue = Double

    public init?(rawValue: RawValue) {
        self = rawValue
    }

    public var rawValue: RawValue {
        return self
    }
}
