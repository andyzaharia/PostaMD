//
//  TrackingInfo.h
//  PostaMD
//
//  Created by Andrei Zaharia on 1/9/15.
//  Copyright (c) 2015 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Package;

@interface TrackingInfo : NSManagedObject

@property (nonatomic, retain) NSString * countryStr;
@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * dateStr;
@property (nonatomic, retain) NSString * eventStr;
@property (nonatomic, retain) NSString * infoStr;
@property (nonatomic, retain) NSString * localityStr;
@property (nonatomic, retain) NSNumber * eventId;
@property (nonatomic, retain) Package *package;

@end
