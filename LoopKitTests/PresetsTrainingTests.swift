//
//  PresetsTrainingTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

final class PresetsTrainingTests: XCTestCase {

    private let completedChaptersKey = "completedPresetTrainingChapters"
    private var savedCompletedChapters: Any?

    override func setUp() {
        savedCompletedChapters = UserDefaults.standard.object(forKey: completedChaptersKey)
        UserDefaults.standard.removeObject(forKey: completedChaptersKey)
    }

    override func tearDown() {
        UserDefaults.standard.set(savedCompletedChapters, forKey: completedChaptersKey)
    }

    private func complete(_ chapters: [PresetsTraining.Chapter], in completion: PresetsTrainingCompletion) {
        for chapter in chapters {
            completion.completedChapters[chapter] = true
        }
    }

    func testExerciseIsRequiredByDefault() {
        let completion = PresetsTrainingCompletion(allowDebugFeatures: false)
        complete([.customizingPresets, .illness, .dailyActivities, .trainingComplete], in: completion)

        XCTAssertFalse(completion.isComplete)
        XCTAssertEqual(PresetsTraining(trainingCompletionConfiguration: .trainingCompletion(completion)).startingAt, .exercise)
    }

    func testOptionalExerciseCompletesWithoutIt() {
        let completion = PresetsTrainingCompletion(allowDebugFeatures: false, exerciseRequired: false)
        complete([.customizingPresets, .illness, .dailyActivities], in: completion)

        XCTAssertFalse(completion.isComplete)
        XCTAssertEqual(PresetsTraining(trainingCompletionConfiguration: .trainingCompletion(completion)).startingAt, .trainingComplete)

        complete([.trainingComplete], in: completion)
        XCTAssertTrue(completion.isComplete)
        XCTAssertEqual(PresetsTraining(trainingCompletionConfiguration: .trainingCompletion(completion)).startingAt, .exercise, "the unread optional chapter is where the Learning Hub opens")
    }

    func testOptionalExerciseSkipsFromDailyActivitiesToTheEnd() {
        let completion = PresetsTrainingCompletion(allowDebugFeatures: false, exerciseRequired: false)
        let training = PresetsTraining(navigationPath: [.dailyActivities(.savedPresets)], trainingCompletionConfiguration: .trainingCompletion(completion))

        training.next()

        XCTAssertEqual(training.currentStep, .trainingComplete)
        XCTAssertEqual(completion.completedChapters[.dailyActivities], true)
    }

    func testRequiredExerciseFollowsDailyActivities() {
        let completion = PresetsTrainingCompletion(allowDebugFeatures: false)
        let training = PresetsTraining(navigationPath: [.dailyActivities(.savedPresets)], trainingCompletionConfiguration: .trainingCompletion(completion))

        training.next()

        XCTAssertEqual(training.currentStep, .exercise(.commonUses))
    }

    func testRequiringExerciseAgainReopensTraining() {
        let completion = PresetsTrainingCompletion(allowDebugFeatures: false, exerciseRequired: false)
        complete([.customizingPresets, .illness, .dailyActivities, .trainingComplete], in: completion)
        XCTAssertTrue(completion.isComplete)

        completion.exerciseRequired = true

        XCTAssertFalse(completion.isComplete)
    }
}
