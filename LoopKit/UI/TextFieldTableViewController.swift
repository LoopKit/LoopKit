//
//  TextFieldTableViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 8/30/15.
//  Copyright © 2015 Nathan Racklyeft. All rights reserved.
//

import UIKit


public protocol TextFieldTableViewControllerDelegate: class {
    func textFieldTableViewControllerDidEndEditing(controller: TextFieldTableViewController)

    func textFieldTableViewControllerDidReturn(controller: TextFieldTableViewController)
}


public class TextFieldTableViewController: UITableViewController, UITextFieldDelegate {

    private weak var textField: UITextField?

    public var indexPath: NSIndexPath?

    public var placeholder: String?

    public var value: String? {
        didSet {
            delegate?.textFieldTableViewControllerDidEndEditing(self)
        }
    }

    public var keyboardType = UIKeyboardType.Default

    public weak var delegate: TextFieldTableViewControllerDelegate?

    public convenience init() {
        self.init(style: .Grouped)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerNib(TextFieldTableViewCell.nib(), forCellReuseIdentifier: TextFieldTableViewCell.className)
    }

    public override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        textField?.becomeFirstResponder()
    }

    // MARK: - UITableViewDataSource

    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(TextFieldTableViewCell.className, forIndexPath: indexPath) as! TextFieldTableViewCell

        textField = cell.textField

        cell.textField.delegate = self
        cell.textField.text = value
        cell.textField.keyboardType = keyboardType
        cell.textField.placeholder = placeholder

        return cell
    }

    // MARK: - UITextFieldDelegate

    public func textFieldShouldEndEditing(textField: UITextField) -> Bool {
        value = textField.text

        return true
    }

    public func textFieldShouldReturn(textField: UITextField) -> Bool {
        value = textField.text

        textField.delegate = nil
        delegate?.textFieldTableViewControllerDidReturn(self)

        return false
    }
}
