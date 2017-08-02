//
//  Package.m
//  PostaMD
//
//  Created by Andrei Zaharia on 4/8/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "Package.h"
#import "TrackingInfo.h"
#import "Package+CoreDataProperties.h"
#import "NSManagedObjectContext+CloudKit.h"
#import "UIAlertController+Alert.h"
#import <CloudKit/CloudKit.h>
#import "DataLoader.h"

@implementation Package

+(void) deleteWithItem:(Package *) item onCompletion: (OnDeleteCompleted) onCompletion
{
    NSString *containerIdentier = [DataLoader cloudKitContainerIdentifier];
    CKContainer *container = [CKContainer containerWithIdentifier: containerIdentier];
    CKDatabase *privateDB = [container privateCloudDatabase];

    NSManagedObjectID *packageObjectID = item.objectID;

    if (item.cloudID.length > 0) {
        CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName: item.cloudID];

        CKFetchRecordsOperation *fetchOperation = [[CKFetchRecordsOperation alloc] initWithRecordIDs: @[recordID]];
        fetchOperation.database = privateDB;
        [fetchOperation setPerRecordCompletionBlock:^(CKRecord * _Nullable record, CKRecordID * _Nullable recordID, NSError * _Nullable error){

            if ((error == nil) && record) {
                record[@"isDeleted"] = @(1);

                CKModifyRecordsOperation *operation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave: @[record]
                                                                                            recordIDsToDelete: nil];
                operation.qualityOfService = NSQualityOfServiceUserInitiated;
                operation.database = privateDB;

                [operation setModifyRecordsCompletionBlock:^(NSArray<CKRecord *> * _Nullable savedRecords,
                                                             NSArray<CKRecordID *> * _Nullable deletedRecordIDs,
                                                             NSError * _Nullable error) {
                    if (error == nil) {

                        CKModifyRecordsOperation *operation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave: nil
                                                                                                    recordIDsToDelete: @[recordID]];
                        operation.qualityOfService = NSQualityOfServiceUserInitiated;
                        operation.database = privateDB;

                        [operation setModifyRecordsCompletionBlock:^(NSArray<CKRecord *> * _Nullable savedRecords,
                                                                     NSArray<CKRecordID *> * _Nullable deletedRecordIDs,
                                                                     NSError * _Nullable error) {

                            if (error == nil) {
                                __block BOOL didFinish = NO;

                                [deletedRecordIDs enumerateObjectsUsingBlock:^(CKRecordID * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                    if ([recordID isEqual: obj]) {
                                        // Execute the block on the receiver's queue.
                                        didFinish = YES;

                                        [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
                                            NSManagedObject *package = [moc objectWithID: packageObjectID];
                                            if (package) {
                                                [moc deleteObject:package];
                                            }
                                        } onSaved:^{
                                            if (onCompletion) onCompletion(nil);
                                        }];
                                    }
                                }];

                                if (didFinish == NO) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        if (onCompletion) onCompletion(nil);
                                    });
                                }

                            } else {
                                NSLog(@"Error: %@", error.localizedDescription);
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (onCompletion) onCompletion(error);
                                });
                            }

                        }];

                        [privateDB addOperation: operation];

                    } else {
                        NSLog(@"Error: %@", error.localizedDescription);

                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (onCompletion) onCompletion(error);
                        });
                    }
                }];

                [privateDB addOperation: operation];
            } else {
                // Failed.

                if (error.code == CKErrorUnknownItem) {
                    [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
                        NSManagedObject *package = [moc objectWithID: packageObjectID];
                        if (package) {
                            [moc deleteObject:package];
                        }
                    } onSaved:^{
                        if (onCompletion) onCompletion(nil);
                    }];
                } else {

                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (onCompletion) onCompletion(error);
                    });
                }
            }

        }];

        [privateDB addOperation: fetchOperation];
    } else {

        [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
            NSManagedObject *package = [moc objectWithID: packageObjectID];
            if (package) {
                [moc deleteObject:package];
            }
        } onSaved:^{
            if (onCompletion) onCompletion(nil);
        }];
    }
}

@end
