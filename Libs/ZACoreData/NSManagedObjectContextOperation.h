//
//  NSManagedObjectContextOperation.h
//
//  Created by Andrei Zaharia on 7/31/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^CoreDataOperationBlock)(NSManagedObjectContext * moc);
typedef void (^OnOperationCompleted)(void);

@interface NSManagedObjectContextOperation : NSOperation

@property (nonatomic, copy) CoreDataOperationBlock operationBlock;
@property (nonatomic, copy) OnOperationCompleted   onOperationCompleted;

-(id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@end
