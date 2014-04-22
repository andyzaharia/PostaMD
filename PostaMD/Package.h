//
//  Package.h
//  PostaMD
//
//  Created by Andrei Zaharia on 4/8/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class TrackingInfo;

@interface Package : NSManagedObject

@property (nonatomic, retain) NSDate    * date;
@property (nonatomic, retain) NSString  * name;
@property (nonatomic, retain) NSString  * trackingNumber;
@property (nonatomic, retain) NSDate * lastChecked;
@property (nonatomic, retain) NSNumber * received;
@property (nonatomic, retain) NSSet *info;
@end

@interface Package (CoreDataGeneratedAccessors)

- (void)addInfoObject:(TrackingInfo *)value;
- (void)removeInfoObject:(TrackingInfo *)value;
- (void)addInfo:(NSSet *)values;
- (void)removeInfo:(NSSet *)values;

@end
