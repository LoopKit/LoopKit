//
//  InsulinModel.swift
//  LoopKit
//
//  Created by Pete Schwamb on 7/26/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation


public protocol InsulinModel: CustomDebugStringConvertible {
    
    /// Returns the percentage of total insulin effect remaining at a specified interval after delivery; also known as Insulin On Board (IOB).
    /// Return value is within the range of 0-1
    ///
    /// - Parameters:
    ///   - time: The interval after insulin delivery
    func percentEffectRemaining(at time: TimeInterval) -> Double
    
    /// The expected duration, including any effect delay, of an insulin dose, from the time of the dose
    var effectDuration: TimeInterval { get }
    
    /// The time after the dose where the effect becomes non-zero
    var delay: TimeInterval { get }
}


