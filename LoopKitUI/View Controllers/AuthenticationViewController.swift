//
//  AuthenticationViewController.swift
//  Loop
//
//  Created by Nate Racklyeft on 7/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import LoopKit


public final class AuthenticationViewController<T: ServiceAuthenticationUI>: UITableViewController, UITextFieldDelegate {

    public typealias AuthenticationObserver = (_ authentication: T) -> Void

    public var authenticationObserver: AuthenticationObserver?

    public let authentication: T

    private var state: AuthenticationState = .empty {
        didSet {
            switch (oldValue, state) {
            case let (x, y) where x == y:
                break
            case (_, .verifying):
                let titleView = ValidatingIndicatorView(frame: CGRect.zero)
                UIView.animate(withDuration: 0.25, animations: {
                    self.navigationItem.hidesBackButton = true
                    self.navigationItem.titleView = titleView
                }) 

                tableView.reloadSections(IndexSet(integersIn: 0...1), with: .automatic)
                authentication.verify { (success, error) in
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.25, animations: {
                            self.navigationItem.titleView = nil
                            self.navigationItem.hidesBackButton = false
                        }) 

                        if let error = error {
                            let alert = UIAlertController(with: error)
                            self.present(alert, animated: true)
                        }

                        if success {
                            self.state = .authorized
                        } else {
                            self.state = .unauthorized
                        }
                    }
                }
            case (_, .authorized), (_, .unauthorized):
                authentication.isAuthorized = (state == .authorized)

                authenticationObserver?(authentication)
                tableView.reloadSections(IndexSet(integersIn: 0...1), with: .automatic)
            default:
                break
            }
        }
    }

    var credentials: [(field: ServiceCredential, value: String?)] {
        switch state {
        case .authorized:


            return authentication.credentials.filter({ !$0.field.isSecret })
        default:
            return authentication.credentials
        }
    }

    public init(authentication: T) {
        self.authentication = authentication

        state = authentication.isAuthorized ? .authorized : .unauthorized

        super.init(style: .grouped)

        title = authentication.title
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(AuthenticationTableViewCell.nib(), forCellReuseIdentifier: AuthenticationTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
    }

    // MARK: - Table view data source

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .credentials:
            return credentials.count
        case .button:
            return 1
        }
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .button:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.textAlignment = .center

            switch state {
            case .authorized:
                cell.textLabel?.text = LocalizedString("Delete Account", comment: "The title of the button to remove the credentials for a service")
                cell.tintColor = .delete
            case .empty, .unauthorized, .verifying:
                cell.textLabel?.text = LocalizedString("Add Account", comment: "The title of the button to add the credentials for a service")
                cell.tintColor = nil
            }

            if case .verifying = state {
                cell.isEnabled = false
            } else {
                cell.isEnabled = true
            }

            return cell
        case .credentials:
            let cell = tableView.dequeueReusableCell(withIdentifier: AuthenticationTableViewCell.className, for: indexPath) as! AuthenticationTableViewCell

            let credentials = self.credentials
            let credential = credentials[indexPath.row]

            cell.titleLabel.text = credential.field.title
            cell.textField.keyboardType = credential.field.keyboardType
            cell.textField.isSecureTextEntry = credential.field.isSecret
            cell.textField.returnKeyType = (indexPath.row < credentials.count - 1) ? .next : .done
            cell.textField.text = credential.value
            cell.textField.placeholder = credential.field.placeholder ?? LocalizedString("Required", comment: "The default placeholder string for a credential")

            if let options = credential.field.options {
                let picker = CredentialOptionPicker(options: options)
                picker.value = credential.value
                authentication.credentialValues[indexPath.row] = credential.value ?? options.first?.value

                cell.credentialOptionPicker = picker
            }

            cell.textField.delegate = self

            switch state {
            case .authorized, .verifying, .empty:
                cell.textField.isEnabled = false
            case .unauthorized:
                cell.textField.isEnabled = true
            }

            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .credentials:
            return false
        case .button:
            return true
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .credentials:
            break
        case .button:
            switch state {
            case .authorized:
                tableView.endEditing(false)
                authentication.resetCredentials()
                state = .unauthorized
            case .unauthorized:
                tableView.endEditing(false)
                validate()
            case .verifying:
                break
            case .empty:
                break
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    fileprivate func validate() {
        state = .verifying
    }

    // MARK: - Actions

    // MARK: - UITextFieldDelegate

    public func textFieldDidEndEditing(_ textField: UITextField) {
        let point = tableView.convert(textField.frame.origin, from: textField.superview)

        guard case .unauthorized = state,
            let indexPath = tableView.indexPathForRow(at: point),
            let cell = tableView.cellForRow(at: IndexPath(row: indexPath.row, section: indexPath.section)) as? AuthenticationTableViewCell
        else {
            return
        }

        authentication.credentialValues[indexPath.row] = cell.value
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.returnKeyType == .done {
            textField.resignFirstResponder()
            validate()
        } else {
            let point = tableView.convert(textField.frame.origin, from: textField.superview)
            if let indexPath = tableView.indexPathForRow(at: point),
                let cell = tableView.cellForRow(at: IndexPath(row: indexPath.row + 1, section: indexPath.section)) as? AuthenticationTableViewCell
            {
                cell.textField.becomeFirstResponder()
            }
        }

        return true
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return textField.inputView == nil
    }
}


private enum Section: Int {
    case credentials
    case button

    static let count = 2
}


private enum AuthenticationState {
    case empty
    case authorized
    case verifying
    case unauthorized
}
