//
//  MasterViewController.swift
//  LoopKit Example
//
//  Created by Nathan Racklyeft on 2/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import HealthKit


class MasterViewController: UITableViewController {

    private var dataManager: DeviceDataManager? = DeviceDataManager()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let dataManager = dataManager else {
            return
        }

        let sampleTypes = Set([
            dataManager.glucoseStore.sampleType,
            dataManager.carbStore.sampleType,
            dataManager.doseStore.sampleType,
        ].compactMap { $0 })

        if dataManager.glucoseStore.authorizationRequired ||
            dataManager.carbStore.authorizationRequired ||
            dataManager.doseStore.authorizationRequired
        {
            dataManager.carbStore.healthStore.requestAuthorization(toShare: sampleTypes, read: sampleTypes) { (success, error) in
                if success {
                    // Call the individual authorization methods to trigger query creation
                    dataManager.carbStore.authorize({ _ in })
                    dataManager.doseStore.insulinDeliveryStore.authorize(toShare: true, { _ in })
                    dataManager.glucoseStore.authorize({ _ in })
                }
            }
        }
    }

    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        case data
        case configuration
    }

    private enum DataRow: Int, CaseIterable {
        case carbs = 0
        case reservoir
        case diagnostic
        case generate
        case reset
    }

    private enum ConfigurationRow: Int, CaseIterable {
        case basalRate
        case carbRatio
        case correctionRange
        case insulinSensitivity
        case pumpID
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .configuration:
            return ConfigurationRow.allCases.count
        case .data:
            return DataRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .configuration:
            switch ConfigurationRow(rawValue: indexPath.row)! {
            case .basalRate:
                cell.textLabel?.text = LocalizedString("Basal Rates", comment: "The title text for the basal rate schedule")
            case .carbRatio:
                cell.textLabel?.text = LocalizedString("Carb Ratios", comment: "The title of the carb ratios schedule screen")
            case .correctionRange:
                cell.textLabel?.text = LocalizedString("Correction Range", comment: "The title text for the glucose correction range schedule")
            case .insulinSensitivity:
                cell.textLabel?.text = LocalizedString("Insulin Sensitivity", comment: "The title text for the insulin sensitivity schedule")
            case .pumpID:
                cell.textLabel?.text = LocalizedString("Pump ID", comment: "The title text for the pump ID")
            }
        case .data:
            switch DataRow(rawValue: indexPath.row)! {
            case .carbs:
                cell.textLabel?.text = LocalizedString("Carbs", comment: "The title for the cell navigating to the carbs screen")
            case .reservoir:
                cell.textLabel?.text = LocalizedString("Reservoir", comment: "The title for the cell navigating to the reservoir screen")
            case .diagnostic:
                cell.textLabel?.text = LocalizedString("Diagnostic", comment: "The title for the cell displaying diagnostic data")
            case .generate:
                cell.textLabel?.text = LocalizedString("Generate Data", comment: "The title for the cell displaying data generation")
            case .reset:
                cell.textLabel?.text = LocalizedString("Reset", comment: "Title for the cell resetting the data manager")
            }
        }

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sender = tableView.cellForRow(at: indexPath)

        switch Section(rawValue: indexPath.section)! {
        case .configuration:
            let row = ConfigurationRow(rawValue: indexPath.row)!
            switch row {
//            case .basalRate:
//
//                // x22 with max basal rate of 5U/hr
//                let pulsesPerUnit = 20
//                let basalRates = (1...100).map { Double($0) / Double(pulsesPerUnit) }
//
//                // full x23 rates
//                let rateGroup1 = ((1...39).map { Double($0) / Double(40) })
//                let rateGroup2 = ((20...199).map { Double($0) / Double(20) })
//                let rateGroup3 = ((100...350).map { Double($0) / Double(10) })
//                let basalRates = rateGroup1 + rateGroup2 + rateGroup3

//                let scheduleVC = BasalScheduleTableViewController(allowedBasalRates: basalRates, maximumScheduleItemCount: 5, minimumTimeInterval: .minutes(30))
//
//                if let profile = dataManager?.basalRateSchedule {
//                    scheduleVC.timeZone = profile.timeZone
//
//
//                    scheduleVC.scheduleItems = profile.items
//                }
//                scheduleVC.delegate = self
//                scheduleVC.title = sender?.textLabel?.text
//                scheduleVC.syncSource = self
//
//                show(scheduleVC, sender: sender)
            case .carbRatio:
                let scheduleVC = DailyQuantityScheduleTableViewController()

                scheduleVC.delegate = self
                scheduleVC.title = NSLocalizedString("Carb Ratios", comment: "The title of the carb ratios schedule screen")
                scheduleVC.unit = .gram()

                if let schedule = dataManager?.carbRatioSchedule {
                    scheduleVC.timeZone = schedule.timeZone
                    scheduleVC.scheduleItems = schedule.items
                    scheduleVC.unit = schedule.unit
                }

                show(scheduleVC, sender: sender)
            case .correctionRange:
                var therapySettings = TherapySettings()
                therapySettings.glucoseTargetRangeSchedule = self.dataManager?.glucoseTargetRangeSchedule
                let therapySettingsViewModel = TherapySettingsViewModel(therapySettings: therapySettings)
                
                let view = CorrectionRangeScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: {
                    self.dataManager?.glucoseTargetRangeSchedule = therapySettingsViewModel.therapySettings.glucoseTargetRangeSchedule
                    self.navigationController?.popToViewController(self, animated: true)
                })
                    .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter))

                let scheduleVC = DismissibleHostingController(rootView: view, dismissalMode: .pop(to:  type(of: self)), isModalInPresentation: false)
                show(scheduleVC, sender: sender)
            case .insulinSensitivity:
                let unit = dataManager?.insulinSensitivitySchedule?.unit ?? dataManager?.glucoseStore.preferredUnit ?? HKUnit.milligramsPerDeciliter
                let scheduleVC = InsulinSensitivityScheduleViewController(allowedValues: unit.allowedSensitivityValues, unit: unit)

                scheduleVC.unit = unit
                scheduleVC.delegate = self
                scheduleVC.insulinSensitivityScheduleStorageDelegate = self
                scheduleVC.schedule = dataManager?.insulinSensitivitySchedule
                scheduleVC.title = NSLocalizedString("Insulin Sensitivity", comment: "The title of the insulin sensitivity schedule screen")
                show(scheduleVC, sender: sender)

            case .pumpID:
                let textFieldVC = TextFieldTableViewController()

//                textFieldVC.delegate = self
                textFieldVC.title = sender?.textLabel?.text
                textFieldVC.placeholder = LocalizedString("Enter the 6-digit pump ID", comment: "The placeholder text instructing users how to enter a pump ID")
                textFieldVC.value = dataManager?.pumpID
                textFieldVC.keyboardType = .numberPad
                textFieldVC.contextHelp = LocalizedString("The pump ID can be found printed on the back, or near the bottom of the STATUS/Esc screen. It is the strictly numerical portion of the serial number (shown as SN or S/N).", comment: "Instructions on where to find the pump ID on a Minimed pump")

                show(textFieldVC, sender: sender)
            default:
                break
            }
        case .data:
            switch DataRow(rawValue: indexPath.row)! {
            case .carbs:
                performSegue(withIdentifier: CarbEntryTableViewController.className, sender: sender)
            case .reservoir:
                performSegue(withIdentifier: LegacyInsulinDeliveryTableViewController.className, sender: sender)
            case .diagnostic:
                let vc = CommandResponseViewController(command: { [weak self] (completionHandler) -> String in
                    let group = DispatchGroup()

                    guard let dataManager = self?.dataManager else {
                        completionHandler("")
                        return "nil"
                    }

                    var doseStoreResponse = ""
                    group.enter()
                    dataManager.doseStore.generateDiagnosticReport { (report) in
                        doseStoreResponse = report
                        group.leave()
                    }

                    var carbStoreResponse = ""
                    if let carbStore = dataManager.carbStore {
                        group.enter()
                        carbStore.generateDiagnosticReport { (report) in
                            carbStoreResponse = report
                            group.leave()
                        }
                    }

                    var glucoseStoreResponse = ""
                    group.enter()
                    dataManager.glucoseStore.generateDiagnosticReport { (report) in
                        glucoseStoreResponse = report
                        group.leave()
                    }

                    group.notify(queue: DispatchQueue.main) {
                        completionHandler([
                            doseStoreResponse,
                            carbStoreResponse,
                            glucoseStoreResponse
                        ].joined(separator: "\n\n"))
                    }

                    return "…"
                })
                vc.title = "Diagnostic"

                show(vc, sender: sender)
            case .generate:
                let vc = CommandResponseViewController(command: { [weak self] (completionHandler) -> String in
                    guard let dataManager = self?.dataManager else {
                        completionHandler("")
                        return "dataManager is nil"
                    }

                    let group = DispatchGroup()

                    var unitVolume = 150.0

                    reservoir: for index in sequence(first: TimeInterval(hours: -6), next: { $0 + .minutes(5) }) {
                        guard index < 0 else {
                            break reservoir
                        }

                        unitVolume -= (drand48() * 2.0)

                        group.enter()
                        dataManager.doseStore.addReservoirValue(unitVolume, at: Date(timeIntervalSinceNow: index)) { (_, _, _, error) in
                            group.leave()
                        }
                    }

                    group.enter()
                    dataManager.glucoseStore.addGlucoseSamples([NewGlucoseSample(date: Date(), quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 101), condition: nil, trend: nil, trendRate: nil, isDisplayOnly: false, wasUserEntered: false, syncIdentifier: UUID().uuidString)], completion: { (result) in
                        group.leave()
                    })

                    group.notify(queue: .main) {
                        completionHandler("Completed")
                    }

                    return "Generating…"
                })
                vc.title = sender?.textLabel?.text

                show(vc, sender: sender)
            case .reset:
                dataManager = nil
                tableView.reloadData()
            }
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        var targetViewController = segue.destination

        if let navVC = targetViewController as? UINavigationController, let topViewController = navVC.topViewController {
            targetViewController = topViewController
        }

        switch targetViewController {
        case let vc as CarbEntryTableViewController:
            vc.carbStore = dataManager?.carbStore
        case let vc as CarbEntryEditViewController:
            if let carbStore = dataManager?.carbStore {
                vc.defaultAbsorptionTimes = carbStore.defaultAbsorptionTimes
                vc.preferredUnit = carbStore.preferredUnit
            }
        case let vc as LegacyInsulinDeliveryTableViewController:
            vc.doseStore = dataManager?.doseStore
        default:
            break
        }
    }
}


extension MasterViewController: DailyValueScheduleTableViewControllerDelegate {
    func dailyValueScheduleTableViewControllerWillFinishUpdating(_ controller: DailyValueScheduleTableViewController) {
        if let indexPath = tableView.indexPathForSelectedRow {
            switch Section(rawValue: indexPath.section)! {
            case .configuration:
                switch ConfigurationRow(rawValue: indexPath.row)! {
//                case .basalRate:
//                    if let controller = controller as? BasalScheduleTableViewController {
//                        dataManager?.basalRateSchedule = BasalRateSchedule(dailyItems: controller.scheduleItems, timeZone: controller.timeZone)
//                    }
                default:
                    break
                }

                tableView.reloadRows(at: [indexPath], with: .none)
            default:
                break
            }
        }
    }
}


extension MasterViewController: InsulinSensitivityScheduleStorageDelegate {
    func saveSchedule(_ schedule: InsulinSensitivitySchedule, for viewController: InsulinSensitivityScheduleViewController, completion: @escaping (SaveInsulinSensitivityScheduleResult) -> Void) {
        self.dataManager?.insulinSensitivitySchedule = schedule
        completion(.success)
    }
}

private extension HKUnit {
    var allowedSensitivityValues: [Double] {
        if self == HKUnit.milligramsPerDeciliter {
            return (10...500).map { Double($0) }
        }

        if self == HKUnit.millimolesPerLiter {
            return (6...270).map { Double($0) / 10.0 }
        }

        return []
    }

    var allowedCorrectionRangeValues: [Double] {
        if self == HKUnit.milligramsPerDeciliter {
            return (60...180).map { Double($0) }
        }

        if self == HKUnit.millimolesPerLiter {
            return (33...100).map { Double($0) / 10.0 }
        }

        return []
    }
}
