//
//  InsulinDeliveryStore.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit

enum InsulinDeliveryStoreResult<T> {
    case success(T)
    case failure(Error)
}

@available(iOS 11.0, *)
public class InsulinDeliveryStore: HealthKitSampleStore {
    fileprivate let insulinType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!

    fileprivate let dataAccessQueue = DispatchQueue(label: "com.loopkit.InsulinKit.InsulinDeliveryStoreQueue")

    fileprivate enum LoadableDate {
        case none
        case loading
        case some(Date)
    }
    // Should only be accessed on dataAccessQueue
    fileprivate var lastBasalEndDate: LoadableDate = .none

    public override var shareTypes: Set<HKSampleType> {
        return Set(arrayLiteral: insulinType)
    }

    func addReconciledDoses(_ doses: [DoseEntry], from device: HKDevice?, completion: @escaping (_ result: InsulinDeliveryStoreResult<Bool>) -> Void) {
        var latestBasalEndDate: Date?
        let unit = HKUnit.internationalUnit()
        let samples = doses.flatMap { (dose) -> HKQuantitySample? in
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
@available(iOS 11.0, *)
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
        let predicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyInsulinDeliveryReason, operatorType: .equalTo, value: HKInsulinDeliveryReason.basal.rawValue)
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


@available(iOS 11.0, *)
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
