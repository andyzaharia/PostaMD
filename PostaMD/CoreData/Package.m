//
//  Package.m
//  PostaMD
//
//  Created by Andrei Zaharia on 4/8/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "Package.h"
#import "TrackingInfo.h"
#import "Package+CoreDataProperties.h"
#import "NSManagedObjectContext+CloudKit.h"
#import "UIAlertController+Alert.h"

@implementation Package

+(void) deleteWithItem:(Package *) item
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlock:^{
        if (item.cloudID.length) {
            [context cloudKitDeleteObject:item
                    andRecordNameProperty:@"cloudID"
                               completion:^(NSError *error) {
                                    if (error) [UIAlertController error: error.localizedDescription];
                               }];
        } else {
            [context deleteObject: item];
        }
        [context recursiveSave];
    }];
}

@end
