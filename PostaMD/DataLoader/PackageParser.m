//
//  PackageParser.m
//  PostaMD
//
//  Created by Andrei Zaharia on 1/8/15.
//  Copyright (c) 2015 Andrei Zaharia. All rights reserved.
//

#import "PackageParser.h"
#import <HTMLReader/HTMLReader.h>

@implementation PackageParser

static NSDateFormatter *sharedDateFormatter = nil;

+(NSArray *) parseMdPackageTrackingInfoWithData: (NSData *)data
                            andTrackingNumber: (NSString *) trackingId
                                    inContext: (NSManagedObjectContext *) context
{
    if (!sharedDateFormatter) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedDateFormatter = [[NSDateFormatter alloc] init];
            [sharedDateFormatter setDateFormat:@"dd.MM.yyyy - HH:mm"];
        });
    }
    
    HTMLDocument *document = [HTMLDocument documentWithData:data contentTypeHeader: nil];
    HTMLElement *trackingTable = [document firstNodeMatchingSelector:@".tracking-table"];
    
    NSArray *childs = [trackingTable nodesMatchingSelector:@".row"];
    
    Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackingId inContext: context];
    if (!package) {
        package = [Package createEntityInContext: context];
    }

    __block NSMutableArray *_newTrackingEvents = [NSMutableArray array];
    
    [childs enumerateObjectsUsingBlock:^(HTMLElement *element, NSUInteger idx, BOOL *stop) {

        __block BOOL _receivedByUser = NO;
        
        HTMLElement *dateElement = [element firstNodeMatchingSelector:@".tracking-result-header-date"];
        HTMLElement *countryElement = [element firstNodeMatchingSelector:@".tracking-result-header-country"];
        HTMLElement *locationElement = [element firstNodeMatchingSelector:@".tracking-result-header-location"];
        HTMLElement *eventElement = [element firstNodeMatchingSelector:@".tracking-result-header-event"];
        HTMLElement *infoExtraElement = [element firstNodeMatchingSelector:@".tracking-result-header-extra"];
        
        NSString *dateString = [dateElement textContent];
        NSString *countryString = [countryElement textContent];
        NSString *localityString = [locationElement textContent];
        NSString *eventString = [eventElement textContent];
        NSString *extraInfoString = [infoExtraElement textContent];
        NSDate *date = [sharedDateFormatter dateFromString: dateString];
        
        if ([eventString isEqualToString:@"Livrarea destinatarului"]) {
            _receivedByUser = YES;
        }
        
        NSPredicate *trackingPredicate = nil;
        if (date) {
            trackingPredicate = [NSPredicate predicateWithFormat:@"(date == %@) AND (eventStr LIKE %@) AND (countryStr LIKE %@) AND (package == %@)", date, eventString, countryString, package];
        } else {
            // Fall back on checking 3 properties
            trackingPredicate = [NSPredicate predicateWithFormat:@"(countryStr LIKE %@) AND (eventStr LIKE %@) AND (localityStr LIKE %@) AND (package == %@)", countryString, eventString, localityString, package];
        }
        
        TrackingInfo *info = [TrackingInfo findFirstWithPredicate:trackingPredicate inContext: context];
        
        if (!info) {
            NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"eventId" ascending: YES];
            NSArray *items = [package.info allObjects];
            NSArray *events = [items sortedArrayUsingDescriptors:@[descriptor]];
            NSNumber *lastEventId = @(0);
            if ([events count]) {
                TrackingInfo *lastEvent = [events lastObject];
                lastEventId = @([lastEvent.eventId integerValue] + 1);
            }
            
            info = [TrackingInfo createEntityInContext: context];
            info.localityStr = localityString;
            info.countryStr = countryString;
            info.eventStr = eventString;
            info.infoStr = extraInfoString;
            info.dateStr = dateString;
            info.date = date;
            info.eventId = lastEventId;
            
            [_newTrackingEvents addObject: info];
        }
        
        info.package = package;
        
        if (_receivedByUser) {
            package.received = @(YES);
        }
    }];
    
    package.lastChecked = [NSDate date];

     return _newTrackingEvents;
}

+(NSArray *) parseRoPackageTrackingInfoWithData: (NSData *)data
                              andTrackingNumber: (NSString *) trackingId
                                      inContext: (NSManagedObjectContext *) context
{
//    if (!sharedDateFormatter) {
//        static dispatch_once_t onceToken;
//        dispatch_once(&onceToken, ^{
//            sharedDateFormatter = [[NSDateFormatter alloc] init];
//            [sharedDateFormatter setDateFormat:@"dd.MM.yyyy - HH:mm"];
//        });
//    }
//    
//    NSError *error;
//    NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
//    NSNumber *found = json[@"found"];
//    if (found.boolValue) {
//        // Go Ahead...
//        NSString *detailsStr = json[@"details"];
//        
//        NSMutableString *detailsStrM = [detailsStr mutableCopy];
//        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[bntr\\\\" options:0 error:nil];
//        [regex replaceMatchesInString:detailsStrM options:0 range:NSMakeRange(0, [detailsStrM length]) withTemplate:@""];
//        
//        NSData *data = [detailsStrM dataUsingEncoding: NSUTF8StringEncoding];
//        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
//        
//        Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackingId inContext: context];
//        if (!package) package = [Package createEntityInContext: context];
//        
//        __block NSMutableArray *_newTrackingEvents = [NSMutableArray array];
//        
//        [context performBlockAndWait:^{
//            
//            NSArray *elements  = [doc searchWithXPathQuery: @"//tr"];
//            [elements enumerateObjectsUsingBlock:^(TFHppleElement *event, NSUInteger idx, BOOL * _Nonnull stop) {
//                __block BOOL _receivedByUser = NO;
//                
//                TFHppleElement *dateElement = [[event firstChildWithClassName:@"raport-data"] firstChild];
//                TFHppleElement *timeElement = [[event firstChildWithClassName:@"raport-ora"] firstChild];
//                TFHppleElement *eventElement = [[event firstChildWithClassName:@"raport-starea"] firstChild];
//                
//                NSString *dateStr = [dateElement text];
//                NSString *timeStr = [timeElement text];
//                NSString *eventString = [eventElement text];
//                
//                NSString *completeDateStr = [NSString stringWithFormat:@"%@ - %@", dateStr, timeStr];
//                NSDate *date = [sharedDateFormatter dateFromString: completeDateStr];
//                
//                if (dateStr.length && timeStr.length && eventString.length) {
//                    if ([eventString isEqualToString:@"Predat la destinatar"]) {
//                        _receivedByUser = YES;
//                    }
//                    
//                    NSPredicate *trackingPredicate = [NSPredicate predicateWithFormat:@"(date == %@) AND (eventStr LIKE %@)", date, eventString];
//                    
//                    TrackingInfo *info = [TrackingInfo findFirstWithPredicate:trackingPredicate inContext: context];
//                    
//                    if (!info) {
//                        NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"eventId" ascending: YES];
//                        NSArray *items = [package.info allObjects];
//                        NSArray *events = [items sortedArrayUsingDescriptors:@[descriptor]];
//                        NSNumber *lastEventId = @(0);
//                        if ([events count]) {
//                            TrackingInfo *lastEvent = [events lastObject];
//                            lastEventId = @([lastEvent.eventId integerValue] + 1);
//                        }
//                        
//                        info = [TrackingInfo createEntityInContext: context];
//                        info.eventStr = eventString;
//                        info.dateStr = completeDateStr;
//                        info.date = date;
//                        info.eventId = lastEventId;
//                        
//                        [_newTrackingEvents addObject: info];
//                    }
//                    
//                    info.package = package;
//                    
//                    if (_receivedByUser) {
//                        package.received = @(YES);
//                    }
//                }
//            }];
//        }];
//        
//        return _newTrackingEvents;
//    } else {
//        // Item not found...
//    }
    
    return @[];
}

@end
