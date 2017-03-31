//
//  NSManagedObjectContext+CloudKit.m
//  PostaMD
//
//  Created by Andrei Zaharia on 10/18/15.
//  Copyright © 2015 Andrei Zaharia. All rights reserved.
//

#import "NSManagedObjectContext+CloudKit.h"
#import <CloudKit/CloudKit.h>
#import "DataLoader.h"

@implementation NSManagedObjectContext (CloudKit)

-(void) cloudKitDeleteObject: (NSManagedObject *) object andRecordNameProperty: (NSString *) recordName completion: (OnCloudKitOperationCompleted) completionHandler
{
    NSString *containerIdentier = [DataLoader cloudKitContainerIdentifier];
    CKDatabase *privateDB = [[CKContainer containerWithIdentifier: containerIdentier] privateCloudDatabase];
    
    NSString *recordNameValue = [object valueForKeyPath: recordName];
    if (recordNameValue) {
        if (recordNameValue.length > minTrackingNumberLength) {
            recordNameValue = [recordNameValue substringToIndex: minTrackingNumberLength];
        }
        
        CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName: recordNameValue];
        [privateDB deleteRecordWithID:recordID
                    completionHandler:^(CKRecordID * _Nullable recordID, NSError * _Nullable error) {
                        if (error) {
                            if (completionHandler) completionHandler(error);
                        } else {
                            [self performBlockAndWait:^{
                                [self deleteObject: object];
                                [self recursiveSave]; // Would be nice to handle this
                            }];
                            if (completionHandler) completionHandler(nil);
                        }
                    }];
    } else {
        //Failed, handle failure
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid value for record name %@", recordName] };
        if (completionHandler) completionHandler([NSError errorWithDomain:@"CloudKit" code:-1 userInfo: userInfo]);
    }
}

@end
