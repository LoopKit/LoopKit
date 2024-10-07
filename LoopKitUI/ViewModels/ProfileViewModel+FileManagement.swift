//
//  ProfileViewModel+FileManagement.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-05-19.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit

public enum ProfileValidationError: Error, LocalizedError {
    case fileLoadError
    case unsupportedIncrement
    case correctionRangeError
    case insulinSensitivityError
    case carbRatioError
    case basalRateError
    case maxBasalRateNotSet

    public var errorDescription: String? {
        switch self {
        case .fileLoadError:
            return "Unable to load the profile file."
        case .unsupportedIncrement:
            return "The profile contains unsupported increments."
        case .correctionRangeError:
            return "Correction Range values are out of bounds."
        case .insulinSensitivityError:
            return "Insulin Sensitivity values are out of bounds."
        case .carbRatioError:
            return "Carb Ratio values are out of bounds."
        case .basalRateError:
            return "Basal Rate values are out of bounds."
        case .maxBasalRateNotSet:
            return "Maximum Basal Rate is not set."
        }
    }
}

public enum LoadProfileResult {
    case success
    case failure(Error)
}

// MARK: File management
extension ProfileViewModel {
    private func setCurrentProfile(name: String) {
        currentProfileName = name
    }
    
    private func clearCurrentProfile() {
        currentProfileName = nil
    }
    
    private func getCurrentProfileName() -> String? {
        return currentProfileName
    }
    
    private var profilesDirectory: URL {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("LoopProfile")
    }

    private func createProfileDirectoryIfNotExists() throws {
        let fileManager = FileManager.default
        var isDir : ObjCBool = false
        if !fileManager.fileExists(atPath: profilesDirectory.path, isDirectory: &isDir) {
            try fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true, attributes: nil)
        } else if !isDir.boolValue {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError, userInfo: nil)
        }
    }

    private func getAllProfileFiles() throws -> [URL] {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil)
        return files.filter { $0.pathExtension == "json" }
    }

    private func encodeProfile(_ profile: Profile) throws -> Data {
        return try JSONEncoder().encode(profile)
    }

    private func decodeProfile(from data: Data) throws -> Profile {
        return try JSONDecoder().decode(Profile.self, from: data)
    }

    public func saveProfile(withName name: String) {
        do {
            try createProfileDirectoryIfNotExists()

            if let existingProfile = getProfileReference(withName: name) {
                removeProfile(profileReference: existingProfile)
            }

            let profile = Profile(
                name: name,
                correctionRange: (therapySettings.glucoseTargetRangeSchedule?.schedule(for: .milligramsPerDeciliter)!)!,
                carbRatioSchedule: therapySettings.carbRatioSchedule!,
                basalRateSchedule: therapySettings.basalRateSchedule!,
                insulinSensitivitySchedule: (therapySettings.insulinSensitivitySchedule?.schedule(for: .milligramsPerDeciliter)!)!,
                sortOrder: -1
            )

            let jsonData = try encodeProfile(profile)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let fileName = dateFormatter.string(from: Date()) + ".json"
            let fileURL = profilesDirectory.appendingPathComponent(fileName)

            try jsonData.write(to: fileURL)
            setCurrentProfile(name: name)

            self.loadProfiles()
        } catch {
            print("An error occurred while saving profile: \(error)")
        }
    }

    public func renameProfile(oldName: String, newName: String) {
        if currentProfileName == oldName {
            currentProfileName = newName
        }
        
        do {
            guard let profileReference = getProfileReference(withName: oldName) else {
                print("Profile with old name not found.")
                return
            }
            
            let profile = try getProfile(from: profileReference)
            
            let newProfile = Profile(
                name: newName,
                correctionRange: profile.correctionRange,
                carbRatioSchedule: profile.carbRatioSchedule,
                basalRateSchedule: profile.basalRateSchedule,
                insulinSensitivitySchedule: profile.insulinSensitivitySchedule,
                sortOrder: profile.sortOrder
            )
            
            if let existingProfile = getProfileReference(withName: newName) {
                removeProfile(profileReference: existingProfile)
            }
            
            let jsonData = try encodeProfile(newProfile)
            let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
            
            try jsonData.write(to: fileURL)
            
            self.loadProfiles()
        } catch {
            print("An error occurred while renaming profile: \(error)")
        }
    }

    public func updateProfilesOrder() {
        for (index, profileReference) in profiles.enumerated() {
            do {
                var profile = try getProfile(from: profileReference)
                let newProfile = Profile(
                    name: profile.name,
                    correctionRange: profile.correctionRange,
                    carbRatioSchedule: profile.carbRatioSchedule,
                    basalRateSchedule: profile.basalRateSchedule,
                    insulinSensitivitySchedule: profile.insulinSensitivitySchedule,
                    sortOrder: index
                )
                
                let jsonData = try encodeProfile(newProfile)
                let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
                try jsonData.write(to: fileURL)
                
            } catch {
                print("An error occurred while updating profile order: \(error)")
            }
        }
        loadProfiles()
    }
    
    public func loadProfiles() {
        do {
            let profileFiles = try getAllProfileFiles()
            
            var newProfiles = [ProfileReference]()
            for fileURL in profileFiles {
                let data = try Data(contentsOf: fileURL)
                let profile = try decodeProfile(from: data)
                let profileRef = ProfileReference(name: profile.name, fileName: fileURL.lastPathComponent, sortOrder: profile.sortOrder)
                newProfiles.append(profileRef)
            }
            
            newProfiles.sort { $0.sortOrder ?? 0 < $1.sortOrder ?? 0 }
            
            self.profiles = newProfiles
        } catch {
            print("An error occurred while loading profiles: \(error)")
        }
    }

    public func loadProfile(profile: Profile, completion: @escaping (LoadProfileResult) -> Void) {
        do {
            delegate?.syncBasalRateSchedule(items: profile.basalRateSchedule.items, completion: { [weak self] result in
                switch result {
                case .success(let syncedSchedule):
                    DispatchQueue.main.async {
                        let unit = self?.therapySettings.glucoseTargetRangeSchedule?.unit ?? HKUnit.milligramsPerDeciliter
                        self?.saveCorrectionRange(range: profile.correctionRange.schedule(for: unit)! )
                        self?.saveCarbRatioSchedule(carbRatioSchedule: profile.carbRatioSchedule)
                        self?.saveBasalRates(basalRates: syncedSchedule)
                        self?.saveInsulinSensitivitySchedule(insulinSensitivitySchedule: profile.insulinSensitivitySchedule.schedule(for: unit)!)
                        print("New profile loaded")
                        self?.setCurrentProfile(name: profile.name)
                        completion(.success)
                    }
                case .failure(let error):
                    print("An error occurred while syncing basal rates: \(error)")
                    completion(.failure(error))
                }
            })
        }
    }

    func getProfileReference(withName name: String) -> ProfileReference? {
        return profiles.first(where: { $0.name == name })
    }

    public func removeProfile(profile: Profile) {
        guard let profileReference = getProfileReference(withName: profile.name) else {
            print("No ProfileReference found for given Profile")
            return
        }

        removeProfile(profileReference: profileReference)
        if getCurrentProfileName() == profile.name {
            clearCurrentProfile()
        }
    }

    public func removeProfile(profileReference: ProfileReference) {
        do {
            let fileManager = FileManager.default
            let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
            try fileManager.removeItem(at: fileURL)
            loadProfiles()
        } catch {
            print("An error occurred while removing profile: \(error)")
        }
    }

    func doesProfileExist(withName name: String) -> Bool {
        return profiles.contains(where: { $0.name == name })
    }

    public func getProfile(from profileReference: ProfileReference) throws -> Profile {
        let fileURL = profilesDirectory.appendingPathComponent(profileReference.fileName)
        let data = try Data(contentsOf: fileURL)
        let getProfile = try decodeProfile(from: data)
        return getProfile
    }

    public func validateProfile(_ profile: Profile) -> Result<Void, ProfileValidationError> {
        guard let supportedIncrements = delegate?.pumpSupportedIncrements() else {
            return .failure(.fileLoadError)
        }

        // Checking Correction Range Schedule
        for item in profile.correctionRange.items {
            let minValue = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: item.value.minValue)
            let maxValue = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: item.value.maxValue)

            if !(Guardrail.correctionRange.absoluteBounds.contains(minValue) && Guardrail.correctionRange.absoluteBounds.contains(maxValue)) {
                return .failure(.correctionRangeError)
            }
        }

        // Checking Insulin Sensitivity Schedule
        for item in profile.insulinSensitivitySchedule.items {
            let value = HKQuantity(unit: HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit()), doubleValue: item.value)

            if !Guardrail.insulinSensitivity.absoluteBounds.contains(value) {
                return .failure(.insulinSensitivityError)
            }
        }

        // Checking Carb Ratio Schedule
        for item in profile.carbRatioSchedule.items {
            let value = HKQuantity(unit: .gramsPerUnit, doubleValue: item.value)

            if !Guardrail.carbRatio.absoluteBounds.contains(value) {
                return .failure(.carbRatioError)
            }
        }

        // Checking Basal Rate Schedule
        if let maximumBasalRate = therapySettings.maximumBasalRatePerHour {
            for item in profile.basalRateSchedule.items {
                let value = item.value

                if value > maximumBasalRate || !supportedIncrements.basalRates.contains(value) {
                    return .failure(.basalRateError)
                }
            }
        } else {
            return .failure(.maxBasalRateNotSet)
        }

        return .success(())
    }

    public func isCurrentProfileOutOfSync() -> Bool {
        guard let currentProfileName = self.currentProfileName else {
            return false // No current profile set
        }
        
        // Assuming you have a method `getProfile(from: ProfileReference)`
        // that fetches a Profile given a ProfileReference
        let currentProfileReference = profiles.first { $0.name == currentProfileName }
        
        guard let profileRef = currentProfileReference,
              let profile = try? getProfile(from: profileRef) else {
            return false // Profile not found
        }
        
        return !(therapySettings.glucoseTargetRangeSchedule == profile.correctionRange &&
        therapySettings.carbRatioSchedule == profile.carbRatioSchedule &&
        therapySettings.basalRateSchedule == profile.basalRateSchedule &&
        therapySettings.insulinSensitivitySchedule == profile.insulinSensitivitySchedule)
    }
}
