//
//  InsulinType.swift
//  LoopKit
//
//  Created by Anna Quinlan on 12/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum InsulinType: Int, Codable {
    case aspart
    case lispro
    case glulisine
    case fiasp
    
    public var title: String {
        switch self {
        case .aspart:
            return LocalizedString("Insulin aspart (Novolog)", comment: "Title for insulin aspart insulin type")
        case .lispro:
            return LocalizedString("Insulin lispro (Humalog)", comment: "Title for insulin lispro insulin type")
        case .glulisine:
            return LocalizedString("Insulin glulisine (Apidra)", comment: "Title for insulin glulisine insulin type")
        case .fiasp:
            return LocalizedString("Fiasp", comment: "Title for fiasp insulin type")
        }
    }
}
