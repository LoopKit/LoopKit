//
//  CarbEntryEditViewController.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/15/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

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

    /// Entry configuration values. Must be set before presenting.
    public var absorptionTimePickerInterval = TimeInterval(minutes: 30)

    public var maxAbsorptionTime = TimeInterval(hours: 8)

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

                shouldBeginEditingQuantity = false
            }
        }
    }

    fileprivate var quantity: HKQuantity?

    fileprivate var date = Date()

    fileprivate var foodType: String?

    fileprivate var absorptionTime: TimeInterval?

    fileprivate var absorptionTimeWasEdited = false

    fileprivate var usesCustomFoodType = false

    private var shouldBeginEditingQuantity = true

    private var shouldBeginEditingFoodType = false

    public var updatedCarbEntry: NewCarbEntry? {
        if  let quantity = quantity,
            let absorptionTime = absorptionTime ?? defaultAbsorptionTimes?.medium
        {
            if let o = originalCarbEntry, o.quantity == quantity && o.startDate == date && o.foodType == foodType && o.absorptionTime == absorptionTime {
                return nil  // No changes were made
            }
            
            return NewCarbEntry(
                quantity: quantity,
                startDate: date,
                foodType: foodType,
                absorptionTime: absorptionTime,
                externalID: originalCarbEntry?.externalID
            )
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
            title = LocalizedString("Edit Carb Entry", value: "Edit Carb Entry", comment: "The title of the view controller to edit an existing carb entry")
        } else {
            title = LocalizedString("Add Carb Entry", value: "Add Carb Entry", comment: "The title of the view controller to create a new carb entry")
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldBeginEditingQuantity, let cell = tableView.cellForRow(at: IndexPath(row: Row.value.rawValue, section: 0)) as? DecimalTextFieldTableViewCell {
            shouldBeginEditingQuantity = false
            cell.textField.becomeFirstResponder()
        }
    }

    private var foodKeyboard: EmojiInputController!

    @IBOutlet weak var saveButtonItem: UIBarButtonItem!

    // MARK: - Table view data source

    fileprivate enum Row: Int {
        case value
        case date
        case foodType
        case absorptionTime

        static let count = 4
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
            let cell = tableView.dequeueReusableCell(withIdentifier: DecimalTextFieldTableViewCell.className) as! DecimalTextFieldTableViewCell

            if let quantity = quantity {
                cell.number = NSNumber(value: quantity.doubleValue(for: preferredUnit))
            }
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
                        foodKeyboard = CarbAbsorptionInputController()
                        foodKeyboard.delegate = self
                    }

                    textField.customInput = foodKeyboard
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

    public override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        switch Row(rawValue: indexPath.row)! {
        case .value, .date:
            break
        case .foodType:
            if usesCustomFoodType, shouldBeginEditingFoodType, let cell = cell as? TextFieldTableViewCell {
                shouldBeginEditingFoodType = false
                cell.textField.becomeFirstResponder()
            }
        case .absorptionTime:
            break
        }
    }

    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return LocalizedString("Choose a longer absorption time for larger meals, or those containing fats and proteins. This is only guidance to the algorithm and need not be exact.", comment: "Carb entry section footer text explaining absorption time")
    }

    // MARK: - UITableViewDelegate

    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        tableView.endEditing(false)
        tableView.beginUpdates()
        hideDatePickerCells(excluding: indexPath)
        return indexPath
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableView.cellForRow(at: indexPath) {
        case is FoodTypeShortcutCell:
            usesCustomFoodType = true
            shouldBeginEditingFoodType = true
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

        guard let quantity = quantity, quantity.doubleValue(for: HKUnit.gram()) > 0 else { return false }
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
            if let cell = cell as? DecimalTextFieldTableViewCell, let number = cell.number {
                quantity = HKQuantity(unit: preferredUnit, doubleValue: number.doubleValue)
            } else {
                quantity = nil
            }
        case .foodType?:
            foodType = cell.textField.text
        default:
            break
        }
    }
}


extension CarbEntryEditViewController: DatePickerTableViewCellDelegate {
    public func datePickerTableViewCellDidUpdateDate(_ cell: DatePickerTableViewCell) {
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
    public func foodTypeShortcutCellDidUpdateSelection(_ cell: FoodTypeShortcutCell) {
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
            shouldBeginEditingFoodType = true
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


extension CarbEntryEditViewController: EmojiInputControllerDelegate {
    public func emojiInputControllerDidAdvanceToStandardInputMode(_ controller: EmojiInputController) {
        if let cell = tableView.cellForRow(at: IndexPath(row: Row.foodType.rawValue, section: 0)) as? TextFieldTableViewCell, let textField = cell.textField as? CustomInputTextField, textField.customInput != nil {
            let customInput = textField.customInput
            textField.customInput = nil
            textField.resignFirstResponder()
            textField.becomeFirstResponder()
            textField.customInput = customInput
        }
    }

    public func emojiInputControllerDidSelectItemInSection(_ section: Int) {
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
