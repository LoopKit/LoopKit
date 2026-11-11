//
//  RenameTherapyProfileEditor.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit

struct RenameTherapyProfileEditor: View {
    @Binding var isPresented: Bool
    let originalName: String
    @ObservedObject var viewModel: TherapyProfilesViewModel
    @Environment(\.guidanceColors) private var guidanceColors
    let didRename: () -> Void
    @State private var newProfileName: String = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            ModalHeaderButtonBar(
                leading: { cancelButton },
                center: {
                    Text(LocalizedString("Rename Profile", comment: "Title of the rename profile editor"))
                        .font(.subheadline)
                },
                trailing: { renameButton }
            )
            .onAppear {
                newProfileName = originalName
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField(LocalizedString("Profile Name", comment: "Placeholder of the profile name field"), text: $newProfileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .accessibilityIdentifier("textField_RenameProfile")
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

    var renameButton: some View {
        Button(
            action: {
                let trimmed = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed != originalName else {
                    withAnimation { isPresented = false }
                    return
                }
                isSaving = true
                Task {
                    do {
                        try await viewModel.renameProfile(originalName, to: trimmed)
                        isSaving = false
                        withAnimation { isPresented = false }
                        didRename()
                    } catch {
                        isSaving = false
                        errorMessage = error.localizedDescription
                    }
                }
            }, label: {
                Text(LocalizedString("Rename", comment: "Button to rename a therapy profile"))
            }
        )
        .disabled(isSaving)
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
