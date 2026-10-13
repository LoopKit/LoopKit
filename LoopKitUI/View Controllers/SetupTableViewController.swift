//
//  SetupTableViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

public protocol SetupTableViewControllerDelegate: AnyObject {
    func setupTableViewControllerCancelButtonPressed(_ viewController: SetupTableViewController)
}

open class SetupTableViewController: UITableViewController {

    private(set) open lazy var footerView = SetupTableFooterView(frame: .zero)

    public var padFooterToBottom: Bool = true

    public weak var delegate: SetupTableViewControllerDelegate?
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed(_:)))

        footerView.primaryButton.addTarget(self, action: #selector(continueButtonPressed(_:)), for: .touchUpInside)
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Rotation can change the available space without changing the row heights.
        // Exclude the current footer so its previous size cannot affect the new size.
        let contentHeight = tableView.contentSize.height - (tableView.tableFooterView?.frame.height ?? 0)
        let visibleHeight = tableView.bounds.height - tableView.adjustedContentInset.top - tableView.adjustedContentInset.bottom
        var footerSize = footerView.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        if padFooterToBottom {
            footerSize.height = max(footerSize.height, visibleHeight - contentHeight)
        }

        guard tableView.tableFooterView !== footerView || footerView.frame.size != footerSize else { return }
        footerView.frame.size = footerSize
        tableView.tableFooterView = footerView
    }

    @IBAction open func cancelButtonPressed(_: Any) {
        delegate?.setupTableViewControllerCancelButtonPressed(self)
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
        return UITableView.automaticDimension
    }
}


open class SetupTableFooterView: UIView {

    public let primaryButton = SetupButton(type: .custom)

    public override init(frame: CGRect) {
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
