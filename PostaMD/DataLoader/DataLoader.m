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

@interface DataLoader ()
{
    NSOperationQueue              *_operationQueue;
}

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
    }
    return self;
}

-(void) getMdTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
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
                
                [PackageParser parseMdPackageTrackingInfoWithData: data andTrackingNumber: trackID inContext: context];
                
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

-(void) getRoTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    NSDictionary *parameters = @{@"awb": trackID};
    NSString *path = @"https://www.posta-romana.ro/cnpr-app/modules/track-and-trace/ajax/status.php";
    
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
                
                [PackageParser parseRoPackageTrackingInfoWithData: data
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

@end
