//
//  IssueAlertTableViewController.swift
//  MockKitUI
//
//  Created by Rick Pasetto on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import MockKit

final class IssueAlertTableViewController: UITableViewController {
  
    let cgmManager: MockCGMManager

    static let delay = TimeInterval(60)
    
    private enum AlertRow: Int, CaseIterable, CustomStringConvertible {
        case immediate = 0
        case delayed
        case repeating
        case issueLater
        case retract
        case buzz
        case critical

        var description: String {
            switch self {
            case .immediate: return "Issue an immediate alert"
            case .delayed: return "Issue a \"delayed \(delay) seconds\" alert"
            case .repeating: return "Issue a \"repeating every \(delay) seconds\" alert"
            case .issueLater: return "Issue an immediate alert \(delay) seconds from now"
            case .retract: return "Retract any alert above"
            case .buzz: return "Issue an immediate vibrate alert"
            case .critical: return "Issue a critical immediate alert"
            }
        }
        
        var trigger: Alert.Trigger {
            switch self {
            case .immediate: return .immediate
            case .retract: return .immediate
            case .critical: return .immediate
            case .delayed: return .delayed(interval: delay)
            case .repeating: return .repeating(repeatInterval: delay)
            case .issueLater: return .immediate
            case .buzz: return .immediate
            }
        }
        
        var delayBeforeIssue: TimeInterval? {
            switch self {
            case .issueLater: return delay
            default: return nil
            }
        }
        
        var identifier: Alert.AlertIdentifier {
            switch self {
            case .buzz: return MockCGMManager.buzz.identifier
            case .critical: return MockCGMManager.critical.identifier
            default: return MockCGMManager.submarine.identifier
            }
        }
    }

    init(cgmManager: MockCGMManager) {
        self.cgmManager = cgmManager
        super.init(style: .plain)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Issue Alerts"

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)

        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped(_:)))
        navigationItem.setRightBarButton(button, animated: false)
    }
    
    @objc func doneTapped(_ sender: Any) {
        done()
    }
    
    private func done() {
        if let nav = navigationController as? SettingsNavigationViewController {
            nav.notifyComplete()
        }
        if let nav = navigationController as? MockPumpManagerSetupViewController {
            nav.finishedSettingsDisplay()
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AlertRow.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
        cell.textLabel?.text = String(describing: AlertRow(rawValue: indexPath.row)!)
        cell.textLabel?.textAlignment = .center
        cell.isEnabled = true
        return cell
    }
    
    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = AlertRow(rawValue: indexPath.row)!
        switch row {
        case .retract:
            cgmManager.retractAlert(identifier: row.identifier)
        default:
            cgmManager.issueAlert(identifier: row.identifier, trigger: row.trigger, delay: row.delayBeforeIssue)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

}
