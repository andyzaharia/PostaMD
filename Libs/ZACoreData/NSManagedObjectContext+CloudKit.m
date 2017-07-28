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

-(void) cloudKitDeleteObject {

    CKContainer *container = [CKContainer defaultContainer];
    CKDatabase *privateDB = [container privateCloudDatabase];

    CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName: @"DS2000330803AS"];

    CKModifyRecordsOperation *operation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave: nil recordIDsToDelete: @[recordID]];
    operation.database = privateDB;

    [operation setModifyRecordsCompletionBlock:^(NSArray<CKRecord *> * _Nullable savedRecords,
                                             NSArray<CKRecordID *> * _Nullable deletedRecordIDs,
                                             NSError * _Nullable error) {

        CKFetchRecordsOperation *fetchOperation = [[CKFetchRecordsOperation alloc] initWithRecordIDs:@[recordID]];
        fetchOperation.database = privateDB;
        [fetchOperation setPerRecordCompletionBlock:^(CKRecord * _Nullable record, CKRecordID * _Nullable recordID, NSError * _Nullable error){
            NSLog(@"Error: %@", error.localizedDescription);
        }];
    }];
}


-(void) cloudKitDeleteObject: (NSManagedObject *) object
       andRecordNameProperty: (NSString *) recordName
                  completion: (OnCloudKitOperationCompleted) completionHandler
{
    NSString *recordNameValue = [object valueForKeyPath: recordName];
    if (recordNameValue) {
        if (recordNameValue.length > minTrackingNumberLength) {
            recordNameValue = [recordNameValue substringToIndex: minTrackingNumberLength];
        }

        CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName: recordNameValue];

        NSLog(@"RecordID to be deleted: %@", recordNameValue);

        NSString *containerIdentier = [DataLoader cloudKitContainerIdentifier];
        CKContainer *container = [CKContainer containerWithIdentifier: containerIdentier];
        CKDatabase *privateDB = [container privateCloudDatabase];

        [privateDB fetchRecordWithID:recordID
                   completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {

                       if ((error == nil) && record) {
                           record[@"isDeleted"] = @(1);

                           CKModifyRecordsOperation *operation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave: @[record]
                                                                                                       recordIDsToDelete: @[recordID]];
                           operation.qualityOfService = NSQualityOfServiceUserInitiated;
                           operation.database = privateDB;

                           [operation setModifyRecordsCompletionBlock:^(NSArray<CKRecord *> * _Nullable savedRecords,
                                                                        NSArray<CKRecordID *> * _Nullable deletedRecordIDs,
                                                                        NSError * _Nullable error) {
                               if (error == nil) {

                                   [deletedRecordIDs enumerateObjectsUsingBlock:^(CKRecordID * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                       if ([recordID isEqual: obj]) {
                                           // Execute the block on the receiver's queue.
                                           [self performBlock:^{
                                               [self deleteObject: object];
                                               [self recursiveSave]; // Would be nice to handle this
                                           }];
                                       }
                                   }];
                               } else {
                                   NSLog(@"Error: %@", error.localizedDescription);
                               }
                           }];
                           
                           [operation setCompletionBlock:^{
                               [self performBlock:^{
                                   if (completionHandler) completionHandler(nil);
                               }];
                           }];
                           
                           [privateDB addOperation: operation];
                       } else {
                           // Failed.
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
