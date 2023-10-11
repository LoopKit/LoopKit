//
//  LoopAlgorithmOutput.swift
//  LoopKit
//
//  Created by Pete Schwamb on 10/11/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public enum LoopAlgorithmOutput {
    case manualBolus(ManualBolusRecommendation)
    case automaticBolus(AutomaticDoseRecommendation?)
    case tempBasal(TempBasalRecommendation?)
}
