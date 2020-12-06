//
//  MockGlucoseProvider.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit


/// Returns a value based on the result of a random coin flip.
/// - Parameter chanceOfHeads: The chance of flipping heads. Must be a value in the range `0...1`. Defaults to `0.5`.
/// - Parameter valueIfHeads: An autoclosure producing the value to return if the coin flips heads.
/// - Parameter valueIfTails: An autoclosure producing the value to return if the coin flips tails.
private func coinFlip<Output>(
    withChanceOfHeads chanceOfHeads: Double = 0.5,
    ifHeads valueIfHeads: @autoclosure () -> Output,
    ifTails valueIfTails: @autoclosure () -> Output
) -> Output {
    precondition((0...1).contains(chanceOfHeads))
    let isHeads = .random(in: 0..<100) < chanceOfHeads * 100
    return isHeads ? valueIfHeads() : valueIfTails()
}


struct MockGlucoseProvider {
    struct BackfillRequest {
        let duration: TimeInterval
        let dataPointFrequency: TimeInterval

        var dataPointCount: Int {
            return Int(duration / dataPointFrequency)
        }

        init(datingBack duration: TimeInterval, dataPointFrequency: TimeInterval) {
            self.duration = duration
            self.dataPointFrequency = dataPointFrequency
        }
    }

    /// Given a date, asynchronously produce the CGMReadingResult at that date.
    private let fetchDataAt: (_ date: Date, _ completion: @escaping (CGMReadingResult) -> Void) -> Void

    func fetchData(at date: Date, completion: @escaping (CGMReadingResult) -> Void) {
        fetchDataAt(date, completion)
    }

    func backfill(_ backfill: BackfillRequest, endingAt date: Date, completion: @escaping (CGMReadingResult) -> Void) {
        let dataPointDates = (0...backfill.dataPointCount).map { offset in
            return date.addingTimeInterval(-backfill.dataPointFrequency * Double(offset))
        }
        dataPointDates.asyncMap(fetchDataAt) { allResults in
            let allSamples = allResults.flatMap { result -> [NewGlucoseSample] in
                if case .newData(let samples) = result {
                    return samples
                } else {
                    return []
                }
            }
            let result: CGMReadingResult = allSamples.isEmpty ? .noData : .newData(allSamples)
            completion(result)
        }
    }
}

extension MockGlucoseProvider {
    init(model: MockCGMDataSource.Model, effects: MockCGMDataSource.Effects) {
        self = effects.transformations.reduce(model.glucoseProvider) { model, transform in transform(model) }
    }

    private static func glucoseSample(at date: Date, quantity: HKQuantity) -> NewGlucoseSample {
        return NewGlucoseSample(
            date: date,
            quantity: quantity,
            isDisplayOnly: false,
            wasUserEntered: false,
            syncIdentifier: UUID().uuidString,
            device: MockCGMDataSource.device
        )
    }
}

// MARK: - Models

extension MockGlucoseProvider {
    fileprivate static func constant(_ quantity: HKQuantity) -> MockGlucoseProvider {
        return MockGlucoseProvider { date, completion in
            let sample = glucoseSample(at: date, quantity: quantity)
            completion(.newData([sample]))
        }
    }

    fileprivate static func sineCurve(parameters: MockCGMDataSource.Model.SineCurveParameters) -> MockGlucoseProvider {
        let (baseGlucose, amplitude, period, referenceDate) = parameters
        precondition(period > 0)
        let unit = HKUnit.milligramsPerDeciliter
        precondition(baseGlucose.is(compatibleWith: unit))
        precondition(amplitude.is(compatibleWith: unit))
        let baseGlucoseValue = baseGlucose.doubleValue(for: unit)
        let amplitudeValue = amplitude.doubleValue(for: unit)

        return MockGlucoseProvider { date, completion in
            let timeOffset = date.timeIntervalSince1970 - referenceDate.timeIntervalSince1970
            let glucoseValue = baseGlucoseValue + amplitudeValue * sin(2 * .pi / period * timeOffset)
            let sample = glucoseSample(at: date, quantity: HKQuantity(unit: unit, doubleValue: glucoseValue))
            completion(.newData([sample]))
        }
    }

    fileprivate static var noData: MockGlucoseProvider {
        return MockGlucoseProvider { _, completion in completion(.noData) }
    }

    fileprivate static func error(_ error: Error) -> MockGlucoseProvider {
        return MockGlucoseProvider { _, completion in completion(.error(error)) }
    }
}

// MARK: - Effects

private struct MockGlucoseProviderError: Error { }

extension MockGlucoseProvider {
    fileprivate func withRandomNoise(upTo magnitude: HKQuantity) -> MockGlucoseProvider {
        let unit = HKUnit.milligramsPerDeciliter
        precondition(magnitude.is(compatibleWith: unit))
        let magnitude = magnitude.doubleValue(for: unit)

        return mapGlucoseQuantities { glucose in
            let glucoseValue = glucose.doubleValue(for: unit) + .random(in: -magnitude...magnitude)
            return HKQuantity(unit: unit, doubleValue: glucoseValue)
        }
    }

    fileprivate func randomlyProducingLowOutlier(withChance chanceOfOutlier: Double, outlierDelta: HKQuantity) -> MockGlucoseProvider {
        return randomlyProducingOutlier(withChance: chanceOfOutlier, outlierDeltaMagnitude: outlierDelta, outlierDeltaSign: -)
    }

    fileprivate func randomlyProducingHighOutlier(withChance chanceOfOutlier: Double, outlierDelta: HKQuantity) -> MockGlucoseProvider {
        return randomlyProducingOutlier(withChance: chanceOfOutlier, outlierDeltaMagnitude: outlierDelta, outlierDeltaSign: +)
    }

    private func randomlyProducingOutlier(
        withChance chanceOfOutlier: Double,
        outlierDeltaMagnitude: HKQuantity,
        outlierDeltaSign: (Double) -> Double
    ) -> MockGlucoseProvider {
        let unit = HKUnit.milligramsPerDeciliter
        precondition(outlierDeltaMagnitude.is(compatibleWith: unit))
        let outlierDelta = outlierDeltaSign(outlierDeltaMagnitude.doubleValue(for: unit))
        return mapGlucoseQuantities { glucose in
            return coinFlip(
                withChanceOfHeads: chanceOfOutlier,
                ifHeads: HKQuantity(unit: unit, doubleValue: glucose.doubleValue(for: unit) + outlierDelta),
                ifTails: glucose
            )
        }
    }

    fileprivate func randomlyErroringOnNewData(withChance chance: Double) -> MockGlucoseProvider {
        return mapResult { result in
            return coinFlip(withChanceOfHeads: chance, ifHeads: .error(MockGlucoseProviderError()), ifTails: result)
        }
    }

    private func mapResult(_ transform: @escaping (CGMReadingResult) -> CGMReadingResult) -> MockGlucoseProvider {
        return MockGlucoseProvider { date, completion in
            self.fetchData(at: date) { result in
                completion(transform(result))
            }
        }
    }

    private func mapGlucoseQuantities(_ transform: @escaping (HKQuantity) -> HKQuantity) -> MockGlucoseProvider {
        return mapResult { result in
            return result.mapGlucoseQuantities(transform)
        }
    }
}

private extension CGMReadingResult {
    func mapGlucoseQuantities(_ transform: (HKQuantity) -> HKQuantity) -> CGMReadingResult {
        guard case .newData(let samples) = self else {
            return self
        }
        return .newData(
            samples.map { sample in
                return NewGlucoseSample(
                    date: sample.date,
                    quantity: transform(sample.quantity),
                    isDisplayOnly: sample.isDisplayOnly,
                    wasUserEntered: sample.wasUserEntered,
                    syncIdentifier: sample.syncIdentifier,
                    syncVersion: sample.syncVersion,
                    device: sample.device
                )
            }
        )
    }
}

private extension MockCGMDataSource.Model {
    var glucoseProvider: MockGlucoseProvider {
        switch self {
        case .constant(let quantity):
            return .constant(quantity)
        case .sineCurve(parameters: let parameters):
            return .sineCurve(parameters: parameters)
        case .noData:
            return .noData
        case .signalLoss:
            return .noData
        }
    }
}

private extension MockCGMDataSource.Effects {
    var transformations: [(MockGlucoseProvider) -> MockGlucoseProvider] {
        // Each effect maps to a transformation on a MockGlucoseProvider
        return [
            glucoseNoise.map { maximumDeltaMagnitude in { $0.withRandomNoise(upTo: maximumDeltaMagnitude) } },
            randomLowOutlier.map { chance, delta in { $0.randomlyProducingLowOutlier(withChance: chance, outlierDelta: delta) } },
            randomHighOutlier.map { chance, delta in { $0.randomlyProducingHighOutlier(withChance: chance, outlierDelta: delta) } },
            randomErrorChance.map { chance in { $0.randomlyErroringOnNewData(withChance: chance) } }
        ].compactMap { $0 }
    }
}
