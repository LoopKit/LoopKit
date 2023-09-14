//
//  RenameProfileEditor.swift
//  LoopKitUI
//
//  Created by Jonas Björkert on 2023-09-07.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI

struct RenameProfileEditor: View {
    @Binding var isPresented: Bool
    @State var currentProfileName: String
    @State var newProfileName: String = ""
    var viewModel: ProfileViewModel
    @State private var showAlert = false
    @Binding var shouldDismissParent: Bool

    var body: some View {
        VStack(spacing: 0) {
            ModalHeaderButtonBar(
                leading: { cancelButton },
                center: {
                    Text("Rename Profile")
                        .font(.subheadline)

                },
                trailing: { renameButton }
            )
            .onAppear {
                self.newProfileName = currentProfileName
            }
            
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
                    self.viewModel.renameProfile(oldName: currentProfileName, newName: self.newProfileName)
                    self.shouldDismissParent = true
                    self.isPresented = false
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    var renameButton: some View {
        Button(
            action: {
                withAnimation {
                    guard newProfileName != currentProfileName else {
                        self.isPresented = false
                        return
                    }

                    if viewModel.doesProfileExist(withName: self.newProfileName) {
                        self.showAlert = true
                    } else {
                        self.viewModel.renameProfile(oldName: currentProfileName, newName: self.newProfileName)
                        self.shouldDismissParent = true
                        self.isPresented = false
                    }
                }
            }, label: {
                Text("Rename")
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
