//
//  PresetsTraining.swift
//  Loop
//
//  Created by Cameron Ingham on 8/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

@Observable
public class PresetsTrainingCompletion {
    
    public let allowDebugFeatures: Bool
    
    public init(allowDebugFeatures: Bool) {
        self.allowDebugFeatures = allowDebugFeatures
    }
    
    public var completedChapters: [PresetsTraining.Chapter: Bool] {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "completedPresetTrainingChapters") else {
                return .default
            }
            
            return [PresetsTraining.Chapter: Bool](rawValue: rawValue) ?? .default
        }
        set {
            withMutation(keyPath: \.completedChapters) {
                UserDefaults.standard.setValue(newValue.rawValue, forKey: "completedPresetTrainingChapters")
            }
        }
    }
    
    public var isComplete: Bool {
        completedChapters.values.allSatisfy({ $0 })
    }
    
    public func complete(to chapter: PresetsTraining.Chapter) {
        guard allowDebugFeatures else { return }
        
        guard let chapterIndex = PresetsTraining.Chapter.allCases.firstIndex(of: chapter) else {
            return
        }
        
        for index in 0..<chapterIndex {
            let chapterToComplete = PresetsTraining.Chapter.allCases[index]
            completedChapters[chapterToComplete] = true
        }
        
        for index in chapterIndex..<PresetsTraining.Chapter.allCases.count {
            let chapterToIncomplete = PresetsTraining.Chapter.allCases[index]
            completedChapters[chapterToIncomplete] = false
        }
    }
}

@Observable
public class PresetsTraining {
    public enum Chapter: CaseIterable, Hashable, Sendable, Codable {
        case customizingPresets
        case illness
        case dailyActivities
        case exercise
        case trainingComplete
        
        public var title: Text {
            switch self {
            case .customizingPresets: Text("Customizing Presets")
            case .illness: Text("Presets for Illness")
            case .dailyActivities: Text("Presets for Daily Activities")
            case .exercise: Text("Presets for Exercise")
            case .trainingComplete: Text("Training Complete")
            }
        }
        
        public var firstStep: Step {
            switch self {
            case .customizingPresets: .customizingPresets(.customizingPresets)
            case .illness: .illness(.commonUses)
            case .dailyActivities: .dailyActivities(.commonUses)
            case .exercise: .exercise(.commonUses)
            case .trainingComplete: .trainingComplete
            }
        }
    }
    
    public enum Step: Hashable, Sendable {
        public enum CustomizingPresets: CaseIterable, Hashable, Sendable {
            case customizingPresets
            case overallInsulin
            case correctionRange
        }
        
        case customizingPresets(CustomizingPresets)
        
        public enum Illness: CaseIterable, Hashable, Sendable {
            case commonUses
            case presetsForIllness
            case overallInsulin
            case correctionRange
            case duration
            case impactOnBolusing
        }
        
        case illness(Illness)
        
        public enum DailyActivities: CaseIterable, Hashable, Sendable {
            case commonUses
            case presetsForDailyActivities
            case overallInsulin
            case correctionRange
            case savedPresets
        }
        
        case dailyActivities(DailyActivities)
        
        public enum Exercise: CaseIterable, Hashable, Sendable {
            case commonUses
            case presetsForExercise
            case perceivedIntensity
            case lightToModerateExercise
            case highIntensityExercise
            case mixedIntensityExercise
            case exerciseAndGlucoseActiveInsulin
            case exerciseAndGlucoseTimeOfDay
            case exerciseAndGlucoseMealTiming
            case exerciseAndGlucoseCompetitionStress
            case preventingLows
            case unplannedActivity
        }
        
        case exercise(Exercise)
        
        case trainingComplete
        
        public func title(appName: String) -> String {
            switch self {
            case .customizingPresets(let customizingPresets):
                switch customizingPresets {
                case .customizingPresets:
                    NSLocalizedString("Customizing Presets", comment: "")
                case .overallInsulin:
                    NSLocalizedString("Overall Insulin", comment: "")
                case .correctionRange:
                    NSLocalizedString("Correction Range", comment: "")
                }
            case .illness(let illness):
                switch illness {
                case .commonUses:
                    NSLocalizedString("Common Uses of Presets", comment: "")
                case .presetsForIllness:
                    NSLocalizedString("Presets for Illness", comment: "")
                case .overallInsulin:
                    NSLocalizedString("Overall Insulin", comment: "")
                case .correctionRange:
                    NSLocalizedString("Correction Range", comment: "")
                case .duration:
                    NSLocalizedString("Duration", comment: "")
                case .impactOnBolusing:
                    NSLocalizedString("Impact on Bolusing", comment: "")
                }
            case .dailyActivities(let dailyActivities):
                switch dailyActivities {
                case .commonUses:
                    NSLocalizedString("Common Uses of Presets", comment: "")
                case .presetsForDailyActivities:
                    NSLocalizedString("Presets for Daily Activity", comment: "")
                case .overallInsulin:
                    NSLocalizedString("Overall Insulin", comment: "")
                case .correctionRange:
                    NSLocalizedString("Correction Range", comment: "")
                case .savedPresets:
                    NSLocalizedString("Saved Presets", comment: "")
                }
            case .exercise(let exercise):
                switch exercise {
                case .commonUses:
                    NSLocalizedString("Common Uses of Presets", comment: "")
                case .presetsForExercise:
                    NSLocalizedString("Presets for Exercise", comment: "")
                case .perceivedIntensity:
                    NSLocalizedString("Perceived Intensity", comment: "")
                case .lightToModerateExercise:
                    NSLocalizedString("Light-to-Moderate Intensity Exercise", comment: "")
                case .highIntensityExercise:
                    NSLocalizedString("High-Intensity Exercise", comment: "")
                case .mixedIntensityExercise:
                    NSLocalizedString("Mixed-Intensity Exercise", comment: "")
                case .exerciseAndGlucoseActiveInsulin,
                     .exerciseAndGlucoseTimeOfDay,
                     .exerciseAndGlucoseMealTiming,
                     .exerciseAndGlucoseCompetitionStress:
                    NSLocalizedString("Exercise and Your Glucose Levels", comment: "")
                case .preventingLows:
                    NSLocalizedString("Preventing Lows", comment: "")
                case .unplannedActivity:
                    NSLocalizedString("Unplanned Activity", comment: "")
                }
            case .trainingComplete:
                NSLocalizedString("Training Complete", comment: "")
            }
        }
        
        public func previous(startingFrom: Chapter) -> Step? {
            switch self {
            case .customizingPresets(let customizingPresets):
                switch customizingPresets {
                case .customizingPresets: nil
                case .overallInsulin: .customizingPresets(.customizingPresets)
                case .correctionRange: .customizingPresets(.overallInsulin)
                }
            case .illness(let illness):
                switch illness {
                case .commonUses: chapter != startingFrom ? nil : .customizingPresets(.correctionRange)
                case .presetsForIllness: .illness(.commonUses)
                case .overallInsulin: .illness(.presetsForIllness)
                case .correctionRange: .illness(.overallInsulin)
                case .duration: .illness(.correctionRange)
                case .impactOnBolusing: .illness(.duration)
                }
            case .dailyActivities(let dailyActivities):
                switch dailyActivities {
                case .commonUses: chapter != startingFrom ? nil : .illness(.impactOnBolusing)
                case .presetsForDailyActivities: .dailyActivities(.commonUses)
                case .overallInsulin: .dailyActivities(.presetsForDailyActivities)
                case .correctionRange: .dailyActivities(.overallInsulin)
                case .savedPresets: .dailyActivities(.correctionRange)
                }
            case .exercise(let exercise):
                switch exercise {
                case .commonUses: chapter != startingFrom ? nil : .dailyActivities(.savedPresets)
                case .presetsForExercise: .exercise(.commonUses)
                case .perceivedIntensity: .exercise(.presetsForExercise)
                case .lightToModerateExercise: .exercise(.perceivedIntensity)
                case .highIntensityExercise: .exercise(.lightToModerateExercise)
                case .mixedIntensityExercise: .exercise(.highIntensityExercise)
                case .exerciseAndGlucoseActiveInsulin: .exercise(.mixedIntensityExercise)
                case .exerciseAndGlucoseTimeOfDay: .exercise(.exerciseAndGlucoseActiveInsulin)
                case .exerciseAndGlucoseMealTiming: .exercise(.exerciseAndGlucoseTimeOfDay)
                case .exerciseAndGlucoseCompetitionStress: .exercise(.exerciseAndGlucoseMealTiming)
                case .preventingLows: .exercise(.exerciseAndGlucoseCompetitionStress)
                case .unplannedActivity: .exercise(.preventingLows)
                }
            case .trainingComplete: chapter != startingFrom ? nil : .exercise(.unplannedActivity)
            }
        }
        
        public func next() -> (Step?, completedChapter: Chapter?) {
            switch self {
            case .customizingPresets(let customizingPresets):
                switch customizingPresets {
                case .customizingPresets: (.customizingPresets(.overallInsulin), nil)
                case .overallInsulin: (.customizingPresets(.correctionRange), nil)
                case .correctionRange: (.illness(.commonUses), .customizingPresets)
                }
            case .illness(let illness):
                switch illness {
                case .commonUses: (.illness(.presetsForIllness), nil)
                case .presetsForIllness: (.illness(.overallInsulin), nil)
                case .overallInsulin: (.illness(.correctionRange), nil)
                case .correctionRange: (.illness(.duration), nil)
                case .duration: (.illness(.impactOnBolusing), nil)
                case .impactOnBolusing: (.dailyActivities(.commonUses), .illness)
                }
            case .dailyActivities(let dailyActivities):
                switch dailyActivities {
                case .commonUses: (.dailyActivities(.presetsForDailyActivities), nil)
                case .presetsForDailyActivities: (.dailyActivities(.overallInsulin), nil)
                case .overallInsulin: (.dailyActivities(.correctionRange), nil)
                case .correctionRange: (.dailyActivities(.savedPresets), nil)
                case .savedPresets: (.exercise(.commonUses), .dailyActivities)
                }
            case .exercise(let exercise):
                switch exercise {
                case .commonUses: (.exercise(.presetsForExercise), nil)
                case .presetsForExercise: (.exercise(.perceivedIntensity), nil)
                case .perceivedIntensity: (.exercise(.lightToModerateExercise), nil)
                case .lightToModerateExercise: (.exercise(.highIntensityExercise), nil)
                case .highIntensityExercise: (.exercise(.mixedIntensityExercise), nil)
                case .mixedIntensityExercise: (.exercise(.exerciseAndGlucoseActiveInsulin), nil)
                case .exerciseAndGlucoseActiveInsulin: (.exercise(.exerciseAndGlucoseTimeOfDay), nil)
                case .exerciseAndGlucoseTimeOfDay: (.exercise(.exerciseAndGlucoseMealTiming), nil)
                case .exerciseAndGlucoseMealTiming: (.exercise(.exerciseAndGlucoseCompetitionStress), nil)
                case .exerciseAndGlucoseCompetitionStress: (.exercise(.preventingLows), nil)
                case .preventingLows: (.exercise(.unplannedActivity), nil)
                case .unplannedActivity: (.trainingComplete, .exercise)
                }
            case .trainingComplete: (nil, .trainingComplete)
            }
        }
        
        public var chapter: Chapter {
            switch self {
            case .customizingPresets: .customizingPresets
            case .illness: .illness
            case .dailyActivities: .dailyActivities
            case .exercise: .exercise
            case .trainingComplete: .trainingComplete
            }
        }
        
        public var contentBackground: Color {
            switch self {
            case .dailyActivities(.commonUses),
                 .exercise(.commonUses),
                 .illness(.commonUses):
                Color(UIColor.secondarySystemBackground)
            default:
                Color(UIColor.systemBackground)
            }
        }
    }

    public var navigationPath: [Step]
    
    public var currentStep: Step {
        navigationPath.last ?? startingAt.firstStep
    }
    
    public private(set) var startingAt: Chapter = .customizingPresets
    
    public enum TrainingCompletionConfiguration {
        case trainingCompletion(PresetsTrainingCompletion)
        case new(allowDebugFeatures: Bool)
        
        var value: PresetsTrainingCompletion {
            switch self {
            case .trainingCompletion(let presetsTrainingCompletion):
                return presetsTrainingCompletion
            case .new(let allowDebugFeatures):
                return PresetsTrainingCompletion(allowDebugFeatures: allowDebugFeatures)
            }
        }
    }
    
    public let trainingCompletion: PresetsTrainingCompletion
    
    public init(
        navigationPath: [Step] = [],
        startingAt: Chapter? = nil,
        trainingCompletionConfiguration: TrainingCompletionConfiguration
    ) {
        self.navigationPath = navigationPath
        self.trainingCompletion = trainingCompletionConfiguration.value
        
        if let startingAt {
            self.startingAt = startingAt
        } else {
            var startingAt: Chapter?
            
            Chapter.allCases.reversed().forEach { chapter in
                if trainingCompletion.completedChapters[chapter] != true {
                    startingAt = chapter
                }
            }
            
            if let startingAt {
                self.startingAt = startingAt
            } else {
                self.startingAt = .customizingPresets
            }
        }
    }
    
    public func next() {
        let (next, completedChapter) = currentStep.next()
        if let next {
            navigationPath.append(next)
        }
        
        if let completedChapter, trainingCompletion.completedChapters[completedChapter] != true {
            trainingCompletion.completedChapters[completedChapter] = true
        }
    }
}

extension Dictionary: @retroactive RawRepresentable where Key == PresetsTraining.Chapter, Value == Bool {
    public init?(rawValue: String) {
        guard
            let data = rawValue.data(using: .utf8),
            let result = try? JSONDecoder().decode([Key: Value].self, from: data)
        else {
            return nil
        }
        
        self = result
    }

    public var rawValue: String {
        guard
            let data = try? JSONEncoder().encode(self),
            let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        
        return result
    }
    
    public static var `default`: Self = PresetsTraining.Chapter.allCases
        .reduce([:]) { partialResult, chapter in
            var partial = partialResult
            partial[chapter] = false
            return partial
        }
}
