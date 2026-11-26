//
//  ExerciseStore.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import os.log

public final class ExerciseStore {
    // HKQueryAnchor is immutable.
    public struct QueryAnchor: Equatable, RawRepresentable, @unchecked Sendable {
        public typealias RawValue = [String: Any]

        let anchor: HKQueryAnchor?

        public init() {
            self.anchor = nil
        }

        init(anchor: HKQueryAnchor?) {
            self.anchor = anchor
        }

        public init?(rawValue: RawValue) {
            guard let data = rawValue["anchor"] as? Data,
                  let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
            else {
                return nil
            }
            self.anchor = anchor
        }

        public var rawValue: RawValue {
            guard let anchor, let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else {
                return [:]
            }
            return ["anchor": data]
        }
    }

    public struct HealthSampleQueryAnchor: Equatable, RawRepresentable, Sendable {
        public typealias RawValue = [String: Any]

        public var anchors: [StoredHealthSample.Kind: QueryAnchor]

        public init() {
            self.anchors = [:]
        }

        public init?(rawValue: RawValue) {
            self.anchors = [:]
            for kind in StoredHealthSample.Kind.allCases {
                if let raw = rawValue[kind.rawValue] as? QueryAnchor.RawValue, let anchor = QueryAnchor(rawValue: raw) {
                    anchors[kind] = anchor
                }
            }
        }

        public var rawValue: RawValue {
            anchors.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value.rawValue }
        }
    }

    public static let readTypes: Set<HKObjectType> = Set([HKObjectType.workoutType()])
        .union(StoredWorkout.distanceTypes)
        .union(StoredHealthSample.Kind.allCases.map(\.quantityType))

    public let healthStore: HKHealthStoreProtocol

    private let log = OSLog(category: "ExerciseStore")

    private var observerQueries: [HKObserverQuery] = []

    public init(healthStore: HKHealthStoreProtocol) {
        self.healthStore = healthStore
    }

    public func observe(workoutsChanged: @escaping @Sendable () -> Void, samplesChanged: @escaping @Sendable () -> Void) {
        stopObserving()
        observerQueries = [observerQuery(for: .workoutType(), onChange: workoutsChanged)]
            + StoredHealthSample.Kind.allCases.map { observerQuery(for: $0.quantityType, onChange: samplesChanged) }
        observerQueries.forEach(healthStore.execute)
    }

    public func stopObserving() {
        observerQueries.forEach(healthStore.stop)
        observerQueries = []
    }

    private func observerQuery(for sampleType: HKSampleType, onChange: @escaping @Sendable () -> Void) -> HKObserverQuery {
        HKObserverQuery(sampleType: sampleType, predicate: nil) { [log] _, completion, error in
            if let error {
                log.error("Observer error for %{public}@: %{public}@", sampleType.identifier, String(describing: error))
            } else {
                onChange()
            }
            completion()
        }
    }

    public func executeWorkoutQuery(fromQueryAnchor queryAnchor: QueryAnchor, limit: Int) async throws -> (anchor: QueryAnchor, added: [StoredWorkout], deleted: [UUID]) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: .workoutType(), predicate: nil, anchor: queryAnchor.anchor, limit: limit) { _, added, deleted, anchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = (added ?? []).compactMap { $0 as? HKWorkout }.map(StoredWorkout.init)
                continuation.resume(returning: (QueryAnchor(anchor: anchor ?? queryAnchor.anchor), workouts, (deleted ?? []).map(\.uuid)))
            }
            healthStore.execute(query)
        }
    }

    public func executeSampleQuery(kind: StoredHealthSample.Kind, fromQueryAnchor queryAnchor: QueryAnchor, limit: Int) async throws -> (anchor: QueryAnchor, added: [StoredHealthSample], deleted: [UUID]) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: kind.quantityType, predicate: nil, anchor: queryAnchor.anchor, limit: limit) { _, added, deleted, anchor, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let samples = (added ?? []).compactMap { $0 as? HKQuantitySample }.map { StoredHealthSample($0, kind: kind) }
                continuation.resume(returning: (QueryAnchor(anchor: anchor ?? queryAnchor.anchor), samples, (deleted ?? []).map(\.uuid)))
            }
            healthStore.execute(query)
        }
    }
}
