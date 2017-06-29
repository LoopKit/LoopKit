//
//  DefaultAbsorptionTimesTableViewController.swift
//  LoopKit
//
//  Created by Michael Pangburn on 6/2/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit


public protocol DefaultAbsorptionTimesTableViewControllerDelegate: class {
    func defaultAbsorptionTimesTableViewControllerDidEndEditing(_ controller: DefaultAbsorptionTimesTableViewController)
}


public class DefaultAbsorptionTimesTableViewController: UITableViewController {
    
    public weak var delegate: DefaultAbsorptionTimesTableViewControllerDelegate?
    
    public var defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes
    
    fileprivate enum Row: Int {
        case fast
        case medium
        case slow
        
        static let count = 3
        
        var labelText: String {
            switch self {
            case .fast:
                return NSLocalizedString("🍭 Fast", comment: "The label text for the fast absorption time cell.")
            case .medium:
                return NSLocalizedString("🌮 Medium", comment: "The label text for the medium absorption time cell.")
            case .slow:
                return NSLocalizedString("🍕 Slow", comment: "The label text for the slow absorption time cell.")
            }
        }
        
        func correspondingTimeInterval(for defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes) -> TimeInterval {
            switch self {
            case .fast:
                return defaultAbsorptionTimes.fast
            case .medium:
                return defaultAbsorptionTimes.medium
            case .slow:
                return defaultAbsorptionTimes.slow
            }
        }
    }
    
    public init(defaultAbsorptionTimes: CarbStore.DefaultAbsorptionTimes) {
        self.defaultAbsorptionTimes = defaultAbsorptionTimes
        super.init(style: .grouped)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(DefaultAbsorptionTimeTableViewCell.nib(), forCellReuseIdentifier: DefaultAbsorptionTimeTableViewCell.className)
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableViewAutomaticDimension
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        tableView.endEditing(true)
        
        delegate?.defaultAbsorptionTimesTableViewControllerDidEndEditing(self)
    }
    
    override public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.count
    }
    
    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DefaultAbsorptionTimeTableViewCell.className, for: indexPath) as! DefaultAbsorptionTimeTableViewCell
        let row = Row(rawValue: indexPath.row)!
        cell.absorptionSpeedLabel.text = row.labelText
        cell.time = row.correspondingTimeInterval(for: defaultAbsorptionTimes)
        cell.delegate = self
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    public override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        tableView.endEditing(false)
        tableView.beginUpdates()
        return indexPath
    }
    
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.endUpdates()
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

extension DefaultAbsorptionTimesTableViewController: DefaultAbsorptionTimeTableViewCellDelegate {
    func defaultAbsorptionTimeTableViewCellDidUpdateTime(_ cell: DefaultAbsorptionTimeTableViewCell) {
        let indexPath = tableView.indexPath(for: cell)!
        let row = Row(rawValue: indexPath.row)!
        switch row {
        case .fast:
            defaultAbsorptionTimes.fast = cell.time
        case .medium:
            defaultAbsorptionTimes.medium = cell.time
        case .slow:
            defaultAbsorptionTimes.slow = cell.time
        }
    }
}
