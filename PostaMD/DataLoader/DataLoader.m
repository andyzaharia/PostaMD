//
//  DataLoader.m
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "DataLoader.h"
#import "PackageParser.h"
#import "NSError+CustomError.h"

#import "NSManagedObjectContext+Custom.h"
#import <CloudKit/CloudKit.h>

@interface DataLoader ()
{
    NSOperationQueue                *_operationQueue;
}

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

+(NSString *) cloudKitContainerIdentifier
{
    if ([DataLoader isRomanianApp]) {
        return @"iCloud.com.andyzaharia.posta.Ro";
    } else if ([DataLoader isMoldovianApp]) {
        return [CKContainer defaultContainer].containerIdentifier;
    }
    
    return nil;
}

+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(__autoreleasing NSURLResponse **)responsePtr
                             error:(__autoreleasing NSError **)errorPtr {
    dispatch_semaphore_t    sem;
    __block NSData *        result;
    
    result = nil;
    
    sem = dispatch_semaphore_create(0);
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (errorPtr != NULL) {
                                             *errorPtr = error;
                                         }
                                         if (responsePtr != NULL) {
                                             *responsePtr = response;
                                         }  
                                         if (error == nil) {  
                                             result = data;  
                                         }  
                                         dispatch_semaphore_signal(sem);  
                                     }] resume];  
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);  
    
    return result;  
}  

#pragma mark -

-(id) init
{
    self = [super init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        [_operationQueue setMaxConcurrentOperationCount: 1];
        
        self.cloudKitQueue = [[NSOperationQueue alloc] init];
        
        [self syncWithCloudKit];
    }
    return self;
}

-(BOOL) getMdTrackingInfoForItemWithID: (NSString *) trackID error: (__autoreleasing NSError **)errorPtr
{
    if (trackID.length >= minTrackingNumberLength) {
        //NSDictionary *parameters = @{@"itemid": trackID};
        NSString *path = [NSString stringWithFormat: @"http://www.posta.md/ro/tracking?id=%@", trackID];
        
        NSError * __autoreleasing error = nil;
        NSURLResponse *response = nil;

        
        NSURL *url = [NSURL URLWithString: path];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: url];
        request.HTTPMethod = @"POST";
        request.timeoutInterval = 15.0;
        request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
        
        NSData *data = [DataLoader sendSynchronousRequest:request returningResponse:&response error: &error];
        
        if(error) {
            NSString *errorMessage = error.localizedDescription;
            NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
            [context performBlockAndWait:^{
                Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: context];
                if (package) {
                    package.errorOccurred = errorMessage;
                }

                if([context hasChanges]) [context recursiveSave];
            }];

            *errorPtr = error;
            return NO;
        } else if (data) {
            NSInteger __block initialEventsCount = 0;
            
            __block BOOL hasNewItems = NO;
            
            NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
            [context performBlockAndWait:^{
                Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackID inContext: context];
                initialEventsCount = [package.info count];
                
                NSArray *freshEvents = [PackageParser parseMdPackageTrackingInfoWithData: data andTrackingNumber: trackID inContext: context];
                if(freshEvents.count > 0) {
                    package.unread = @(YES);
                }

                package.errorOccurred = @"";
                
                NSInteger afterUpdateEventsCount = [package.info count];
                hasNewItems = (initialEventsCount < afterUpdateEventsCount);
                
                if([context hasChanges]) [context recursiveSave];
            }];
            
            return hasNewItems;
        }
    
    } else {
        NSError *__autoreleasing error = [NSError errorWithDescription:@"Tracking number is too short."];
        *errorPtr = error;
        return NO;
    }
    
    return NO;
}

-(void) getRoTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    if (trackID.length >= minTrackingNumberLength) {
        //NSDictionary *parameters = @{@"awb": trackID};
        NSString *path = @"https://www.posta-romana.ro/cnpr-app/modules/track-and-trace/ajax/status.php";
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            //Background Thread
            
            NSError *error = nil;
            NSData *data = nil;
            
            NSURL *url = [NSURL URLWithString: path];
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL: url];
            request.HTTPMethod = @"POST";
            
            NSData *syncData = nil;
            NSURLResponse *response = nil;
            syncData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            if(syncData) {
                data = syncData;
            }
            
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
                        [ctx recursiveSave];
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
    } else {
        NSError *error = [NSError errorWithDescription:@"Tracking number is too short."];
        if (onFailure) onFailure(error);
    }
}

-(void) getTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        if ([DataLoader isRomanianApp]) {
            //Go for Romania
            [self getRoTrackingInfoForItemWithID:trackID onDone: onDone onFailure: onFailure];
        } else {
            
            NSError *error = nil;
            BOOL hasNewData = [self getMdTrackingInfoForItemWithID:trackID error: &error];
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                if(error == nil) {
                    if(onDone) onDone(@(hasNewData));
                } else {
                    if(onFailure) onFailure(error);
                }
            });
        }
    });
}

-(void) getTrackingInfoForItems: (NSArray *) trackingNumbers
                         onDone: (OnFetchSuccessEx) onDone
                      onFailure: (OnFailure) onFailure
{
    NSMutableDictionary *__block _packageEventsDic      = [NSMutableDictionary dictionary];
    
    __block NSError *operationError = nil;
    
    [trackingNumbers enumerateObjectsUsingBlock:^(NSString *trackingId, NSUInteger idx, BOOL *stop) {
        
        NSArray *__block currentEventIDs = nil;
        
        NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
        [context performBlockAndWait:^{
            Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackingId inContext: context];
            if (package) currentEventIDs = [package.info valueForKeyPath:@"eventId"];
        }];
        
        NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
            
            NSError *error = nil;
            BOOL hasNewData = [[DataLoader shared] getMdTrackingInfoForItemWithID:trackingId error: &error];
            
            if(error == nil) {
                if(hasNewData) {
                   NSManagedObjectContext *ctx = [NSManagedObjectContext contextForBackgroundThread];
                   [ctx performBlockAndWait:^{
                       Package *pkg = [Package findFirstByAttribute:@"trackingNumber" withValue: trackingId inContext: ctx];
                       if (pkg) {
                           [ctx refreshObject:pkg mergeChanges: YES];

                           //Fetch only the new events
                           NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(package == %@) AND (NOT (eventId IN %@))", pkg, currentEventIDs];
                           NSArray *events = [TrackingInfo findAllWithPredicate:predicate inContext: ctx];
                           [_packageEventsDic setObject: events forKey: trackingId];
                       }
                       
                       if([ctx hasChanges]) {
                           [ctx recursiveSave];
                       }
                   }];
                }
            } else {
                operationError = error;
            }
        }];
        
        [self addOperationAfterLast: operation];
    }];
    
    NSOperation *finishOperation = [NSBlockOperation blockOperationWithBlock:^{
        if(operationError == nil) {
            if (onDone) onDone(_packageEventsDic);
        } else {
            if (onFailure) onFailure(operationError);
        }
    }];
    
    [self addOperationAfterLast: finishOperation];
}

- (void) addOperationAfterLast:(NSOperation *)op
{
    if (_operationQueue.maxConcurrentOperationCount != 1)
    _operationQueue.maxConcurrentOperationCount = 1;
    
    NSOperation *lastOp = _operationQueue.operations.lastObject;
    if (lastOp != nil)
    [op addDependency: lastOp];
    
    [_operationQueue addOperation:op];
}

#pragma mark - Sync

-(void) syncWithCloudKit
{
    NSString *containerIdentier = [DataLoader cloudKitContainerIdentifier];
    CKContainer *container = [CKContainer containerWithIdentifier: containerIdentier];
    CKDatabase *privateDB = [container privateCloudDatabase];
 
    [container accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError * _Nullable error) {
       
        if(accountStatus == CKAccountStatusAvailable) {
            if (privateDB) {
                NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
                [context performBlock:^{
                    
                    NSMutableArray *operations = [NSMutableArray array];
                    __block NSOperation *_lastOperation = nil;
                    DataLoader *__weak weakSelf = self;
                    
                    // Check the existing packages for cloudID presence on local side.
                    // if a package has a cloudID but that id is missing in Cloud then we must delete the local one.
                    //
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.cloudID.length > 0"];
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
                    
                    NSLog(@"%@", [DataLoader cloudKitContainerIdentifier]);
                    
                    
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
                            
                            CKModifyRecordsOperation *operation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[cloudPackage]
                                                                                                        recordIDsToDelete: nil];
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
                    [fetchOperation setQueryCompletionBlock:^(CKQueryCursor * _Nullable cursor, NSError * _Nullable operationError){
                        if (operationError) {
                            NSLog(@"Error: %@", operationError);
                        }
                    }];

                    if(_lastOperation) [fetchOperation addDependency:_lastOperation];
                    [operations addObject: fetchOperation];
                    _lastOperation = fetchOperation;
                    
                    if (operations.count) {
                        [self.cloudKitQueue addOperations:operations waitUntilFinished: NO];
                    }


                }];
            }
        } else {
            NSLog(@"No iCloud Account available.");
        }
    }];
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
            
            [moc recursiveSave];
            
            [self getTrackingInfoForItemWithID:trackingNumber onDone:nil onFailure:nil];
        }
    }];
}

-(void) debug {
    
    [NSManagedObjectContext performSaveOperationWithBlock:^(NSManagedObjectContext *moc) {
        
        for(int i = 0; i<500; i++) {
        
            Package *package = [Package createEntityInContext: moc];
            package.name            = @"A Test";
            package.date            = [NSDate date];
            package.trackingNumber  = @"CH004676661US";
            package.lastChecked     = nil;
            package.received        = @(NO);
        
            [self getTrackingInfoForItemWithID:package.trackingNumber onDone:nil onFailure:nil];
        }
    } onSaved:^{
        
    }];
    
}

@end
