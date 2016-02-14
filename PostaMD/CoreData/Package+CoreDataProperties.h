//
//  Package+CoreDataProperties.h
//  PostaMD
//
//  Created by Andrei Zaharia on 2/14/16.
//  Copyright © 2016 Andrei Zaharia. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Package.h"

NS_ASSUME_NONNULL_BEGIN

@interface Package (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *cloudID;
@property (nullable, nonatomic, retain) NSDate *date;
@property (nullable, nonatomic, retain) NSDate *lastChecked;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSNumber *received;
@property (nullable, nonatomic, retain) NSString *trackingNumber;
@property (nullable, nonatomic, retain) NSSet<TrackingInfo *> *info;

@end

@interface Package (CoreDataGeneratedAccessors)

- (void)addInfoObject:(TrackingInfo *)value;
- (void)removeInfoObject:(TrackingInfo *)value;
- (void)addInfo:(NSSet<TrackingInfo *> *)values;
- (void)removeInfo:(NSSet<TrackingInfo *> *)values;

@end

NS_ASSUME_NONNULL_END
