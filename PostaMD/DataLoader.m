//
//  DataLoader.m
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "DataLoader.h"
#import "Package.h"
#import "TrackingInfo.h"
#import "AFHTTPRequestOperationManager+Timeout.h"

@implementation DataLoader

static NSDateFormatter *sharedDateFormatter = nil;

+(void) getTrackingInfoForItemWithID: (NSString *) trackID onDone: (OnSuccess) onDone onFailure: (OnFailure) onFailure
{
    if (!sharedDateFormatter) {
        sharedDateFormatter = [[NSDateFormatter alloc] init];
        [sharedDateFormatter setDateFormat:@"dd.MM.yyyy - HH:mm"];
    }

    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    //manager.
    manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
    NSDictionary *parameters = @{@"itemid": trackID};
    
    NSString *path = [NSString stringWithFormat: @"http://www.posta.md/ro/tracking?id=%@", trackID];
    [manager        POST: path
              parameters: parameters
         timeoutInterval: 5.0
                 success: ^(AFHTTPRequestOperation *operation, NSData *data) {
                     
              NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
              [context performBlock:^{
                  
                  //NSString *responseString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding: NSUTF8StringEncoding];
                  //NSLog(@"Response: %@", responseString);
                  
                  TFHpple *doc = [[TFHpple alloc] initWithHTMLData: data];
                  
                  NSArray *elements  = [doc searchWithXPathQuery: @"//div[@class='tracking-table']"];
                  __block TFHppleElement *mainDiv = nil;
                  [elements enumerateObjectsUsingBlock:^(TFHppleElement *element, NSUInteger idx, BOOL *stop) {
                      NSArray *childs = [element childrenWithClassName:@"row clearfix"];
                      if ([childs count] > 0) {
                          mainDiv = element;
                          *stop = YES;
                      }
                  }];
                  
                  NSArray *childs = [mainDiv childrenWithClassName:@"row clearfix"];

                  Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackID inContext: context];
                  if (!package) {
                      package = [Package createEntityInContext: context];
                  }
                  
                  __block BOOL _hasNewData = NO;
                  
                  [childs enumerateObjectsUsingBlock:^(TFHppleElement *e, NSUInteger idx, BOOL *stop) {
                      
                      __block BOOL _receivedByUser = NO;
                      
                      TFHppleElement *dateElement = [e firstChildWithClassName:@"cell tracking-result-header-date"];
                      TFHppleElement *countryElement = [e firstChildWithClassName:@"cell tracking-result-header-country"];
                      TFHppleElement *locationElement = [e firstChildWithClassName:@"cell tracking-result-header-location"];
                      TFHppleElement *eventElement = [e firstChildWithClassName:@"cell tracking-result-header-event"];
                      TFHppleElement *infoExtraElement = [e firstChildWithClassName:@"cell tracking-result-header-extra"];
                      
                      NSString *dateString = [dateElement text];
                      NSString *countryString = [countryElement text];
                      NSString *localityString = [locationElement text];
                      NSString *eventString = [eventElement text];
                      NSString *extraInfoString = [infoExtraElement text];
                      NSDate *date = [sharedDateFormatter dateFromString: dateString];
                      
                      if ([eventString isEqualToString:@"Livrarea destinatarului"]) {
                          _receivedByUser = YES;
                      }
                      
                      NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(date == %@) AND (eventStr LIKE %@)", date, eventString];
                      
                      TrackingInfo *info = [TrackingInfo findFirstWithPredicate:predicate inContext: context];
                      
                      if (!info) {
                          info = [TrackingInfo createEntityInContext: context];
                          info.localityStr = localityString;
                          info.countryStr = countryString;
                          info.eventStr = eventString;
                          info.infoStr = extraInfoString;
                          info.dateStr = dateString;
                          info.date = date;
                          
                          _hasNewData = YES;
                      }
                      
                      info.package = package;
                      
                      if (_receivedByUser) {
                          package.received = @(YES);
                      }
                  }];
                  
                  
                  package.lastChecked = [NSDate date];
                  [context save];
                  
                  NSManagedObjectID *objID = [package objectID];
                  
                  dispatch_async(dispatch_get_main_queue(), ^{
                      NSManagedObjectContext *ctx = [NSManagedObjectContext contextForMainThread];
                      
                      Package *pkg = (Package *)[ctx objectWithID: objID];
                      [ctx refreshObject:pkg mergeChanges: YES];
                      
                      if (onDone) {
                          onDone(@(_hasNewData));
                      }
                  });
              }];
          } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              if (onFailure) {
                  onFailure(error);
              }
          }];
}

#pragma mark - ------------------------------------------------------------

+(void) fetchPackageTrackingInBackground: (NSString *) trackingID
                             onDoneFetch: (OnFetchSuccess) onDone
{
    [DataLoader getTrackingInfoForItemWithID: trackingID
                                      onDone: ^(NSNumber *hasNewData) {
                                          onDone([hasNewData boolValue] ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultNoData);
                                      } onFailure:^(NSError *error) {
                                          onDone(UIBackgroundFetchResultFailed);
                                      }];
}

+(void) fetchTrackingInfoForItems: (NSMutableArray *) items
                  backgroundFetch: (BOOL) backgroundFetch
                   currentResults: (NSMutableArray *) currentResults
                      onDoneFetch: (OnFetchSuccess) onDone
{
    if ([items count] > 0) {
        NSString *lastNumber = [items lastObject];
        [items removeLastObject];
    
        [DataLoader fetchPackageTrackingInBackground: lastNumber
                                         onDoneFetch:^(NSInteger count) {
                                             
                                             //Add the tracking result to the results array.
                                             [currentResults addObject: @(count)];
                                             
                                             [DataLoader fetchTrackingInfoForItems: items
                                                                   backgroundFetch: backgroundFetch
                                                                    currentResults: currentResults
                                                                       onDoneFetch: ^(NSInteger count) {
                                                                           onDone(count);
                                                                       }];
                                         }];
    } else {
        __block NSInteger itemCountWithNewData = 0;
        [currentResults enumerateObjectsUsingBlock:^(NSNumber *result, NSUInteger idx, BOOL *stop) {
            if ([result integerValue] == UIBackgroundFetchResultNewData) {
                itemCountWithNewData++;
            }
        }];
        
        
        if (itemCountWithNewData > 0) {
            onDone(itemCountWithNewData);
        } else {
           onDone(-1);
        }
    }
}

+(void) getTrackingInfoForItems: (NSArray *) trackingNumbers
                backgroundFetch: (BOOL) backgroundFetch
                         onDone: (OnFetchSuccess) onDone
{
    NSMutableArray *mutableList = [NSMutableArray arrayWithArray: trackingNumbers];
    [DataLoader fetchTrackingInfoForItems: mutableList
                          backgroundFetch: backgroundFetch
                           currentResults: [NSMutableArray array]
                              onDoneFetch: ^(NSInteger itemsWithNewData) {
                                  onDone(itemsWithNewData);
                              }];
}

@end
