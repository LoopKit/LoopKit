//
//  NewTherapyProfileEditor.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit

/// Names a new profile, created from the active profile's settings.
struct NewTherapyProfileEditor: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: TherapyProfilesViewModel
    @Environment(\.guidanceColors) private var guidanceColors
    @State private var newProfileName = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            ModalHeaderButtonBar(
                leading: { cancelButton },
                center: {
                    Text(LocalizedString("New Profile", comment: "Title of the new profile editor"))
                        .font(.headline)
                },
                trailing: { addButton }
            )

            VStack(alignment: .leading, spacing: 8) {
                TextField(LocalizedString("Profile Name", comment: "Placeholder of the profile name field"), text: $newProfileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier("textField_ProfileName")
                Text(String(format: LocalizedString("The new profile starts with the settings of %1$@.", comment: "New profile hint (1: active profile name)"), viewModel.activeProfileName))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(guidanceColors.critical)
                }
            }
            .padding()
            .background(
                RoundedCorners(radius: 10, corners: [.bottomLeft, .bottomRight])
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .padding(.horizontal)
    }

    var addButton: some View {
        Button(
            action: {
                isSaving = true
                Task {
                    do {
                        try await viewModel.createProfile(named: newProfileName)
                        isSaving = false
                        withAnimation { isPresented = false }
                    } catch {
                        isSaving = false
                        errorMessage = error.localizedDescription
                    }
                }
            }, label: {
                Text(LocalizedString("Add", comment: "Button to add a profile"))
            }
        )
        .disabled(isSaving || newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityIdentifier("button_SaveNewProfile")
    }

    var cancelButton: some View {
        Button(
            action: {
                withAnimation {
                    isPresented = false
                }
            }, label: {
                Text(LocalizedString("Cancel", comment: "Button to cancel"))
            }
        )
    }
}
