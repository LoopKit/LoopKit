//
//  CorrectionRangeOverridesEditorViewModel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-15.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct CorrectionRangeOverridesEditorViewModel {

    let correctionRangeOverrides: CorrectionRangeOverrides

    let suspendThreshold: GlucoseThreshold?

    let correctionRangeScheduleRange: ClosedRange<HKQuantity>

    let preset: CorrectionRangeOverrides.Preset

    let guardrail: Guardrail<HKQuantity>

    var saveCorrectionRangeOverride: (_ correctionRangeOverrides: CorrectionRangeOverrides) -> Void
    
    private var duration: TimeInterval? = TimeInterval(hours: 1)
    var overallInsulinPercentage: Double = 1 // This should always be 1
    
    var durationString: String? {
        guard let duration else {
            return nil
        }
        
        return unitFormatter.string(from: duration)
    }
    
    var insulinPercentageString: String {
        return "\(String(format: "%.0f", 100 * overallInsulinPercentage))% \(LocalizedString("of scheduled", comment: ""))"
    }
    
    var correctionRangeString: String? {
        correctionRangeOverrides.workout?.localizedDescription(unit: .milligramsPerDeciliter)
    }
    
    private let unitFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .short
        return formatter
    }()

    public init(therapySettingsViewModel: TherapySettingsViewModel,
                preset: CorrectionRangeOverrides.Preset,
                didSave: (() -> Void)? = nil)
    {
        self.correctionRangeOverrides = therapySettingsViewModel.correctionRangeOverrides
        self.suspendThreshold = therapySettingsViewModel.suspendThreshold
        self.correctionRangeScheduleRange = therapySettingsViewModel.correctionRangeScheduleRange
        self.guardrail = Guardrail.correctionRangeOverride(
            for: preset,
            correctionRangeScheduleRange: therapySettingsViewModel.correctionRangeScheduleRange,
            suspendThreshold: therapySettingsViewModel.suspendThreshold)
        self.preset = preset

        self.saveCorrectionRangeOverride = { [weak therapySettingsViewModel] correctionRangeOverrides in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }
            therapySettingsViewModel.saveCorrectionRangeOverride(preset: preset,
                                                                 correctionRangeOverrides: correctionRangeOverrides)
            didSave?()
        }
    }
}
