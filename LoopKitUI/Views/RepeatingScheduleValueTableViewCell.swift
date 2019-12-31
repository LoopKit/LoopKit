//
//  RepeatingScheduleValueTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/6/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


protocol RepeatingScheduleValueTableViewCellDelegate: DatePickerTableViewCellDelegate {
    func repeatingScheduleValueTableViewCellDidUpdateValue(_ cell: RepeatingScheduleValueTableViewCell)
}


class RepeatingScheduleValueTableViewCell: DatePickerTableViewCell, UITextFieldDelegate {

    weak var delegate: RepeatingScheduleValueTableViewCellDelegate?

    var timeZone: TimeZone! {
        didSet {
            dateFormatter.timeZone = timeZone
            datePicker.timeZone = timeZone
        }
    }

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short

        return dateFormatter
    }()

    override func updateDateLabel() {
        dateLabel.text = dateFormatter.string(from: date)
    }

    override func dateChanged(_ sender: UIDatePicker) {
        super.dateChanged(sender)

        delegate?.datePickerTableViewCellDidUpdateDate(self)
    }

    var value: Double = 0 {
        didSet {
            textField.text = valueNumberFormatter.string(from: value)
        }
    }

    var datePickerInterval: TimeInterval {
        return TimeInterval(minutes: Double(datePicker.minuteInterval))
    }

    var isReadOnly = false {
        didSet {
            if isReadOnly, textField.isFirstResponder {
                textField.resignFirstResponder()
            }
        }
    }

    lazy var valueNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1

        return formatter
    }()

    @IBOutlet weak var dateLabel: UILabel!

    @IBOutlet weak var unitLabel: UILabel! {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            if #available(iOSApplicationExtension 13.0, *) {
                unitLabel.textColor = .secondaryLabel
            }
        }
    }

    @IBOutlet weak var textField: UITextField! {
        didSet {
            // Setting this color in code because the nib isn't being applied correctly
            if #available(iOSApplicationExtension 13.0, *) {
                textField.textColor = .label
            }
        }
    }

    var unitString: String? {
        get {
            return unitLabel.text
        }
        set {
            unitLabel.text = newValue
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return !isReadOnly
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.async {
            textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        value = valueNumberFormatter.number(from: textField.text ?? "")?.doubleValue ?? 0

        delegate?.repeatingScheduleValueTableViewCellDidUpdateValue(self)
    }
}
