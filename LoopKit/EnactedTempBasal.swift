//
//  EnactedTempBasal.swift
//  LoopKit
//
//  Extracted from DosingDecisionStore so that a target without the dosing-decision store —
//  a watch running a loan, for instance — can still name the temp basal a pump is currently
//  delivering. The alias is what `TempBasalRecommendation.adjustForCurrentDelivery` speaks in,
//  and that comparison is needed anywhere doses are enacted, not only where they are recorded.
//

import Foundation
import LoopAlgorithm

/// A temp basal that has actually been enacted on a pump, as opposed to one being recommended.
/// Structurally identical to a recommendation; the distinction is which side of delivery it is on.
public typealias EnactedTempBasal = TempBasalRecommendation
