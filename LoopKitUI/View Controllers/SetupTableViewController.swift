//
//  SetupTableViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit


open class SetupTableViewController: UITableViewController {
    open var setupViewController: PumpManagerSetupViewController? {
        return navigationController as? PumpManagerSetupViewController
    }

    open var cgmSetupViewController: CGMManagerSetupViewController? {
        return navigationController as? CGMManagerSetupViewController
    }
    
    open var setupNavigationController: SetupNavigationController? {
        return navigationController as? SetupNavigationController
    }

    private(set) open lazy var footerView = SetupTableFooterView(frame: .zero)

    private var lastContentHeight: CGFloat = 0
    
    private var compactMode: Bool = false {
        didSet {
            if oldValue != compactMode {
                tableView.reloadData()
            }
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed(_:)))

        footerView.primaryButton.addTarget(self, action: #selector(continueButtonPressed(_:)), for: .touchUpInside)
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let visibleHeight = tableView.bounds.size.height - (tableView.adjustedContentInset.top + tableView.adjustedContentInset.bottom)
        
        if visibleHeight < tableView.contentSize.height {
            compactMode = true
        }

        // Reposition footer view if necessary
        if tableView.contentSize.height != lastContentHeight {
            lastContentHeight = tableView.contentSize.height
            tableView.tableFooterView = nil

            var footerSize = footerView.systemLayoutSizeFitting(CGSize(width: tableView.frame.size.width, height: UIView.layoutFittingCompressedSize.height))
            let footerPadding = max(footerSize.height, visibleHeight - tableView.contentSize.height)

            footerSize.height = footerPadding
            footerView.frame.size = footerSize
            tableView.tableFooterView = footerView
        }
    }

    @IBAction open func cancelButtonPressed(_: Any) {
        setupNavigationController?.cancelSetup()
    }

    @IBAction open func continueButtonPressed(_ sender: Any) {
        if shouldPerformSegue(withIdentifier: "Continue", sender: sender) {
            performSegue(withIdentifier: "Continue", sender: sender)
        }
    }

    // MARK: - UITableViewDelegate

    open override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    open override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    open override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if compactMode {
            return 5
        } else {
            return UITableView.automaticDimension
        }
    }
}


open class SetupTableFooterView: UIView {

    public let primaryButton = SetupButton(type: .custom)

    fileprivate override init(frame: CGRect) {
        let buttonStack = UIStackView(arrangedSubviews: [primaryButton])

        super.init(frame: frame)

        autoresizingMask = [.flexibleWidth]
        primaryButton.resetTitle()

        buttonStack.alignment = .center
        buttonStack.axis = .vertical
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(buttonStack)

        NSLayoutConstraint.activate([
            primaryButton.leadingAnchor.constraint(equalTo: buttonStack.leadingAnchor),
            primaryButton.trailingAnchor.constraint(equalTo: buttonStack.trailingAnchor),

            buttonStack.topAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.topAnchor),
            buttonStack.leadingAnchor.constraint(equalToSystemSpacingAfter: layoutMarginsGuide.leadingAnchor, multiplier: 1),
            layoutMarginsGuide.trailingAnchor.constraint(equalToSystemSpacingAfter: buttonStack.trailingAnchor, multiplier: 1),
            safeAreaLayoutGuide.bottomAnchor.constraint(equalToSystemSpacingBelow: buttonStack.bottomAnchor, multiplier: 2),
        ])
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


public extension SetupButton {
    func resetTitle() {
        setTitle(LocalizedString("Continue", comment: "Title of the setup button to continue"), for: .normal)
    }
}
