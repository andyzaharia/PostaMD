//
//  DataLoader.h
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"
#import "Package.h"
#import "TrackingInfo.h"

typedef void (^OnSuccess)(id data);
typedef void (^OnFailure)(NSError *error);

typedef void (^OnFetchSuccess)(BOOL didFetchNewData);
typedef void (^OnFetchSuccessEx)(NSDictionary *info);

@interface DataLoader : NSObject

+(id) shared;

-(void) getTrackingInfoForItemWithID: (NSString *) trackID
                              onDone: (OnSuccess) onDone
                           onFailure: (OnFailure) onFailure;

-(void) getTrackingInfoForItems: (NSArray *) trackingNumbers
                         onDone: (OnFetchSuccessEx) onDone
                      onFailure: (OnFailure) onFailure;


@end
