//
//  RepeatingScheduleValueTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/6/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


protocol RepeatingScheduleValueTableViewCellDelegate: class {
    func repeatingScheduleValueTableViewCellDidUpdateDate(_ cell: RepeatingScheduleValueTableViewCell)

    func repeatingScheduleValueTableViewCellDidUpdateValue(_ cell: RepeatingScheduleValueTableViewCell)
}


class RepeatingScheduleValueTableViewCell: UITableViewCell, UITextFieldDelegate {

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

    var date: Date = Date() {
        didSet {
            dateLabel.text = dateFormatter.string(from: date)

            if datePicker.date != date {
                datePicker.date = date
            }
        }
    }

    var value: Double = 0 {
        didSet {
            textField.text = valueNumberFormatter.string(from: value.rawValue)
        }
    }

    var datePickerInterval: TimeInterval {
        return TimeInterval(minutes: Double(datePicker.minuteInterval))
    }

    lazy var valueNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1

        return formatter
    }()

    @IBOutlet weak var dateLabel: UILabel!

    @IBOutlet weak var unitLabel: UILabel!

    @IBOutlet weak var textField: UITextField!

    @IBOutlet weak var datePicker: UIDatePicker!

    @IBOutlet weak var datePickerHeightConstraint: NSLayoutConstraint!

    private var datePickerExpandedHeight: CGFloat = 0

    override func awakeFromNib() {
        super.awakeFromNib()

        datePickerExpandedHeight = datePickerHeightConstraint.constant
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        datePicker.isHidden = !selected
        datePickerHeightConstraint.constant = selected ? datePickerExpandedHeight : 0
    }

    var unitString: String? {
        get {
            return unitLabel.text
        }
        set {
            unitLabel.text = newValue
        }
    }

    @IBAction func dateChanged(_ sender: UIDatePicker) {
        date = sender.date

        delegate?.repeatingScheduleValueTableViewCellDidUpdateDate(self)
    }

    // MARK: - UITextFieldDelegate

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
