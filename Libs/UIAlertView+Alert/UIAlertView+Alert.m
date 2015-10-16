//
//  UIAlertView+Alert.m
//  
//
//  Created by Admin on 06.10.2012.
//  Copyright (c) 2012 Admin. All rights reserved.
//

#import "UIAlertView+Alert.h"

@implementation UIAlertView (Alert)

+(void) info: (NSString *) message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Info", @"")
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                          otherButtonTitles: nil];
    [alert show];
}

+(void) message: (NSString *) message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @""
                                                    message: message
                                                   delegate: nil
                                          cancelButtonTitle: NSLocalizedString(@"OK", @"")
                                          otherButtonTitles: nil];
    [alert show];
}

+(void) error: (NSString *) message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:NSLocalizedString(@"OK", @"")
                                          otherButtonTitles: nil];
    [alert show];
}

@end
