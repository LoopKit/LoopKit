//
//  CarbEntryEditViewController.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//  Fat-Protein Unit code by Robert Silvers, 10/2018.

import UIKit
import HealthKit
import LoopKit

public final class CarbEntryEditViewController: UITableViewController {
    
    var navigationDelegate = CarbEntryNavigationDelegate()
    
    public var defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes? {
        didSet {
            if let times = defaultAbsorptionTimes {
                orderedAbsorptionTimes = [times.fast, times.medium, times.slow]
            }
        }
    }

    fileprivate var orderedAbsorptionTimes = [TimeInterval]()

    public var preferredUnit = HKUnit.gram()

    public var maxQuantity = HKQuantity(unit: .gram(), doubleValue: 250)
    
    public var FPCaloriesRatio: Double = 0.0
    
    public var onsetDelay: Double = 0.0

    /// Entry configuration values. Must be set before presenting.
    public var absorptionTimePickerInterval = TimeInterval(minutes: 30)

    public var maxAbsorptionTime = TimeInterval(hours: 16)

    public var maximumDateFutureInterval = TimeInterval(hours: 4)

    public var originalCarbEntry: StoredCarbEntry? {
        didSet {
            if let entry = originalCarbEntry {
                quantity = entry.quantity
                date = entry.startDate
                foodType = entry.foodType
                absorptionTime = entry.absorptionTime

                absorptionTimeWasEdited = true
                usesCustomFoodType = true
            }
        }
    }

    fileprivate var quantity: HKQuantity? 
    
    fileprivate var carbQuantity: Double? = 0.0
    
    fileprivate var fatQuantity: Double? = 0.0
    
    fileprivate var proteinQuantity: Double? = 0.0
    
    fileprivate var FPUQuantity: HKQuantity?

    fileprivate var date = Date()

    fileprivate var foodType: String?

    fileprivate var absorptionTime: TimeInterval?

    fileprivate var absorptionTimeWasEdited = false

    fileprivate var usesCustomFoodType = false
    
    public var updatedCarbEntry: NewCarbEntry? {
        if  let quantity = quantity,
            var absorptionTime = absorptionTime ?? defaultAbsorptionTimes?.medium
        {
            if let o = originalCarbEntry, o.quantity == quantity && o.startDate == date && o.foodType == foodType && o.absorptionTime == absorptionTime {
                return nil  // No changes were made
            }
            
            if ((proteinQuantity! > 0.0) || (fatQuantity! > 0.0)) { // RSS - If fat and protein were entered, then carbs are always fast.
                return NewCarbEntry(
                    quantity: quantity,
                    startDate: date,
                    foodType: foodType,
                    absorptionTime: 7200,
                    externalID: originalCarbEntry?.externalID
                )
            } else {
                return NewCarbEntry(
                    quantity: quantity,
                    startDate: date,
                    foodType: foodType,
                    absorptionTime: absorptionTime,
                    externalID: originalCarbEntry?.externalID
                )
            }
            
        
        } else {
            return nil
        }
    }
    
     public var updatedFPCarbEntry: NewCarbEntry? {
        if  let quantity = quantity,
            let absorptionTime = absorptionTime ?? defaultAbsorptionTimes?.medium
        {
            if let o = originalCarbEntry, o.quantity == quantity && o.startDate == date && o.foodType == foodType && o.absorptionTime == absorptionTime {
                if ((proteinQuantity == 0) && (fatQuantity == 0)) {
                    return nil  // No changes were made
                }
            }
            
            /// See https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2901033/
            
            let proteinCalories = proteinQuantity! * 4
            let fatCalories = fatQuantity! * 9
            var lowCarbMultiplier: Double = Double(carbQuantity!)
     
            // If carbs are 40 or more, then fat and protein are full weught.
            // If carbs are 0, then fat and protein are 50% weight.
            // If carbs are 20, then fat and protein are 75% weight.
            // This is based on medical paper data that extra insulin is
            // most important for high-carb meals.
     
            /*
            if carbQuantity! >= 40 {
                lowCarbMultiplier = 1.0
            } else {
                lowCarbMultiplier = (carbQuantity! / 80.0) + 0.5
            }
            */ // This is experimental so comment out for now pending more discussion.
            lowCarbMultiplier = 1.0
            
     
            let FPU = Double(proteinCalories + fatCalories) / Double(FPCaloriesRatio)
     
            let carbEquivilant = FPU * 10 * lowCarbMultiplier
     
                    /*The first two hours is to generalize the research-paper equation. But then add 3 more hours to the Loop absorption time to better mimic the effect of the duration of a pump square-wave (because the insulin will still have significant effect for about three hours after the square-wave ends). This does not need to be exact because individuals will tune it to their personal response using the FPU-Ratio setting. Finally, multiply by 0.6667 as the inverse of the 1.5x scaler that Loop applies to inputted durations. */
            
            var squareWaveDuration = (2.0 + FPU + 3.0) * 0.6667
     
            if squareWaveDuration > 16 { // Set some reasonable max.
                squareWaveDuration = 16
            }
            if squareWaveDuration < 4 { // Ewa told me never less than 4 hours for manual pump.
                squareWaveDuration = 4  // But since this is carb-absorption, have to add ~3. But then
                                        // Multiply by 0.667 to invert the Loop 1.5x factor. About 4.5,
                                        // but round back down to 4 (and Loop will make that 6).
            }
     
            if carbEquivilant >= 1 {
                return NewCarbEntry(
                    quantity: HKQuantity(unit: .gram(), doubleValue: carbEquivilant),
                    startDate: date + 60 * onsetDelay,
                    foodType: foodType,
                    absorptionTime: .hours(squareWaveDuration),
                    externalID: originalCarbEntry?.externalID)
            } else {
     
                return nil
            }
        } else {
            return nil
        }
    }
    
    
    private var isSampleEditable: Bool {
        return originalCarbEntry?.createdByCurrentApp != false
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.register(DateAndDurationTableViewCell.nib(), forCellReuseIdentifier: DateAndDurationTableViewCell.className)

        if originalCarbEntry != nil {
            title = LocalizedString("carb-entry-title-edit", value: "Edit Carb Entry", comment: "The title of the view controller to edit an existing carb entry")
        } else {
            title = LocalizedString("carb-entry-title-add", value: "Add Carb Entry", comment: "The title of the view controller to create a new carb entry")
        }
    }

    private var foodKeyboard: CarbAbsorptionInputController!

    @IBOutlet weak var saveButtonItem: UIBarButtonItem!

    // MARK: - Table view data source

    fileprivate enum Row: Int {
        case value
        case fat
        case protein
        case date
        case foodType
        case absorptionTime

        static let count = 6
    }

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Row(rawValue: indexPath.row)! {
        case .value:
            let cell = tableView.dequeueReusableCell(withIdentifier: CarbDecimalTextFieldTableViewCell.className) as! CarbDecimalTextFieldTableViewCell

            if let quantity = quantity {
                cell.number = NSNumber(value: quantity.doubleValue(for: preferredUnit))
            }
            cell.textField.isEnabled = isSampleEditable
            cell.unitLabel?.text = String(describing: preferredUnit)

            if originalCarbEntry == nil {
                cell.textField.becomeFirstResponder()
            }

            cell.delegate = self

            return cell
        case .fat:
            let cell = tableView.dequeueReusableCell(withIdentifier: FatDecimalTextFieldTableViewCell.className) as! FatDecimalTextFieldTableViewCell
      
            cell.number = nil // Has to be nil or else the field will open with an actual 0 in it rather than empty with a virtual 0.
            cell.textField.isEnabled = isSampleEditable
            cell.unitLabel?.text = String(describing: preferredUnit)
            
            cell.delegate = self
            
            return cell
        case .protein:
            let cell = tableView.dequeueReusableCell(withIdentifier: ProteinDecimalTextFieldTableViewCell.className) as! ProteinDecimalTextFieldTableViewCell
            
            cell.number = nil // Has to be nil or else the field will open with an actual 0 in it rather than empty with a virtual 0.
            cell.textField.isEnabled = isSampleEditable
            cell.unitLabel?.text = String(describing: preferredUnit)
            
            cell.delegate = self
            
            return cell
        case .date:
            let cell = tableView.dequeueReusableCell(withIdentifier: DateAndDurationTableViewCell.className) as! DateAndDurationTableViewCell

            cell.titleLabel.text = LocalizedString("Date", comment: "Title of the carb entry date picker cell")
            cell.datePicker.isEnabled = isSampleEditable
            cell.datePicker.datePickerMode = .dateAndTime
            cell.datePicker.maximumDate = Date(timeIntervalSinceNow: maximumDateFutureInterval)
            cell.datePicker.minuteInterval = 1
            cell.date = date
            cell.delegate = self

            return cell
        case .foodType:
            if usesCustomFoodType {
                let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldTableViewCell.className, for: indexPath) as! TextFieldTableViewCell

                cell.textField.text = foodType
                cell.delegate = self

                if let textField = cell.textField as? CustomInputTextField {
                    if foodKeyboard == nil {
                        foodKeyboard = storyboard?.instantiateViewController(withIdentifier: CarbAbsorptionInputController.className) as? CarbAbsorptionInputController
                        foodKeyboard.delegate = self
                    }

                    textField.customInput = foodKeyboard
                }

                if originalCarbEntry == nil {
                    cell.textField.becomeFirstResponder()
                }

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: FoodTypeShortcutCell.className, for: indexPath) as! FoodTypeShortcutCell

                if absorptionTime == nil {
                    cell.selectionState = .medium
                }

                cell.delegate = self
                
                return cell
            }
        case .absorptionTime:
            let cell = tableView.dequeueReusableCell(withIdentifier: DateAndDurationTableViewCell.className) as! DateAndDurationTableViewCell

            cell.titleLabel.text = LocalizedString("Absorption Time", comment: "Title of the carb entry absorption time cell")
            cell.datePicker.isEnabled = isSampleEditable
            cell.datePicker.datePickerMode = .countDownTimer
            cell.datePicker.minuteInterval = Int(absorptionTimePickerInterval.minutes)

            if let duration = absorptionTime ?? defaultAbsorptionTimes?.medium {
                cell.duration = duration
            }

            cell.maximumDuration = maxAbsorptionTime
            cell.delegate = self

            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return LocalizedString("Optional Fat and protein entry will result in additional dosing over an extended duration for fat and protein calories, and will override manual entry of duration of absorption.", comment: "Carb entry section footer text explaining absorption time")
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        tableView.endEditing(false)
        tableView.beginUpdates()
        hideDatePickerCells(excluding: indexPath)
        return indexPath
    } // RSS FIX Date selected there.

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case is FoodTypeShortcutCell:
            usesCustomFoodType = true
            tableView.reloadRows(at: [IndexPath(row: Row.foodType.rawValue, section: 0)], with: .none)
        default:
            break
        }

        tableView.endUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Navigation

    public override func restoreUserActivityState(_ activity: NSUserActivity) {
        if let entry = activity.newCarbEntry {
            quantity = entry.quantity
            date = entry.startDate

            if let foodType = entry.foodType {
                self.foodType = foodType
                usesCustomFoodType = true
            }

            if let absorptionTime = entry.absorptionTime {
                self.absorptionTime = absorptionTime
                absorptionTimeWasEdited = true
            }
        }
    }
    // When Add/Edit carb and hit "save" button, this gets called.
    public override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        self.tableView.endEditing(true)

        guard let button = sender as? UIBarButtonItem, button == saveButtonItem else {
            quantity = nil
            return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        }

        guard let absorptionTime = absorptionTime ?? defaultAbsorptionTimes?.medium else {
            return false
        }
        guard absorptionTime <= maxAbsorptionTime else {
            navigationDelegate.showAbsorptionTimeValidationWarning(for: self, maxAbsorptionTime: maxAbsorptionTime)
            return false
        }

        // RSS - Allow one to save if protein or fat is entered, even if carb is 0.
        // Have to check "quantity" for carb because it means original quantity exists.
        guard let quantity = quantity, let fq = fatQuantity, let pq = proteinQuantity, (quantity.doubleValue(for: HKUnit.gram()) > 0 || (fq > 0.0) || (pq > 0.0)) else {
            return false
        }

        guard quantity.compare(maxQuantity) != .orderedDescending else {
            navigationDelegate.showMaxQuantityValidationWarning(for: self, maxQuantityGrams: maxQuantity.doubleValue(for: .gram()))
            return false
        }
        return true
    }
}


extension CarbEntryEditViewController: TextFieldTableViewCellDelegate {
    public func textFieldTableViewCellDidBeginEditing(_ cell: TextFieldTableViewCell) {
        // Collapse any date picker cells to save space
        tableView.beginUpdates()
        hideDatePickerCells()
        tableView.endUpdates()
    }

    public func textFieldTableViewCellDidEndEditing(_ cell: TextFieldTableViewCell) {
        guard let row = tableView.indexPath(for: cell)?.row else { return }

        switch Row(rawValue: row) {
        case .value?:
            if let cell = cell as? CarbDecimalTextFieldTableViewCell, let number = cell.number {
                carbQuantity = Double(number.doubleValue)
                quantity = HKQuantity(unit: preferredUnit, doubleValue: number.doubleValue)
            } else {
                quantity = HKQuantity(unit: preferredUnit, doubleValue: 0.1)
                // 0.1 to leave a marker for when you ate in HealthKit, Loop, and Nightscout.
                carbQuantity = 0.1
            }
        case .fat?:
            if let cell = cell as? FatDecimalTextFieldTableViewCell, let number = cell.number {
                fatQuantity = Double(number.doubleValue)
            } else {
                fatQuantity = 0.0
            }
        case .protein?:
            if let cell = cell as? ProteinDecimalTextFieldTableViewCell, let number = cell.number {
                proteinQuantity = Double(number.doubleValue)
            } else {
                proteinQuantity = 0.0
            }
        case .foodType?:
            foodType = cell.textField.text
        default:
            break
        }
    }
}


extension CarbEntryEditViewController: DatePickerTableViewCellDelegate {
    func datePickerTableViewCellDidUpdateDate(_ cell: DatePickerTableViewCell) {
        guard let row = tableView.indexPath(for: cell)?.row else { return }

        switch Row(rawValue: row) {
        case .date?:
            date = cell.date
        case .absorptionTime?:
            absorptionTime = cell.duration
            absorptionTimeWasEdited = true
        default:
            break
        }
    }
}


extension CarbEntryEditViewController: FoodTypeShortcutCellDelegate {
    func foodTypeShortcutCellDidUpdateSelection(_ cell: FoodTypeShortcutCell) {
        var absorptionTime: TimeInterval?

        switch cell.selectionState {
        case .fast:
            absorptionTime = defaultAbsorptionTimes?.fast
        case .medium:
            absorptionTime = defaultAbsorptionTimes?.medium
        case .slow:
            absorptionTime = defaultAbsorptionTimes?.slow
        case .custom:
            tableView.beginUpdates()
            usesCustomFoodType = true
            tableView.reloadRows(at: [IndexPath(row: Row.foodType.rawValue, section: 0)], with: .fade)
            tableView.endUpdates()
        }

        if let absorptionTime = absorptionTime {
            self.absorptionTime = absorptionTime

            if let cell = tableView.cellForRow(at: IndexPath(row: Row.absorptionTime.rawValue, section: 0)) as? DateAndDurationTableViewCell {
                cell.duration = absorptionTime
            }
        }
    }
}


extension CarbEntryEditViewController: CarbAbsorptionInputControllerDelegate {
    func carbAbsorptionInputControllerDidAdvanceToStandardInputMode(_ controller: CarbAbsorptionInputController) {
        if let cell = tableView.cellForRow(at: IndexPath(row: Row.foodType.rawValue, section: 0)) as? TextFieldTableViewCell, let textField = cell.textField as? CustomInputTextField, textField.customInput != nil {
            let customInput = textField.customInput
            textField.customInput = nil
            textField.resignFirstResponder()
            textField.becomeFirstResponder()
            textField.customInput = customInput
        }
    }

    func carbAbsorptionInputControllerDidSelectItemInSection(_ section: Int) {
        guard !absorptionTimeWasEdited, section < orderedAbsorptionTimes.count else {
            return
        }

        let lastAbsorptionTime = self.absorptionTime
        self.absorptionTime = orderedAbsorptionTimes[section]

        if let cell = tableView.cellForRow(at: IndexPath(row: Row.absorptionTime.rawValue, section: 0)) as? DateAndDurationTableViewCell {
            cell.duration = max(lastAbsorptionTime ?? 0, orderedAbsorptionTimes[section])
        }
    }
}
