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

+(NSArray *) parsePackageTrackingInfoWithData: (NSData *)data
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
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(date == %@) AND (eventStr LIKE %@)", date, eventString];
        
        TrackingInfo *info = [TrackingInfo findFirstWithPredicate:predicate inContext: context];
        
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

@end
