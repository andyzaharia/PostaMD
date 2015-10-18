//
//  NSManagedObjectContext+CloudKit.h
//  PostaMD
//
//  Created by Andrei Zaharia on 10/18/15.
//  Copyright © 2015 Andrei Zaharia. All rights reserved.
//

#import <CoreData/CoreData.h>

typedef void (^OnCloudKitOperationCompleted)(NSError *error);

@interface NSManagedObjectContext (CloudKit)

-(void) cloudKitDeleteObject: (NSManagedObject *) object andRecordNameProperty: (NSString *) recordName completion: (OnCloudKitOperationCompleted) completionHandler;

@end
