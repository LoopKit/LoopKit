//
//  Prescription.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

public protocol Prescription {
    /// Date prescription was prescribed
    var datePrescribed: Date { get }
    /// Name of clinician prescribing
    var providerName: String { get }
}
