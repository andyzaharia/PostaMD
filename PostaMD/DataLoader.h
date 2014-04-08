//
//  DataLoader.h
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"
#import "TFHpple.h"

typedef void (^OnSuccess)(id data);
typedef void (^OnFailure)(NSError *error);

@interface DataLoader : NSObject

+(void) getTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure;

@end
