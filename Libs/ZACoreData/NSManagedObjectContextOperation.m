//
//  NSManagedObjectContextOperation.m
//  
//
//  Created by Andrei Zaharia on 7/31/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "NSManagedObjectContextOperation.h"

@interface NSManagedObjectContextOperation ()
{
    NSPersistentStoreCoordinator    *_persistentStoreCoordinator;
    NSManagedObjectContext          *_context;
}

@end

@implementation NSManagedObjectContextOperation

-(id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    
    NSParameterAssert(persistentStoreCoordinator);
    self = [super init];
    if (self == nil) return nil;
    
    _persistentStoreCoordinator = persistentStoreCoordinator;
    
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    context.persistentStoreCoordinator = persistentStoreCoordinator;
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
    
    _context = context;
    return self;
}

-(void)main {
    
    @autoreleasepool {
        
        if (!self.isCancelled) {
            [_context performBlock:^{
                
                _operationBlock(_context);
            
                if ([_context hasChanges]) {
                    
                    //[_persistentStoreCoordinator lock];
                    
                    NSError *saveError;
                    if (![_context save:&saveError]) {
                        //Handle saveError. It may be simplest to report failure and let the calling callback enqueue a new operation.
                    }
                    
                    //[_persistentStoreCoordinator unlock];
                }
                
                if (self.onOperationCompleted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.onOperationCompleted();
                    });
                }
            }];
        }
    }
}

@end
