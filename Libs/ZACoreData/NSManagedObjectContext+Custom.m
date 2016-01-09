//
//  NSManagedObjectContext+Custom.m
//  
//
//  Created by Andrei Zaharia on 9/18/13.
//  Copyright (c) 2013 Andy. All rights reserved.
//

#import "NSManagedObjectContext+Custom.h"

@implementation NSManagedObjectContext (Custom)

static NSManagedObjectContext   *_masterPrivateContext = nil;
static NSMutableDictionary      *_managedObjectContextsDictionary = nil;
static NSOperationQueue         *_operationQueue;


+ (NSString *) generateGUID
{
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    NSString *uuid = [NSString stringWithString:(__bridge NSString *) uuidStringRef];
    CFRelease(uuidStringRef);
    return uuid;
}

+ (NSManagedObjectContext *) masterWriterPrivateContext
{
    if (!_masterPrivateContext) {
        _masterPrivateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
        _masterPrivateContext.persistentStoreCoordinator = [NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator];
    }
    
    return _masterPrivateContext;
}

+ (void) setContextForMainThread: (NSManagedObjectContext *) context
{
    NSThread *thread = [NSThread mainThread];
    if (![[thread name] length]) {
        [thread setName: [NSManagedObjectContext generateGUID]];
    }
    
    [_managedObjectContextsDictionary setObject:context forKey: [thread name]];
}

+ (NSManagedObjectContext *) contextForMainThread
{
    if(![NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator]) return nil;
    
    if (!_managedObjectContextsDictionary) {
        _managedObjectContextsDictionary = [[NSMutableDictionary alloc] init];
    }
    
    NSThread *thread = [NSThread mainThread];

    //NSAssert([[NSThread currentThread] isEqual: thread], @"Cannot access main thread context from a separate thread");
    
    if (![[thread name] length]) {
        [thread setName: [NSManagedObjectContext generateGUID]];
        
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
        context.persistentStoreCoordinator = [NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator];
        [context setMergePolicy: NSMergeByPropertyObjectTrumpMergePolicy];
        
        [_managedObjectContextsDictionary setObject:context forKey: [thread name]];
        
        __weak NSManagedObjectContext *weakCtxRef = context;
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserverForName: NSManagedObjectContextDidSaveNotification
                                        object: nil //context.persistentStoreCoordinator, we where not receiving notifications from performSaveOperationWithBlock:
                                         queue: [NSOperationQueue mainQueue]
                                    usingBlock:^(NSNotification *note) {
                                        
                                        NSManagedObjectContext *savedContext = [note object];
                                        if (savedContext == weakCtxRef) {
                                            return;
                                        }
                                        
                                        if (savedContext.persistentStoreCoordinator != [NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator]) {
                                            return;
                                        }
                                        
                                        if (savedContext == [NSManagedObjectContext contextForMainThread]) {
                                            return;
                                        }
                                        
                                        NSArray *updatedObjects = note.userInfo[NSUpdatedObjectsKey];
                                        NSArray *insertedObjects = note.userInfo[NSInsertedObjectsKey];
                                        NSArray *deletedObjects = note.userInfo[NSDeletedObjectsKey];
                                        
                                        //NSLog(@"DidSave: Inserted(%d) Deleted(%d) Updated(%d)", [insertedObjects count], [deletedObjects count], [updatedObjects count]);
                                        
                                        if ([updatedObjects count] || [insertedObjects count] || [deletedObjects count]) {
                                            [weakCtxRef performBlock:^{
                                                
                                                // http://stackoverflow.com/questions/3923826/nsfetchedresultscontroller-with-predicate-ignores-changes-merged-from-different                                                
                                                dispatch_async(dispatch_get_main_queue(), ^(void){
                                                    for (NSManagedObject *object in [[note userInfo] objectForKey:NSUpdatedObjectsKey]) {
                                                        [[weakCtxRef objectWithID:[object objectID]] willAccessValueForKey:nil];
                                                    }
                                                    
                                                    [weakCtxRef mergeChangesFromContextDidSaveNotification: note];
                                                });
                                            }];
                                        }

        }];
        return context;
    } else {
        return [_managedObjectContextsDictionary objectForKey: [thread name]];
    }
}

+ (NSManagedObjectContext *) contextForCurrentThread
{    
    if(![NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator]) return nil;
    
    if (!_managedObjectContextsDictionary) {
        _managedObjectContextsDictionary = [[NSMutableDictionary alloc] init];
    }
    
    // Force the return of the main thread context.
    if ([NSThread isMainThread]) {
        return [NSManagedObjectContext contextForMainThread];
    }

    NSThread *currentThread = [NSThread currentThread];
    if (![[currentThread name] length]) {
        [currentThread setName: [NSManagedObjectContext generateGUID]];
        
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
        context.parentContext = [NSManagedObjectContext contextForMainThread];
        context.undoManager = nil;
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        
         @synchronized(_managedObjectContextsDictionary) {
            [_managedObjectContextsDictionary setObject:context forKey: [currentThread name]];
         }
        
        return context;
    } else {
        return [_managedObjectContextsDictionary objectForKey: [currentThread name]];
    }
}

+ (NSManagedObjectContext *) privateManagedContext
{
    if(![NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator]) return nil;
    
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
    context.parentContext = [NSManagedObjectContext contextForMainThread];
    context.undoManager = nil;
    
    return context;
}

+ (void) cleanContextsForCurrentThread
{
    if (_managedObjectContextsDictionary) {
        NSThread *currentThread = [NSThread currentThread];
        if ([[currentThread name] length]) {
            [_managedObjectContextsDictionary removeObjectForKey: [currentThread name]];
        }
    }
}

+ (NSManagedObjectContext *) contextForBackgroundThread
{
    @synchronized(_managedObjectContextsDictionary) {
        
        if(![NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator]) return nil;
        
        static NSString *backgroundThreadContextKey = @"backgroundThreadContextKey";
        
        NSManagedObjectContext *backgroundContext = [_managedObjectContextsDictionary objectForKey: backgroundThreadContextKey];
        
        if (!backgroundContext) {
            backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            backgroundContext.parentContext = [NSManagedObjectContext contextForMainThread];
            [backgroundContext setMergePolicy: NSMergeByPropertyObjectTrumpMergePolicy];
            backgroundContext.undoManager = nil;
        }
        
        return backgroundContext;
    }
}

+(void) resetStack
{
    _masterPrivateContext = nil;
    
    if (_managedObjectContextsDictionary) {
        [_managedObjectContextsDictionary removeAllObjects];
    }
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name: NSManagedObjectContextDidSaveNotification object: nil];
    
    NSThread *thread = [NSThread mainThread];
    [thread setName:@""];
    
    [_operationQueue cancelAllOperations];
}

#pragma mark - ObjectWith

- (NSManagedObject *)objectWithURI:(NSURL *)uri
{
    NSManagedObjectContext *moc = self;
    
    NSManagedObjectID *objectID = [[moc persistentStoreCoordinator] managedObjectIDForURIRepresentation:uri];
    
    if (!objectID) {
        return nil;
    }
    
    NSManagedObject *objectForID = [moc objectWithID:objectID];
    if (![objectForID isFault]) {
        return objectForID;
    }
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[objectID entity]];
    
    // Equivalent to
    // predicate = [NSPredicate predicateWithFormat:@"SELF = %@", objectForID];
    NSPredicate *predicate = [NSComparisonPredicate predicateWithLeftExpression: [NSExpression expressionForEvaluatedObject]
                                                                rightExpression: [NSExpression expressionForConstantValue:objectForID]
                                                                       modifier: NSDirectPredicateModifier
                                                                           type: NSEqualToPredicateOperatorType
                                                                        options: 0];
    [request setPredicate:predicate];
    
    NSArray *results = [moc executeFetchRequest:request error:nil];
    if ([results count] > 0) {
        return [results objectAtIndex:0];
    }
    
    return nil;
}

#pragma mark -

+ (void) performSaveOperationWithBlock: (CoreDataOperationBlock) block onSaved: (OnSaved) onSaved
{
    if (!_operationQueue) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;
    }
    
    if (!_operationQueue) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;
    }
    
    NSPersistentStoreCoordinator *store = [NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator];
    NSManagedObjectContextOperation *operation = [[NSManagedObjectContextOperation alloc] initWithPersistentStoreCoordinator: store];
    operation.operationBlock = block;
    operation.onOperationCompleted = onSaved;
    
    [_operationQueue addOperation: operation];
}

+ (void) performSaveOperationWithBlock: (CoreDataOperationBlock) block
{
    [self performSaveOperationWithBlock:block onSaved: nil];
}

@end
