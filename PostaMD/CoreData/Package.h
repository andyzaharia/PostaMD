//
//  Package.h
//  PostaMD
//
//  Created by Andrei Zaharia on 4/8/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

typedef void (^OnDeleteCompleted)(NSError *error);

@class TrackingInfo;

@interface Package : NSManagedObject

+(void) deleteWithItem:(Package *) item onCompletion: (OnDeleteCompleted) onCompletion;

@end
