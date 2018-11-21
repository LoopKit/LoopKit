//
//  DateAndDurationTableViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/24/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit


protocol DateAndDurationTableViewControllerDelegate: class {
    func dateAndDurationTableViewControllerDidChangeDate(_ controller: DateAndDurationTableViewController)
}

class DateAndDurationTableViewController: UITableViewController {
    enum InputMode {
        case date(Date, mode: UIDatePicker.Mode)
        case duration(TimeInterval)
    }

    var inputMode: InputMode = .date(Date(), mode: .dateAndTime) {
        didSet {
            delegate?.dateAndDurationTableViewControllerDidChangeDate(self)
        }
    }

    var titleText: String?

    var contextHelp: String?

    var indexPath: IndexPath?

    weak var delegate: DateAndDurationTableViewControllerDelegate?

    convenience init() {
        self.init(style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(DateAndDurationTableViewCell.nib(), forCellReuseIdentifier: DateAndDurationTableViewCell.className)
    }

    private var completion: ((InputMode) -> Void)?

    func onSave(_ completion: @escaping (InputMode) -> Void) {
        let saveBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        navigationItem.rightBarButtonItem = saveBarButtonItem
        self.completion = completion
    }

    @objc private func save() {
        completion?(inputMode)
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DateAndDurationTableViewCell.className, for: indexPath) as! DateAndDurationTableViewCell
        switch inputMode {
        case .date(let date, mode: let mode):
            cell.datePicker.datePickerMode = mode
            cell.date = date
        case .duration(let duration):
            cell.datePicker.datePickerMode = .countDownTimer
            cell.maximumDuration = .hours(24)
            cell.duration = duration
        }
        cell.titleLabel.text = titleText
        cell.isDatePickerHidden = false
        cell.selectionStyle = .none
        cell.delegate = self
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return contextHelp
    }
}

extension DateAndDurationTableViewController: DatePickerTableViewCellDelegate {
    func datePickerTableViewCellDidUpdateDate(_ cell: DatePickerTableViewCell) {
        switch inputMode {
        case .date(_, mode: let mode):
            inputMode = .date(cell.date, mode: mode)
        case .duration(_):
            inputMode = .duration(cell.duration)
        }
    }
}
