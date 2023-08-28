//
//  DismissibleHostingController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/7/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct _DismissibleHostingView<Content: View>: View {
    
    let content: Content
    let guidanceColors: GuidanceColors
    let carbTintColor: Color
    let glucoseTintColor: Color
    let insulinTintColor: Color
    
    public var dismiss: () -> Void = {}
    
    public init(
        content: Content,
        guidanceColors: GuidanceColors,
        carbTintColor: Color,
        glucoseTintColor: Color,
        insulinTintColor: Color
    ) {
        self.content = content
        self.guidanceColors = guidanceColors
        self.carbTintColor = carbTintColor
        self.glucoseTintColor = glucoseTintColor
        self.insulinTintColor = insulinTintColor
    }
    
    public var body: some View {
        content
            .environment(\.dismissAction, dismiss)
            .environment(\.guidanceColors, guidanceColors)
            .environment(\.carbTintColor, carbTintColor)
            .environment(\.glucoseTintColor, glucoseTintColor)
            .environment(\.insulinTintColor, insulinTintColor)
    }
}

public class DismissibleHostingController<Content: View>: UIHostingController<_DismissibleHostingView<Content>> {
    public enum DismissalMode {
        case modalDismiss
        case pop(to: UIViewController.Type)
    }

    private var onDisappear: () -> Void = {}

    public convenience init (
        content: Content,
        dismissalMode: DismissalMode = .modalDismiss,
        isModalInPresentation: Bool = true,
        onDisappear: @escaping () -> Void = {},
        colorPalette: LoopUIColorPalette
    ) {
        self.init(content: content,
                  dismissalMode: dismissalMode,
                  isModalInPresentation: isModalInPresentation,
                  onDisappear: onDisappear,
                  guidanceColors: colorPalette.guidanceColors,
                  carbTintColor: colorPalette.carbTintColor,
                  glucoseTintColor: colorPalette.glucoseTintColor,
                  insulinTintColor: colorPalette.insulinTintColor)
    }

    public convenience init(
        content: Content,
        dismissalMode: DismissalMode = .modalDismiss,
        isModalInPresentation: Bool = true,
        onDisappear: @escaping () -> Void = {},
        guidanceColors: GuidanceColors = GuidanceColors(),
        carbTintColor: Color = .green,
        glucoseTintColor: Color = Color(.systemTeal),
        insulinTintColor: Color = .orange
    ) {
        let view = _DismissibleHostingView(
            content: content,
            guidanceColors: guidanceColors,
            carbTintColor: carbTintColor,
            glucoseTintColor: glucoseTintColor,
            insulinTintColor: insulinTintColor
        )
        
        // Delay initialization of dismissal closure pushed into SwiftUI Environment until after calling the designated initializer
        self.init(rootView: view)

        switch dismissalMode {
        case .modalDismiss:
            self.rootView.dismiss = { [weak self] in self?.dismiss(animated: true) }
        case .pop(to: let PredecessorViewController):
            self.rootView.dismiss = { [weak self] in
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
