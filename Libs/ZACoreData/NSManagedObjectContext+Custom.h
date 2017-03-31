//
//  NSManagedObjectContext+Custom.h
//  
//
//  Created by Andrei Zaharia on 9/18/13.
//  Copyright (c) 2013 Andy. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "NSManagedObjectContextOperation.h"

typedef void (^OnSaved)(void);

@interface NSManagedObjectContext (Custom)

+ (void) setContextForMainThread: (NSManagedObjectContext *) context;
+ (NSManagedObjectContext *) contextForMainThread;
+ (NSManagedObjectContext *) contextForCurrentThread;
+ (void) cleanContextsForCurrentThread;

+ (NSManagedObjectContext *) privateManagedContext;
+ (NSManagedObjectContext *) contextForBackgroundThread;
+ (NSManagedObjectContext *) masterWriterPrivateContext;

+ (void) resetStack;

- (NSManagedObject *)objectWithURI:(NSURL *)uri;

-(void) recursiveSave;

// Background Operations
+ (void) performSaveOperationWithBlock: (CoreDataOperationBlock) block onSaved: (OnSaved) onSaved;
+ (void) performSaveOperationWithBlock: (CoreDataOperationBlock) block;

@end
