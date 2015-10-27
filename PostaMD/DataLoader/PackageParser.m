//
//  PackageParser.m
//  PostaMD
//
//  Created by Andrei Zaharia on 1/8/15.
//  Copyright (c) 2015 Andrei Zaharia. All rights reserved.
//

#import "PackageParser.h"
#import "TFHpple.h"

@implementation PackageParser

static NSDateFormatter *sharedDateFormatter = nil;

+(NSArray *) parseMdPackageTrackingInfoWithData: (NSData *)data
                            andTrackingNumber: (NSString *) trackingId
                                    inContext: (NSManagedObjectContext *) context
{
    if (!sharedDateFormatter) {
        sharedDateFormatter = [[NSDateFormatter alloc] init];
        [sharedDateFormatter setDateFormat:@"dd.MM.yyyy - HH:mm"];
    }
    
    
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
    
    Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackingId inContext: context];
    if (!package) {
        package = [Package createEntityInContext: context];
    }
    
    __block NSMutableArray *_newTrackingEvents = [NSMutableArray array];
    
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
        
        NSPredicate *trackingPredicate = nil;
        if (date) {
            trackingPredicate = [NSPredicate predicateWithFormat:@"(date == %@) AND (eventStr LIKE %@) AND (countryStr LIKE %@)", date, eventString, countryString];
        } else {
            // Fall back on checking 3 properties
            trackingPredicate = [NSPredicate predicateWithFormat:@"(countryStr LIKE %@) AND (eventStr LIKE %@) AND (localityStr LIKE %@)", countryString, eventString, localityString];
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
    [context save];

    return _newTrackingEvents;
}

+(NSArray *) parseRoPackageTrackingInfoWithData: (NSData *)data
                              andTrackingNumber: (NSString *) trackingId
                                      inContext: (NSManagedObjectContext *) context
{
    if (!sharedDateFormatter) {
        sharedDateFormatter = [[NSDateFormatter alloc] init];
        [sharedDateFormatter setDateFormat:@"dd.MM.yyyy - HH:mm"];
    }
    
    NSError *error;
    NSMutableDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    NSNumber *found = json[@"found"];
    if (found.boolValue) {
        // Go Ahead...
        NSString *detailsStr = json[@"details"];
        
        NSMutableString *detailsStrM = [detailsStr mutableCopy];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[bntr\\\\" options:0 error:nil];
        [regex replaceMatchesInString:detailsStrM options:0 range:NSMakeRange(0, [detailsStrM length]) withTemplate:@""];
        
        NSData *data = [detailsStrM dataUsingEncoding: NSUTF8StringEncoding];
        TFHpple *doc = [[TFHpple alloc] initWithHTMLData:data];
        
        Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackingId inContext: context];
        if (!package) package = [Package createEntityInContext: context];
        
        __block NSMutableArray *_newTrackingEvents = [NSMutableArray array];
        
        [context performBlockAndWait:^{
            
            NSArray *elements  = [doc searchWithXPathQuery: @"//tr"];
            [elements enumerateObjectsUsingBlock:^(TFHppleElement *event, NSUInteger idx, BOOL * _Nonnull stop) {
                __block BOOL _receivedByUser = NO;
                
                TFHppleElement *dateElement = [[event firstChildWithClassName:@"raport-data"] firstChild];
                TFHppleElement *timeElement = [[event firstChildWithClassName:@"raport-ora"] firstChild];
                TFHppleElement *eventElement = [[event firstChildWithClassName:@"raport-starea"] firstChild];
                
                NSString *dateStr = [dateElement text];
                NSString *timeStr = [timeElement text];
                NSString *eventString = [eventElement text];
                
                NSString *completeDateStr = [NSString stringWithFormat:@"%@ - %@", dateStr, timeStr];
                NSDate *date = [sharedDateFormatter dateFromString: completeDateStr];
                
                if (dateStr.length && timeStr.length && eventString.length) {
                    if ([eventString isEqualToString:@"Predat la destinatar"]) {
                        _receivedByUser = YES;
                    }
                    
                    NSPredicate *trackingPredicate = [NSPredicate predicateWithFormat:@"(date == %@) AND (eventStr LIKE %@)", date, eventString];
                    
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
                        info.eventStr = eventString;
                        info.dateStr = completeDateStr;
                        info.date = date;
                        info.eventId = lastEventId;
                        
                        [_newTrackingEvents addObject: info];
                    }
                    
                    info.package = package;
                    
                    if (_receivedByUser) {
                        package.received = @(YES);
                    }
                }
            }];

            [context save: nil];
        }];
        
        return _newTrackingEvents;
    } else {
        // Item not found...
    }
    
    return @[];
}

@end
