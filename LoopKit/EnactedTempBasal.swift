//
//  EnactedTempBasal.swift
//  LoopKit
//
//  Moved out of DosingDecisionStore so a target without that store can still name the temp
//  basal a pump is delivering.
//

import Foundation
import LoopAlgorithm

/// A temp basal that has actually been enacted on a pump, as opposed to one being recommended.
/// Structurally identical to a recommendation; the distinction is which side of delivery it is on.
public typealias EnactedTempBasal = TempBasalRecommendation
