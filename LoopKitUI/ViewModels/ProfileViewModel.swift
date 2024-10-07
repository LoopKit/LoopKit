//
//  ProfileViewModel.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-04-22.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import Combine
import LoopKit
import HealthKit
import SwiftUI

public class ProfileViewModel: ObservableObject {
    
    @Published public var therapySettings: TherapySettings
    @Published public var profiles = [ProfileReference]()
    @Published public var currentProfileName: String? {
        didSet {
            UserDefaults.standard.setValue(currentProfileName, forKey: "currentProfileName")
        }
    }

    internal weak var delegate: TherapySettingsViewModelDelegate?
    
    public init(therapySettings: TherapySettings,
                pumpSupportedIncrements: (() -> PumpSupportedIncrements?)? = nil,
                sensitivityOverridesEnabled: Bool = false,
                adultChildInsulinModelSelectionEnabled: Bool = false,
                prescription: Prescription? = nil,
                delegate: TherapySettingsViewModelDelegate? = nil) {
        self.therapySettings = therapySettings
        self.delegate = delegate
        self.currentProfileName = UserDefaults.standard.string(forKey: "currentProfileName")
        self.loadProfiles()
    }
    
    public func pumpSupportedIncrements() -> PumpSupportedIncrements? {
        return delegate?.pumpSupportedIncrements()
    }
}

public struct Profile: Codable {
    let name: String
    let correctionRange: GlucoseRangeSchedule
    let carbRatioSchedule: CarbRatioSchedule
    let basalRateSchedule: BasalRateSchedule
    let insulinSensitivitySchedule: InsulinSensitivitySchedule
    var sortOrder: Int?
}

public struct ProfileReference: Codable, Equatable {
    var name: String
    var fileName: String
    var sortOrder: Int?
}


// MARK: Saving
extension ProfileViewModel {

    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        delegate?.saveCompletion(therapySettings: therapySettings)
    }

    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
        delegate?.saveCompletion(therapySettings: therapySettings)
    }

    public func saveCarbRatioSchedule(carbRatioSchedule: CarbRatioSchedule) {
        therapySettings.carbRatioSchedule = carbRatioSchedule
        delegate?.saveCompletion(therapySettings: therapySettings)
    }

    public func saveInsulinSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        therapySettings.insulinSensitivitySchedule = insulinSensitivitySchedule
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
}
