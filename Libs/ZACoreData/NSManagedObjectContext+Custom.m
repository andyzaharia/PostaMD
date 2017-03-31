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
        
        _masterPrivateContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        _masterPrivateContext.undoManager = nil;
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
    
    if (![[thread name] length]) {
        [thread setName: [NSManagedObjectContext generateGUID]];
        
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
        [context setParentContext: [NSManagedObjectContext masterWriterPrivateContext]];
        [context setMergePolicy: NSMergeByPropertyObjectTrumpMergePolicy];
        
        [_managedObjectContextsDictionary setObject:context forKey: [thread name]];
        
        return context;
    } else {
        NSManagedObjectContext *context = _managedObjectContextsDictionary[thread.name];
        return context;
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
    
    NSAssert([NSThread isMainThread], @"Cannot access %s from a background thread.", __PRETTY_FUNCTION__);
    
    NSThread *currentThread = [NSThread currentThread];
    if (![[currentThread name] length]) {
        [currentThread setName: [NSManagedObjectContext generateGUID]];
        
        //Main thread as parent context
        NSManagedObjectContext *mainThreadContext = _managedObjectContextsDictionary[[NSThread mainThread].name];
        NSAssert(mainThreadContext, @"Main thread cannot be nil.");
        
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
        context.parentContext = mainThreadContext;
        context.undoManager = nil;
        
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
    /* Must be removed. */
    
    @synchronized(_managedObjectContextsDictionary) {
        
        if(![NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator]) return nil;
        
        static NSString *backgroundThreadContextKey = @"backgroundThreadContextKey";
        
        NSManagedObjectContext *backgroundContext = [_managedObjectContextsDictionary objectForKey: backgroundThreadContextKey];
        
        if (!backgroundContext) {
            //Main thread as parent context
            NSManagedObjectContext *mainThreadContext = _managedObjectContextsDictionary[[NSThread mainThread].name];
            NSAssert(mainThreadContext, @"Main thread cannot be nil.");
            
            backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            backgroundContext.parentContext = mainThreadContext;
            //backgroundContext.persistentStoreCoordinator = [NSPersistentStoreCoordinator sharedPersisntentStoreCoordinator];
            //[backgroundContext setMergePolicy: NSMergeByPropertyObjectTrumpMergePolicy];
            backgroundContext.undoManager = nil;
            
            //[_managedObjectContextsDictionary setObject:backgroundContext forKey: backgroundThreadContextKey];
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

+ (void) performSaveOperationWithBlock: (CoreDataOperationBlock) block
{
    [self performSaveOperationWithBlock:block onSaved: nil];
}

+ (void) performSaveOperationWithBlock: (CoreDataOperationBlock) block onSaved: (OnSaved) onSaved
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
    [context setParentContext: [NSManagedObjectContext contextForMainThread]];
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [context performBlock:^{
        
        @try {
            block(context);
            
            [context recursiveSave];
            
        } @catch (NSException *exception) {
            NSLog(@"Exception: %@", exception);
        } @finally {
            if (onSaved) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    onSaved();
                });
            }
        }
    }];
}

+ (NSUInteger) operationsInQueue
{
    return _operationQueue.operationCount;
}

#pragma mark -

-(void) recursiveSave
{
    if ([self hasChanges]) {
        NSError *error;
        if([self save: &error]) {
            
            __block NSManagedObjectContext *parent = self.parentContext;
            while (parent != nil) {
                [parent performBlockAndWait:^{
                    if([parent hasChanges]) {
                        NSError *error;
                        if ([parent save:&error]) {
                            parent = parent.parentContext;
                        } else {
                            NSLog(@"Failed context save: %@", [error userInfo]);
                            parent = nil;
                        }
                    } else {
                        parent = nil;
                    }
                }];
            }
        } else {
            NSLog(@"Failed context save: %@", [error userInfo]);
        }
    }
}

@end
