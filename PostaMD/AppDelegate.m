//
//  AppDelegate.m
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "AppDelegate.h"
#import "Package.h"
#import "DataLoader.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [NSPersistentStoreCoordinator setDataModelName:@"DataModel" withStoreName:@"data.sqlite"];
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval: 1800]; // 30 Minutes
    
    // Override point for customization after application launch.
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    application.applicationIconBadgeNumber = 0;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

-(void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    NSPredicate *predicate = [NSPredicate predicateWithValue: YES];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"date" ascending: NO];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName: @"Package"];
    [request setFetchBatchSize: 20];
    [request setPredicate: predicate];
    [request setSortDescriptors: @[sort]];
    
    NSArray *items = [context executeFetchRequest: request error: nil];
    NSMutableArray *trackingNumbers = [NSMutableArray arrayWithCapacity: [items count]];
    [items enumerateObjectsUsingBlock:^(Package *package, NSUInteger idx, BOOL *stop) {
        if (![package.received boolValue]) {
            [trackingNumbers addObject: package.trackingNumber];
        }
    }];
    
    [DataLoader getTrackingInfoForItems: trackingNumbers
                        backgroundFetch: YES
                                 onDone: ^(NSInteger count) {
                                     if (count >= 0) {
                                         UIBackgroundFetchResult result = (count > 0) ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultNoData;
                                         completionHandler(result);
                                     } else {
                                         completionHandler(UIBackgroundFetchResultFailed);
                                     }
                                     
                                     application.applicationIconBadgeNumber = (count >= 0) ? count : 0;
                                 }];
}

@end
