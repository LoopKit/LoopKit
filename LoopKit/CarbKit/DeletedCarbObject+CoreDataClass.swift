//
//  DeletedCarbObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


class DeletedCarbObject: NSManagedObject {
    var uploadState: UploadState {
        get {
            willAccessValue(forKey: "uploadState")
            defer { didAccessValue(forKey: "uploadState") }
            return UploadState(rawValue: primitiveUploadState!.intValue)!
        }
        set {
            willChangeValue(forKey: "uploadState")
            defer { didChangeValue(forKey: "uploadState") }
            primitiveUploadState = NSNumber(value: newValue.rawValue)
        }
    }
}
