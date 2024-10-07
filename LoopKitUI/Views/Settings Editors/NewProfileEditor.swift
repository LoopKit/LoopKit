//
//  NewProfileEditor.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-05-19.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

struct NewProfileEditor: View {
    @Binding var isPresented: Bool
    @State var newProfileName: String
    var viewModel: ProfileViewModel
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 0) {
            ModalHeaderButtonBar(
                leading: { cancelButton },
                center: {
                    Text("New Profile")
                        .font(.headline)
                },
                trailing: { addButton }
            )

            TextField("Profile Name", text: $newProfileName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .background(
                    RoundedCorners(radius: 10, corners: [.bottomLeft, .bottomRight])
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
        .padding(.horizontal)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Overwrite Existing Profile"),
                message: Text("A profile with this name already exists. Would you like to overwrite it?"),
                primaryButton: .destructive(Text("Overwrite")) {
                    self.viewModel.saveProfile(withName: self.newProfileName)
                    self.isPresented = false
                },
                secondaryButton: .cancel()
            )
        }
    }

    var addButton: some View {
        Button(
            action: {
                withAnimation {
                    if viewModel.doesProfileExist(withName: self.newProfileName) {
                        self.showAlert = true
                    } else {
                        self.viewModel.saveProfile(withName: self.newProfileName)
                        self.isPresented = false
                    }
                }
            }, label: {
                Text("Add")
            }
        )
    }

    var cancelButton: some View {
        Button(
            action: {
                withAnimation {
                    self.isPresented = false
                }
            }, label: {
                Text("Cancel")
            }
        )
    }
}
