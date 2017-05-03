//
//  AppDelegate.m
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "AppDelegate.h"
#import "DataLoader.h"
#import "Constants.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <iRate/iRate.h>
#import <MBProgressHUD/MBProgressHUD.h>

@implementation AppDelegate

+(void)initialize
{
    [iRate sharedInstance].daysUntilPrompt = 10;
    [iRate sharedInstance].usesUntilPrompt = 30;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Fabric with:@[CrashlyticsKit]];

    [NSPersistentStoreCoordinator setDataModelName:@"DataModel" withStoreName:@"data.sqlite"];
    [NSManagedObjectContext contextForMainThread];
    
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval: 1500]; // 30 Minutes
    
    [[MBProgressHUD appearance] setBackgroundColor:[UIColor blackColor]];
    
        
    [DataLoader shared];
    
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]){
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes: UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound categories:nil];
        [application registerUserNotificationSettings: settings];
    }
    
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
    
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlock:^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"received == NO"];
        NSInteger activePackages = [Package countOfEntitiesWithPredicate: predicate];
        NSTimeInterval fetchInterval = (activePackages > 0) ? 1800 : UIApplicationBackgroundFetchIntervalNever;
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval: fetchInterval];
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
    [[DataLoader shared] syncWithCloudKit];
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

    [[DataLoader shared] getTrackingInfoForItems: trackingNumbers
                                          onDone: ^(NSDictionary *info) {
                                             NSInteger newEvents = [info count];
                                             if (newEvents >= 0) {
                                                 UIBackgroundFetchResult result = (newEvents > 0) ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultNoData;
                                                 completionHandler(result);
                                             } else {
                                                 completionHandler(UIBackgroundFetchResultNoData);
                                             }

                                            dispatch_async(dispatch_get_main_queue(), ^(void){
                                                [self backgroundFetchPerformedWithItems: info.allKeys hasNewItems: (newEvents > 0)];
                                            });
                                          } onFailure:^(NSError *error) {
                                              completionHandler(UIBackgroundFetchResultFailed);
                                          }];
}

#pragma mark -

-(void) backgroundFetchPerformedWithItems: (NSArray *) items hasNewItems: (BOOL) newEvents
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSDate date] forKey: kDEFAULTS_LAST_FULL_UPDATE];
    [defaults synchronize];

    NSString *messageBody = @"";
    if (newEvents == 1) {
        NSArray *allKeys = items;
        NSString *firstTrackingId = [allKeys firstObject];

        Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:firstTrackingId];
        NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"eventId" ascending: YES];
        NSArray *items = [package.info allObjects];
        NSArray *events = [items sortedArrayUsingDescriptors:@[descriptor]];

        if ([events count]) {
            TrackingInfo *lastEvent = [events lastObject];
            NSString *localityStr = [lastEvent.localityStr length] ? [NSString stringWithFormat:@"(%@)", lastEvent.localityStr] : @"";
            messageBody = [NSString stringWithFormat:@"%@ - %@%@.", package.name, lastEvent.eventStr, localityStr];
        }
    } else {
        NSArray *allKeys = items;

        NSMutableString *bodyStr = [NSMutableString stringWithFormat:@""];
        [allKeys enumerateObjectsUsingBlock:^(NSString *trackingId, NSUInteger idx, BOOL *stop) {
            Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue: trackingId];
            if (idx < newEvents - 1) {
                [bodyStr appendFormat:@"%@, ", package.name];
            } else {
                [bodyStr appendFormat:@"%@.", package.name];
            }
        }];

        if (bodyStr.length > 0) {
            messageBody = [NSString stringWithFormat: @"Updates in %@", bodyStr];
        }
    }

    if ([messageBody length]) {
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.fireDate = [NSDate date];
        localNotification.alertBody = messageBody;
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        localNotification.applicationIconBadgeNumber = newEvents;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    }
}

@end
