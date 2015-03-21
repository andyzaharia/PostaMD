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

-(id) init
{
    self = [super init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        [_operationQueue setMaxConcurrentOperationCount: 2];
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

@end
