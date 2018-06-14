//
//  InsulinDeliveryStore.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit

enum InsulinDeliveryStoreResult<T> {
    case success(T)
    case failure(Error)
}


/// Manages insulin dose data from HealthKit
///
/// Scheduled doses (e.g. a bolus or temporary basal) shouldn't be written to HealthKit until they've
/// been delivered into the patient, which means its common for the HealthKit data to slightly lag
/// behind the dose data used for algorithmic calculation.
///
/// HealthKit data isn't a substitute for an insulin pump's diagnostic event history, but doses fetched
/// from HealthKit can reduce the amount of repeated communication with an insulin pump.
public class InsulinDeliveryStore: HealthKitSampleStore {
    private let insulinType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!

    private let dataAccessQueue = DispatchQueue(label: "com.loopkit.InsulinKit.InsulinDeliveryStoreQueue", qos: .utility)

    private enum LoadableDate {
        case none
        case loading
        case some(Date)
    }

    /// The most-recent end date for a basal sample written by LoopKit
    /// Should only be accessed on dataAccessQueue
    private var lastBasalEndDate: LoadableDate = .none

    public init(healthStore: HKHealthStore, effectDuration: TimeInterval, observationEnabled: Bool) {
        super.init(healthStore: healthStore, type: insulinType, observationStart: Date(timeIntervalSinceNow: -effectDuration), observationEnabled: observationEnabled)
    }

    public override func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], error: Error?) {
        // New data not written by LoopKit (see `MetadataKeyHasLoopKitOrigin`) should be assumed external to what could be fetched as PumpEvent data.
        // That external data could be factored into dose computation with some modification:
        // An example might be supplemental injections in cases of extended exercise periods without a pump
    }

    public override var preferredUnit: HKUnit! {
        return super.preferredUnit
    }
}


// MARK: - Adding data
extension InsulinDeliveryStore {
    func addReconciledDoses(_ doses: [DoseEntry], from device: HKDevice?, completion: @escaping (_ result: InsulinDeliveryStoreResult<Bool>) -> Void) {
        var latestBasalEndDate: Date?
        let unit = HKUnit.internationalUnit()
        let samples = doses.compactMap { (dose) -> HKQuantitySample? in
            let sample = HKQuantitySample(
                type: insulinType,
                unit: unit,
                dose: dose,
                device: device
            )

            if case .basal? = sample?.insulinDeliveryReason, let endDate = sample?.endDate {
                latestBasalEndDate = max(endDate, latestBasalEndDate ?? .distantPast)
            }

            return sample
        }

        guard samples.count > 0 else {
            completion(.success(true))
            return
        }

        healthStore.save(samples) { (success, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                self.dataAccessQueue.async {
                    if let latestBasalEndDate = latestBasalEndDate {
                        self.setLastBasalEndDate(latestBasalEndDate)
                    }
                    completion(.success(true))
                }
            }
        }
    }
}


// MARK: - lastBasalEndDate management
extension InsulinDeliveryStore {
    /// Returns the end date of the most recent basal sample
    ///
    /// - Parameter completion: A closure to execute when
    func getLastBasalEndDate(_ completion: @escaping (_ result: InsulinDeliveryStoreResult<Date>) -> Void) {
        dataAccessQueue.async {
            switch self.lastBasalEndDate {
            case .none:
                self.lastBasalEndDate = .loading
                self.getLastBasalEndDateFromHealthKit { (result) in
                    self.dataAccessQueue.async {
                        switch result {
                        case .failure:
                            self.lastBasalEndDate = .none
                        case .success(let date):
                            self.lastBasalEndDate = .some(date)
                        }

                        completion(result)
                    }
                }
            case .some(let date):
                completion(.success(date))
            case .loading:
                // TODO: send a proper error
                completion(.failure(DoseStore.DoseStoreError.configurationError))
            }
        }
    }

    fileprivate func setLastBasalEndDate(_ endDate: Date) {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        switch lastBasalEndDate {
        case .none, .loading:
            lastBasalEndDate = .some(endDate)
        case .some(let date):
            lastBasalEndDate = .some(max(date, endDate))
        }
    }

    private func getLastBasalEndDateFromHealthKit(_ completion: @escaping (_ result: InsulinDeliveryStoreResult<Date>) -> Void) {
        let basalPredicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyInsulinDeliveryReason, operatorType: .equalTo, value: HKInsulinDeliveryReason.basal.rawValue)
        let sourcePredicate = HKQuery.predicateForObjects(withMetadataKey: MetadataKeyHasLoopKitOrigin, operatorType: .equalTo, value: true)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [basalPredicate, sourcePredicate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: insulinType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { (query, samples, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                let date = samples?.first?.endDate ?? self.healthStore.earliestPermittedSampleDate()

                completion(.success(date))
            }
        }

        healthStore.execute(query)
    }
}


extension InsulinDeliveryStore {
    private func getDoses(since start: Date, _ completion: @escaping (_ result: InsulinDeliveryStoreResult<[DoseEntry]>) -> Void) {
        getSamples(since: start) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let samples):
                completion(.success(samples.compactMap { $0.dose }))
            }
        }
    }

    private func getSamples(since start: Date, _ completion: @escaping (_ result: InsulinDeliveryStoreResult<[HKQuantitySample]>) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: [])
        getSamples(matching: predicate, chronological: true, completion)
    }

    private func getSamples(matching predicate: NSPredicate, chronological: Bool, _ completion: @escaping (_ result: InsulinDeliveryStoreResult<[HKQuantitySample]>) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: chronological)
        let query = HKSampleQuery(sampleType: insulinType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { (query, samples, error) in
            if let error = error {
                completion(.failure(error))
            } else if let samples = samples as? [HKQuantitySample] {
                completion(.success(samples))
            } else {
                assertionFailure("Unknown return configuration from query \(query)")
            }
        }

        healthStore.execute(query)
    }
}


extension InsulinDeliveryStore {
    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completion: The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completion: @escaping (_ report: String) -> Void) {
        getLastBasalEndDate { (result) in
            var report: [String] = [
                "### InsulinDeliveryStore",
                super.debugDescription,
                ""
            ]

            switch result {
            case .success(let lastBasalEndDate):
                report.append("* lastBasalEndDate: \(lastBasalEndDate)")
            case .failure(let error):
                report.append("* error: \(String(reflecting: error))")
            }
            report.append("")
            completion(report.joined(separator: "\n"))
        }
    }
}
