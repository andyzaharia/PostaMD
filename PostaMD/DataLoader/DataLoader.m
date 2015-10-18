//
//  DataLoader.m
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "DataLoader.h"
#import "AFHTTPRequestOperationManager+Synchronous.h"
#import "PackageParser.h"

#import "NSManagedObjectContext+Custom.h"
#import <CloudKit/CloudKit.h>

@interface DataLoader ()
{
    NSOperationQueue                *_operationQueue;
}

@property (nonatomic, strong)       CKDatabase       *privateDB;
@property (nonatomic, strong)       NSOperationQueue *cloudKitQueue;

@end

@implementation DataLoader

+(id) shared
{
    static dispatch_once_t onceQueue;
    static DataLoader *dataLoader = nil;
    
    dispatch_once(&onceQueue, ^{ dataLoader = [[self alloc] init]; });
    return dataLoader;
}

-(id) init
{
    self = [super init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        [_operationQueue setMaxConcurrentOperationCount: 2];
        
        self.privateDB = [[CKContainer defaultContainer] privateCloudDatabase];
        self.cloudKitQueue = [[NSOperationQueue alloc] init];
        
        [self syncWithCloudKit];
    }
    return self;
}

-(void) getTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    NSDictionary *parameters = @{@"itemid": trackID};
    NSString *path = [NSString stringWithFormat: @"http://www.posta.md/ro/tracking?id=%@", trackID];
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
        
        NSError *error = nil;
        NSData *data = [manager syncPOST: path
                              parameters: parameters
                               operation: NULL
                                   error: &error];
        
        if (data) {
            NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
            [context performBlock:^{
                
                Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: context];
                NSInteger initialEventsCount = [package.info count];
                
                [PackageParser parsePackageTrackingInfoWithData: data
                                              andTrackingNumber: trackID
                                                      inContext: context];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSManagedObjectContext *ctx = [NSManagedObjectContext contextForMainThread];
                    
                    Package *pkg = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: ctx];
                    [ctx refreshObject:pkg mergeChanges: YES];
                    
                    NSInteger afterUpdateEventsCount = [pkg.info count];
                    
                    if (onDone) {
                        onDone(@(initialEventsCount < afterUpdateEventsCount));
                    }
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                //Run UI Updates
                if (onFailure) {
                    onFailure(error);
                }
            });
        }
    });
}

-(void) getTrackingInfoForItems: (NSArray *) trackingNumbers
                         onDone: (OnFetchSuccessEx) onDone
                      onFailure: (OnFailure) onFailure
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
    [context performBlock:^{
        
        __block BOOL                 _stoppedWithError      = NO;
        __block NSMutableArray      *_packagesWithUpdates   = [NSMutableArray array];
        __block NSMutableDictionary *_packageEventsDic      = [NSMutableDictionary dictionary];
        
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
        
        [trackingNumbers enumerateObjectsUsingBlock:^(NSString *trackingId, NSUInteger idx, BOOL *stop) {
            
            NSDictionary *parameters = @{@"itemid": trackingId};
            NSString *path = [NSString stringWithFormat: @"http://www.posta.md/ro/tracking?id=%@", trackingId];
            
            NSError *error = nil;
            NSData *data = [manager syncPOST: path
                                  parameters: parameters
                                   operation: NULL
                                       error: &error];
            
            if (data) {
                NSArray *freshEvents = [PackageParser parsePackageTrackingInfoWithData: data
                                                                     andTrackingNumber: trackingId
                                                                             inContext: context];
                
                if ([freshEvents count]) {
                    Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackingId inContext: context];
                    [_packagesWithUpdates addObject: package];
                    [_packageEventsDic setObject: freshEvents forKey: trackingId];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSManagedObjectContext *ctx = [NSManagedObjectContext contextForMainThread];
                        Package *pkg = [Package findFirstByAttribute:@"trackingNumber" withValue: trackingId inContext: ctx];
                        [ctx refreshObject:pkg mergeChanges: YES];
                    });
                }
            } else {
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (onFailure) {
                            onFailure(error);
                        }
                    });
                    
                    _stoppedWithError = YES;
                    *stop = YES;
                }
            }
        }];
        
        if (!_stoppedWithError) {
            dispatch_async(dispatch_get_main_queue(), ^(void){
                if (onDone) {
                    onDone(_packageEventsDic);
                }
            });
        }
    }];
}

#pragma mark - Sync

-(void) syncWithCloudKit
{
    CKDatabase *privateDB = [[CKContainer defaultContainer] privateCloudDatabase];
    
    NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
    [context performBlock:^{
        
        NSMutableArray *operations = [NSMutableArray array];
        __block NSOperation *_lastOperation = nil;
        
        
        // Check the existing packages for cloudID presence on local side.
        // if a package has a cloudID but that id is missing in Cloud then we must delete the local one.
        //
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"length(cloudID) > 0"];
        NSArray *packages = [Package findAllWithPredicate:predicate inContext: context];
        NSArray *localPackageTrackingNumbers = [packages valueForKeyPath:@"cloudID"];
        if (packages.count) {
            predicate = [NSPredicate predicateWithFormat:@"(trackingNumber IN %@)", localPackageTrackingNumbers];
            
            CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Package" predicate:predicate];
            CKQueryOperation *fetchOperation = [[CKQueryOperation alloc] initWithQuery: query];
            
            __block NSMutableArray *packagesToDelete = [localPackageTrackingNumbers mutableCopy];
            [fetchOperation setRecordFetchedBlock:^(CKRecord * _Nonnull record) {
                NSString *trackingNumber = record[@"trackingNumber"];
                [packagesToDelete removeObject: trackingNumber];
            }];
            
            [fetchOperation setQueryCompletionBlock:^(CKQueryCursor * _Nullable cursor, NSError * _Nullable error) {
                if (!error && packagesToDelete.count) {
                    [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
                        [packagesToDelete enumerateObjectsUsingBlock:^(NSString *trackingNumber, NSUInteger idx, BOOL * _Nonnull stop) {
                            NSPredicate *deletePredicate = [NSPredicate predicateWithFormat:@"trackingNumber == %@", trackingNumber];
                            [Package deleteAllMatchingPredicate:deletePredicate inContext: moc];
                        }];
                    }];
                }
            }];
            
            [operations addObject: fetchOperation];
            _lastOperation = fetchOperation;
        }
        
        packages = [Package findAllInContext: context];
        // Upload to CloudKit the new items
        [packages enumerateObjectsUsingBlock:^(Package *package, NSUInteger idx, BOOL * _Nonnull stop) {
            if (package.cloudID.length == 0) {
                // We must sync this package
                NSString *trackingNumber = package.trackingNumber;
                
                CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName: trackingNumber];
                CKRecord *cloudPackage = [[CKRecord alloc] initWithRecordType:@"Package" recordID: recordID];
                cloudPackage[@"name"]               = package.name;
                cloudPackage[@"date"]               = package.date;
                cloudPackage[@"trackingNumber"]     = package.trackingNumber;
                cloudPackage[@"lastChecked"]        = package.lastChecked;
                cloudPackage[@"received"]           = package.received;
                
                CKModifyRecordsOperation *operation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[cloudPackage] recordIDsToDelete: nil];
                operation.savePolicy = CKRecordSaveAllKeys;
                operation.database = privateDB;
                if(_lastOperation) [operation addDependency:_lastOperation];
                
                [operation setModifyRecordsCompletionBlock:^(NSArray<CKRecord *> * _Nullable savedRecords, NSArray<CKRecordID *> * _Nullable deletedRecordIDs, NSError * _Nullable error) {
                    if (error == nil) {
                        [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
                            Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackingNumber inContext: moc];
                            package.cloudID = trackingNumber;
                        }];
                    } else {
                        NSLog(@"Error: %@", error.localizedDescription);
                    }
                }];
                
                _lastOperation = operation;
                [operations addObject: operation];
            }
        }];
        
        // Download the missing local items
        localPackageTrackingNumbers = [packages valueForKeyPath:@"trackingNumber"];
        predicate = localPackageTrackingNumbers.count ? [NSPredicate predicateWithFormat:@"NOT (trackingNumber IN %@)", localPackageTrackingNumbers] : [NSPredicate predicateWithValue: YES];
        CKQuery *query = [[CKQuery alloc] initWithRecordType:@"Package" predicate:predicate];
        CKQueryOperation *fetchOperation = [[CKQueryOperation alloc] initWithQuery: query];
        [fetchOperation setRecordFetchedBlock:^(CKRecord * _Nonnull record) {
            [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
                NSString *trackingNumber = record[@"trackingNumber"];
                if (trackingNumber.length) {
                    Package *package = [Package createEntityInContext: moc];
                    package.name            = record[@"name"];
                    package.date            = record[@"date"];
                    package.trackingNumber  = trackingNumber;
                    package.lastChecked     = record[@"lastChecked"];
                    package.received        = record[@"received"];
                    package.cloudID         = record[@"trackingNumber"];
                }
            }];
        }];
        if(_lastOperation) [fetchOperation addDependency:_lastOperation];
        [operations addObject: fetchOperation];
        _lastOperation = fetchOperation;
        
        if (operations.count) {
            [self.cloudKitQueue addOperations:operations waitUntilFinished: NO];
        }
    }];
}

@end
