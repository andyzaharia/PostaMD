//
//  Package+CoreDataProperties.m
//  PostaMD
//
//  Created by Andrei Zaharia on 10/12/16.
//  Copyright © 2016 Andrei Zaharia. All rights reserved.
//

#import "Package+CoreDataProperties.h"

@implementation Package (CoreDataProperties)

+ (NSFetchRequest<Package *> *)fetchRequest {
	return [[NSFetchRequest alloc] initWithEntityName:@"Package"];
}

@dynamic cloudID;
@dynamic date;
@dynamic lastChecked;
@dynamic name;
@dynamic received;
@dynamic trackingNumber;
@dynamic unread;
@dynamic info;

@end
