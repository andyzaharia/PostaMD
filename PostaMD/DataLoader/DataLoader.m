//
//  DataLoader.m
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "DataLoader.h"
#import "AFHTTPRequestOperationManager+Synchronous.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
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

+(BOOL) isRomanianApp
{
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    return [bundleIdentifier hasSuffix:@".ro"];
}

+(BOOL) isMoldovianApp
{
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    return ![bundleIdentifier hasSuffix:@".ro"];
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

-(void) getMdTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    NSDictionary *parameters = @{@"itemid": trackID};
    NSString *path = [NSString stringWithFormat: @"http://www.posta.md/ro/tracking?id=%@", trackID];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        
        //Background Thread
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
        
        NSError *error = nil;
        NSData *data = [manager syncPOST: path parameters: parameters operation: NULL error: &error];
        
        if (data) {
            NSInteger __block initialEventsCount = 0;

            [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
                Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: moc];
                initialEventsCount = [package.info count];
                [PackageParser parseMdPackageTrackingInfoWithData: data andTrackingNumber: trackID inContext: moc];
            } onSaved:^{
                
                NSManagedObjectContext *ctx = [NSManagedObjectContext contextForMainThread];
                [ctx performBlockAndWait:^{
                    Package *pkg = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: ctx];
                    [ctx refreshObject:pkg mergeChanges: YES];
                    
                    NSInteger afterUpdateEventsCount = [pkg.info count];
                    
                    if (onDone) onDone(@(initialEventsCount < afterUpdateEventsCount));
                    [ctx save: nil];
                }];
                
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

-(void) getRoTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    NSDictionary *parameters = @{@"awb": trackID};
    NSString *path = @"https://www.posta-romana.ro/cnpr-app/modules/track-and-trace/ajax/status.php";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        //Background Thread
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
        
        NSError *error = nil;
        NSData *data = [manager syncPOST: path parameters: parameters operation: NULL error: &error];
        
        if (data) {
            NSInteger __block initialEventsCount = 0;
            
            [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
                Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: moc];
                initialEventsCount = [package.info count];
                [PackageParser parseRoPackageTrackingInfoWithData: data andTrackingNumber: trackID inContext: moc];
            } onSaved:^{
                
                NSManagedObjectContext *ctx = [NSManagedObjectContext contextForMainThread];
                [ctx performBlockAndWait:^{
                    Package *pkg = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: ctx];
                    [ctx refreshObject:pkg mergeChanges: YES];
                    
                    NSInteger afterUpdateEventsCount = [pkg.info count];
                    
                    if (onDone) onDone(@(initialEventsCount < afterUpdateEventsCount));
                    [ctx save: nil];
                }];
                
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

-(void) getTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    if ([DataLoader isRomanianApp]) {
        //Go for Romania
        [self getRoTrackingInfoForItemWithID:trackID onDone: onDone onFailure: onFailure];
    } else {
        [self getMdTrackingInfoForItemWithID:trackID onDone: onDone onFailure: onFailure];
    }
}

-(void) getTrackingInfoForItems: (NSArray *) trackingNumbers
                         onDone: (OnFetchSuccessEx) onDone
                      onFailure: (OnFailure) onFailure
{
    NSMutableDictionary *__block _packageEventsDic      = [NSMutableDictionary dictionary];
    
    NSMutableArray *__block signals = [NSMutableArray arrayWithCapacity: trackingNumbers.count];
    [trackingNumbers enumerateObjectsUsingBlock:^(NSString *trackingId, NSUInteger idx, BOOL *stop) {
        
        NSArray *__block currentEventIDs = nil;
        
        NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
        [context performBlockAndWait:^{
            Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackingId inContext: context];
            if (package) currentEventIDs = [package.info valueForKeyPath:@"eventId"];
        }];
        
        RACSignal *signal =[RACSignal createSignal:^RACDisposable *(id < RACSubscriber > subscriber) {
            [[DataLoader shared] getTrackingInfoForItemWithID:trackingId
                                                       onDone:^(NSNumber *hasFreshItems) {
                                                           
                                                           if (hasFreshItems.boolValue) {
                                                               NSManagedObjectContext *ctx = [NSManagedObjectContext contextForMainThread];
                                                               [ctx performBlockAndWait:^{
                                                                   Package *pkg = [Package findFirstByAttribute:@"trackingNumber" withValue: trackingId inContext: ctx];
                                                                   if (pkg) {
                                                                       [ctx refreshObject:pkg mergeChanges: YES];
                                                                       
                                                                       //Fetch only the new events
                                                                       NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(package == %@) AND (NOT (eventId IN %@))", pkg, currentEventIDs];
                                                                       NSArray *events = [TrackingInfo findAllWithPredicate:predicate inContext: ctx];
                                                                       [_packageEventsDic setObject: events forKey: trackingId];
                                                                   }
                                                               }];
                                                           }
                                                           
                                                           [subscriber sendCompleted];
                                                           
                                                       } onFailure:^(NSError *error) {
                                                           [subscriber sendError:error];
                                                       }];
            return nil;
        }];
        
        [signals addObject: signal];
    }];
    
    [[RACSignal merge:signals] subscribeError:^(NSError *error) {
        if (onFailure) onFailure(error);
    } completed:^{
        if (onDone) onDone(_packageEventsDic);
    }];
}

#pragma mark - Sync

-(void) syncWithCloudKit
{
    CKDatabase *privateDB = [[CKContainer defaultContainer] privateCloudDatabase];
    if (privateDB) {
        NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
        [context performBlock:^{
            
            NSMutableArray *operations = [NSMutableArray array];
            __block NSOperation *_lastOperation = nil;
            DataLoader *__weak weakSelf = self;
            
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
                [weakSelf savePackageCKRecord: record];
            }];
            if(_lastOperation) [fetchOperation addDependency:_lastOperation];
            [operations addObject: fetchOperation];
            _lastOperation = fetchOperation;
            
            if (operations.count) {
                [self.cloudKitQueue addOperations:operations waitUntilFinished: NO];
            }
        }];
    }
}

-(void) savePackageCKRecord: (CKRecord *) record
{
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
            
            [self getTrackingInfoForItemWithID:trackingNumber onDone:nil onFailure:nil];
        }
    }];
}

@end
