//
//  CommandResponseViewController.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/26/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public class CommandResponseViewController: UIViewController {
    public typealias Command = (completionHandler: (responseText: String) -> Void) -> String

    public init(command: Command) {
        self.command = command

        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let command: Command

    private lazy var textView = UITextView()

    override public func loadView() {
        self.view = textView
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        textView.font = UIFont(name: "Menlo-Regular", size: 14)
        textView.text = command { [weak self] (responseText) -> Void in
            self?.textView.text = responseText
        }
        textView.editable = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: #selector(shareText(_:)))
    }

    @objc func shareText(_: AnyObject?) {
        let activityVC = UIActivityViewController(activityItems: [self], applicationActivities: nil)

        presentViewController(activityVC, animated: true, completion: nil)
    }
}

extension CommandResponseViewController: UIActivityItemSource {
    public func activityViewControllerPlaceholderItem(activityViewController: UIActivityViewController) -> AnyObject {
        return title ?? textView.text
    }

    public func activityViewController(activityViewController: UIActivityViewController, itemForActivityType activityType: String) -> AnyObject? {
        return textView.attributedText
    }

    public func activityViewController(activityViewController: UIActivityViewController, subjectForActivityType activityType: String?) -> String {
        return title ?? textView.text
    }
}
