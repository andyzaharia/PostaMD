//
//  Package+CoreDataProperties.h
//  PostaMD
//
//  Created by Andrei Zaharia on 10/12/16.
//  Copyright © 2016 Andrei Zaharia. All rights reserved.
//

#import "Package.h"


NS_ASSUME_NONNULL_BEGIN

@interface Package (CoreDataProperties)

+ (NSFetchRequest<Package *> *)fetchRequest;

@property (nullable, nonatomic, copy) NSString *cloudID;
@property (nullable, nonatomic, copy) NSDate *date;
@property (nullable, nonatomic, copy) NSDate *lastChecked;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, copy) NSNumber *received;
@property (nullable, nonatomic, copy) NSString *trackingNumber;
@property (nullable, nonatomic, copy) NSNumber *unread;
@property (nullable, nonatomic, retain) NSSet<TrackingInfo *> *info;
@property (nullable, nonatomic, copy) NSString *errorOccurred;

@end

@interface Package (CoreDataGeneratedAccessors)

- (void)addInfoObject:(TrackingInfo *)value;
- (void)removeInfoObject:(TrackingInfo *)value;
- (void)addInfo:(NSSet<TrackingInfo *> *)values;
- (void)removeInfo:(NSSet<TrackingInfo *> *)values;

@end

NS_ASSUME_NONNULL_END
