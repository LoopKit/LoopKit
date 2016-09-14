//
//  Fetchable.swift
//  Naterade
//
//  Based on https://gist.github.com/capttaco/adb38e0d37fbaf9c004e
//  See http://martiancraft.com/blog/2015/07/objective-c-swift-core-data/
//


import CoreData


protocol Fetchable {
    associatedtype FetchableType: NSManagedObject = Self

    static func entityName() -> String
    static func objectsInContext(_ context: NSManagedObjectContext, predicate: NSPredicate?, sortedBy: String?, ascending: Bool) throws -> [FetchableType]
    static func singleObjectInContext(_ context: NSManagedObjectContext, predicate: NSPredicate?, sortedBy: String?, ascending: Bool) throws -> FetchableType?
    static func objectCountInContext(_ context: NSManagedObjectContext, predicate: NSPredicate?) throws -> Int
    static func fetchRequest(_ context: NSManagedObjectContext, predicate: NSPredicate?, sortedBy: String?, ascending: Bool) -> NSFetchRequest<FetchableType>
}


extension Fetchable where Self : NSManagedObject, FetchableType == Self {

    static func entityName() -> String {
        if #available(iOS 10.0, *) {
            return self.entity().name!
        } else {
            return NSStringFromClass(self).components(separatedBy: ".").last!
        }
    }

    static func singleObjectInContext(_ context: NSManagedObjectContext, predicate: NSPredicate? = nil, sortedBy: String? = nil, ascending: Bool = false) -> FetchableType? {
        let managedObjects: [FetchableType]? = try? objectsInContext(context, predicate: predicate, sortedBy: sortedBy, ascending: ascending)

        return managedObjects?.first
    }

    static func objectCountInContext(_ context: NSManagedObjectContext, predicate: NSPredicate? = nil) throws -> Int {
        let request = fetchRequest(context, predicate: predicate)
        return try context.count(for: request)
    }

    static func objectsInContext(_ context: NSManagedObjectContext, predicate: NSPredicate? = nil, sortedBy: String? = nil, ascending: Bool = false) throws -> [FetchableType] {
        let request = fetchRequest(context, predicate: predicate, sortedBy: sortedBy, ascending: ascending)
        return try context.fetch(request)
    }

    static func fetchRequest(_ context: NSManagedObjectContext, predicate: NSPredicate? = nil, sortedBy: String? = nil, ascending: Bool = false) -> NSFetchRequest<FetchableType> {
        let request = NSFetchRequest<FetchableType>()

        request.entity = NSEntityDescription.entity(forEntityName: entityName(), in: context)
        request.predicate = predicate

        if (sortedBy != nil) {
            let sort = NSSortDescriptor(key: sortedBy, ascending: ascending)
            let sortDescriptors = [sort]
            request.sortDescriptors = sortDescriptors
        }

        return request
    }

    static func insertNewObjectInContext(_ context: NSManagedObjectContext) -> FetchableType {

        return NSEntityDescription.insertNewObject(forEntityName: entityName(), into: context) as! FetchableType
    }
}
