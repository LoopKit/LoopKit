//
//  DeletedCarbObject+CoreDataProperties.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


extension DeletedCarbObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DeletedCarbObject> {
        return NSFetchRequest<DeletedCarbObject>(entityName: "DeletedCarbObject")
    }

    @NSManaged public var externalID: String?
    @NSManaged public var primitiveUploadState: NSNumber?
    @NSManaged public var startDate: NSDate?

}
