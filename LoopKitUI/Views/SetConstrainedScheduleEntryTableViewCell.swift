//
//  SetConstrainedScheduleEntryTableViewCell.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

protocol SetConstrainedScheduleEntryTableViewCellDelegate: AnyObject {
    func setConstrainedScheduleEntryTableViewCellDidUpdate(_ cell: SetConstrainedScheduleEntryTableViewCell)
}

private enum Component: Int, CaseIterable {
    case time = 0
    case value
}

class SetConstrainedScheduleEntryTableViewCell: UITableViewCell {

    public enum EmptySelectionType {
        case none
        case firstIndex
        case lastIndex

        var rowCount: Int {
            if self == .none {
                return 0
            } else {
                return 1
            }
        }

        var rowOffset: Int {
            if self == .firstIndex {
                return 1
            } else {
                return 0
            }
        }
    }

    @IBOutlet private weak var picker: UIPickerView!

    @IBOutlet private weak var pickerHeightConstraint: NSLayoutConstraint!

    private var pickerExpandedHeight: CGFloat = 0

    @IBOutlet private weak var dateLabel: UILabel!

    @IBOutlet private weak var valueLabel: UILabel!

    public weak var delegate: SetConstrainedScheduleEntryTableViewCellDelegate?

    public var allowedValues: [Double] = [] {
        didSet {
            picker.reloadAllComponents()
            updateValuePicker()
        }
    }

    public var emptySelectionType = EmptySelectionType.none {
        didSet {
            picker.reloadAllComponents()
            updateValuePicker()
        }
    }

    public var unit: HKUnit? {
        didSet {
            if let unit = unit {
                valueQuantityFormatter.setPreferredNumberFormatter(for: unit)
                picker.reloadAllComponents()
                updateValuePicker()
            }
        }
    }

    public var minimumTimeInterval: TimeInterval = .hours(0.5)

    public var minimumStartTime: TimeInterval = .hours(0) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
            updateStartTimeSelection()
        }
    }
    public var maximumStartTime: TimeInterval = .hours(23.5) {
        didSet {
            picker.reloadComponent(Component.time.rawValue)
        }
    }

    public var timeZone: TimeZone! {
        didSet {
            dateFormatter.timeZone = timeZone
            var calendar = Calendar.current
            calendar.timeZone = timeZone
            startOfDay = calendar.startOfDay(for: Date())
        }
    }

    private lazy var startOfDay = Calendar.current.startOfDay(for: Date())

    var startTime: TimeInterval = 0 {
        didSet {
            updateStartTimeSelection()
            updateDateLabel()
        }
    }

    var selectedStartTime: TimeInterval {
        let row = picker.selectedRow(inComponent: Component.time.rawValue)
        return startTimeForTimeComponent(row: row)
    }

    var value: Double? = nil {
        didSet {
            updateValuePicker()
            updateValueLabel()
        }
    }

    var isPickerHidden: Bool {
        get {
            return picker.isHidden
        }
        set {
            picker.isHidden = newValue
            pickerHeightConstraint.constant = newValue ? 0 : pickerExpandedHeight

            if !newValue {
                updateValuePicker()
                updateStartTimeSelection()
            }
        }
    }

    var isReadOnly = false

    override func awakeFromNib() {
        super.awakeFromNib()

        pickerExpandedHeight = pickerHeightConstraint.constant

        valueLabel.text = nil
        setSelected(true, animated: false)
        updateDateLabel()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected && !isReadOnly {
            isPickerHidden.toggle()
        }
    }

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short

        return dateFormatter
    }()

    lazy var valueQuantityFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter()
        return formatter
    }()

    private func startTimeForTimeComponent(row: Int) -> TimeInterval {
        return minimumStartTime + minimumTimeInterval * TimeInterval(row)
    }

    private func stringForStartTime(_ time: TimeInterval) -> String {
        let date = startOfDay.addingTimeInterval(time)
        return dateFormatter.string(from: date)
    }

    func updateDateLabel() {
        dateLabel.text = stringForStartTime(startTime)
    }

    func validate() {
        if let value = value, allowedValues.contains(value) {
            valueLabel.textColor = nil  // Default color
        } else {
            valueLabel.textColor = .systemRed
        }
    }

    func updateValueFromPicker() {
        let index = picker.selectedRow(inComponent: Component.value.rawValue) - emptySelectionType.rowOffset
        if index >= 0 && index < allowedValues.count {
            value = allowedValues[index]
        } else {
            value = nil
        }
        updateValueLabel()
    }

    private func updateStartTimeSelection() {
        let row = Int(round((startTime - minimumStartTime) / minimumTimeInterval))
        if row >= 0 && row < pickerView(picker, numberOfRowsInComponent: Component.time.rawValue) {
            picker.selectRow(row, inComponent: Component.time.rawValue, animated: true)
        }
    }

    func updateValuePicker() {
        guard !allowedValues.isEmpty else {
            return
        }
        let selectedIndex: Int
        if let value = value {
            if let row = allowedValues.firstIndex(of: value) {
                selectedIndex = row + emptySelectionType.rowOffset
            } else {
                // Select next highest value
                selectedIndex = (allowedValues.enumerated().filter({$0.element >= value}).min(by: { $0.1 < $1.1 })?.offset ?? 0) + emptySelectionType.rowOffset
            }
        } else {
            switch emptySelectionType {
            case .none:
                selectedIndex = allowedValues.count - 1
            case .firstIndex:
                selectedIndex = 0
            case .lastIndex:
                selectedIndex = allowedValues.count
            }
        }
        picker.selectRow(selectedIndex, inComponent: Component.value.rawValue, animated: true)
    }

    func updateValueLabel() {
        guard let value = value else {
            valueLabel.text = nil
            return
        }
        validate()
        valueLabel.text = formatValue(value)
    }

    private func formatValue(_ value: Double) -> String? {
        if let unit = unit {
            let quantity = HKQuantity(unit: unit, doubleValue: value)
            return valueQuantityFormatter.string(from: quantity, for: unit)
        } else {
            return valueQuantityFormatter.numberFormatter.string(from: value)
        }
    }
}


extension SetConstrainedScheduleEntryTableViewCell: UIPickerViewDelegate {

    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {
        switch Component(rawValue: component)! {
        case .time:
            startTime = selectedStartTime
        case .value:
            updateValueFromPicker()
        }

        delegate?.setConstrainedScheduleEntryTableViewCellDidUpdate(self)
    }

    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        let metrics = UIFontMetrics(forTextStyle: .body)
        return metrics.scaledValue(for: 32)
    }

    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {

        switch Component(rawValue: component)! {
        case .time:
            let time = startTimeForTimeComponent(row: row)
            return stringForStartTime(time)
        case .value:
            let valueRow = row - emptySelectionType.rowOffset
            guard valueRow >= 0 && valueRow < allowedValues.count else {
                return nil
            }
            return formatValue(allowedValues[valueRow])
        }
    }
}

extension SetConstrainedScheduleEntryTableViewCell: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return Component.allCases.count
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch Component(rawValue: component)! {
        case .time:
            return Int(round((maximumStartTime - minimumStartTime) / minimumTimeInterval) + 1)
        case .value:
            return allowedValues.count + emptySelectionType.rowCount
        }
    }
}

/// UITableViewController extensions to aid working with DatePickerTableViewCell
extension SetConstrainedScheduleEntryTableViewCellDelegate where Self: UITableViewController {
    func hideSetConstrainedScheduleEntryCells(excluding indexPath: IndexPath? = nil) {
        for case let cell as SetConstrainedScheduleEntryTableViewCell in tableView.visibleCells where tableView.indexPath(for: cell) != indexPath && cell.isPickerHidden == false {
            cell.isPickerHidden = true
        }
    }
}
