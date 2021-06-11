//
//  DismissibleHostingController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public class DismissibleHostingController: UIHostingController<AnyView> {
    public enum DismissalMode {
        case modalDismiss
        case pop(to: UIViewController.Type)
    }

    private var onDisappear: () -> Void = {}

    public convenience init<Content: View> (
        rootView: Content,
        dismissalMode: DismissalMode = .modalDismiss,
        isModalInPresentation: Bool = true,
        onDisappear: @escaping () -> Void = {},
        colorPalette: LoopUIColorPalette
    ) {
        self.init(rootView: rootView,
                  dismissalMode: dismissalMode,
                  isModalInPresentation: isModalInPresentation,
                  onDisappear: onDisappear,
                  guidanceColors: colorPalette.guidanceColors,
                  carbTintColor: colorPalette.carbTintColor,
                  glucoseTintColor: colorPalette.glucoseTintColor,
                  insulinTintColor: colorPalette.insulinTintColor)
    }

    public convenience init<Content: View>(
        rootView: Content,
        dismissalMode: DismissalMode = .modalDismiss,
        isModalInPresentation: Bool = true,
        onDisappear: @escaping () -> Void = {},
        guidanceColors: GuidanceColors = GuidanceColors(),
        carbTintColor: Color = .green,
        glucoseTintColor: Color = Color(.systemTeal),
        insulinTintColor: Color = .orange
    ) {
        // Delay initialization of dismissal closure pushed into SwiftUI Environment until after calling the designated initializer
        var dismiss = {}
        self.init(rootView: AnyView(rootView.environment(\.dismissAction, { dismiss() })
            .environment(\.guidanceColors, guidanceColors)
            .environment(\.carbTintColor, carbTintColor)
            .environment(\.glucoseTintColor, glucoseTintColor)
            .environment(\.insulinTintColor, insulinTintColor)))

        switch dismissalMode {
        case .modalDismiss:
            dismiss = { [weak self] in self?.dismiss(animated: true) }
        case .pop(to: let PredecessorViewController):
            dismiss = { [weak self] in
                guard
                    let navigationController = self?.navigationController,
                    let predecessor = navigationController.viewControllers.last(where: { $0.isKind(of: PredecessorViewController) })
                else {
                    return
                }

                navigationController.popToViewController(predecessor, animated: true)
            }
        }

        self.onDisappear = onDisappear
        self.isModalInPresentation = isModalInPresentation
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDisappear()
    }
}
