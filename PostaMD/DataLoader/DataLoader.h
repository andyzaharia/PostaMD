//
//  DataLoader.h
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#import "Package.h"
#import "Package+CoreDataProperties.h"
#import "TrackingInfo.h"

typedef void (^OnSuccess)(id data);
typedef void (^OnFailure)(NSError *error);

typedef void (^OnFetchSuccess)(BOOL didFetchNewData);
typedef void (^OnFetchSuccessEx)(NSDictionary *info);

typedef void (^OnFinished)(UIBackgroundFetchResult result);

static NSInteger minTrackingNumberLength = 13;

@interface DataLoader : NSObject

+(id) shared;

+(NSString *) cloudKitContainerIdentifier;

-(void) getTrackingInfoForItemWithID: (NSString *) trackID
                              onDone: (OnSuccess) onDone
                           onFailure: (OnFailure) onFailure;

-(void) getTrackingInfoForItems: (NSArray *) trackingNumbers
                         onDone: (OnFetchSuccessEx) onDone
                      onFailure: (OnFailure) onFailure;

-(void) syncWithCloudKit;

-(void) processQueryNotification: (CKQueryNotification *) notification onFinish: (OnFinished) onFinish;

-(void) debug;

@end
