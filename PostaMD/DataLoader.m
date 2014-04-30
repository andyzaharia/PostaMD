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
        [sharedDateFormatter setDateFormat:@"M/dd/yyyy hh:mm:ss a"];
    }

    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    //manager.
    manager.responseSerializer = [[AFHTTPResponseSerializer alloc] init];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
    NSDictionary *parameters = @{@"itemid": trackID};
    
    [manager        POST: @"http://www.posta.md:8081/IPSWeb_item_events.asp"
              parameters: parameters
         timeoutInterval: 5.0
                 success: ^(AFHTTPRequestOperation *operation, NSData *data) {
                     
              NSManagedObjectContext *context = [NSManagedObjectContext contextForBackgroundThread];
              [context performBlock:^{
                  
                  //NSString *responseString = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding: NSUTF8StringEncoding];
                                    
                  TFHpple *doc = [[TFHpple alloc] initWithHTMLData: data];
                  
                  NSArray *elements  = [doc searchWithXPathQuery: @"//table[@id='200']"];
                  TFHppleElement *table = [elements firstObject];
                  TFHppleElement *tableBody = [table firstChildWithTagName:@"tbody"];
                  NSArray *childs = [tableBody childrenWithTagName:@"tr"];

                  
                  Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackID inContext: context];
                  if (!package) {
                      package = [Package createEntityInContext: context];
                  }
                  
                  __block BOOL _hasNewData = NO;
                  
                  childs = [childs subarrayWithRange:NSMakeRange(2, [childs count] - 2)];
                  [childs enumerateObjectsUsingBlock:^(TFHppleElement *e, NSUInteger idx, BOOL *stop) {
                      
                      __block TrackingInfo *info = nil;
                      __block BOOL _receivedByUser = NO;
                      
                      NSArray *tdChilds = [e childrenWithTagName:@"td"];
                      [tdChilds enumerateObjectsUsingBlock:^(TFHppleElement *td, NSUInteger idx, BOOL *stop) {
                          if (idx == 0) {
                              info = [TrackingInfo findFirstByAttribute: @"dateStr"
                                                              withValue: [td text]
                                                              inContext: context];
                              
                              if (!info) {
                                  info = [TrackingInfo createEntityInContext: context];
                                  _hasNewData = YES;
                              }
                              
                              info.package = package;
                          }
                          
                          if (info) {
                              switch (idx) {
                                  case 0: {
                                      info.dateStr = [td text];
                                      info.date = [sharedDateFormatter dateFromString: [td text]];
                                  } break;
                                  case 1:
                                      info.countryStr = [td text];
                                      break;
                                  case 2:
                                      info.localityStr = [td text];
                                      break;
                                  case 3: {
                                      info.eventStr = [td text];
                                      
                                      if (!_receivedByUser && [info.eventStr isEqualToString:@"Livrarea destinatarului"]) {
                                          _receivedByUser = YES;
                                      }
                                  }
                                      break;
                                  case 4:
                                      info.infoStr = [td text];
                                      break;
                                  default:
                                      break;
                              }
                          }
                          
                          //NSLog(@"TD %@", [td text]);
                      }];
                      
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
