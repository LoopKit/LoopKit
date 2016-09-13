//
//  CommandResponseViewController.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/26/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


public class CommandResponseViewController: UIViewController {
    public typealias Command = (_ completionHandler: (_ responseText: String) -> Void) -> String

    public init(command: @escaping Command) {
        self.command = command

        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let command: Command

    fileprivate lazy var textView = UITextView()

    public override func loadView() {
        self.view = textView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        textView.font = UIFont(name: "Menlo-Regular", size: 14)
        textView.text = command { [weak self] (responseText) -> Void in
            self?.textView.text = responseText
        }
        textView.isEditable = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareText(_:)))
    }

    @objc func shareText(_: Any?) {
        let activityVC = UIActivityViewController(activityItems: [self], applicationActivities: nil)

        present(activityVC, animated: true, completion: nil)
    }
}

extension CommandResponseViewController: UIActivityItemSource {
    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return title ?? textView.text
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType) -> Any? {
        return textView.attributedText
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivityType?) -> String {
        return title ?? textView.text
    }
}
