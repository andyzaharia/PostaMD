//
//  PackageParser.h
//  PostaMD
//
//  Created by Andrei Zaharia on 1/8/15.
//  Copyright (c) 2015 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Package.h"
#import "Package+CoreDataProperties.h"
#import "TrackingInfo.h"

@interface PackageParser : NSObject

// Returns the newly found events
+(NSArray *) parseMdPackageTrackingInfoWithData: (NSData *)data
                            andTrackingNumber: (NSString *) trackingId
                                    inContext: (NSManagedObjectContext *) context;

+(NSArray *) parseRoPackageTrackingInfoWithData: (NSData *)data
                              andTrackingNumber: (NSString *) trackingId
                                      inContext: (NSManagedObjectContext *) context;

@end
