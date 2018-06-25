//
//  NSManagedObjectContext.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData


extension NSManagedObjectContext {
    func all<T: NSManagedObject>() -> [T] {
        let request = NSFetchRequest<T>(entityName: T.entity().name!)
        return (try? fetch(request)) ?? []
    }
}
