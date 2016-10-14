//
//  UIAlertController+Alert.m
//  PostaMD
//
//  Created by Andrei Zaharia on 8/26/16.
//  Copyright © 2016 Andrei Zaharia. All rights reserved.
//

#import "UIAlertController+Alert.h"

@implementation UIAlertController (Alert)

+(void) info: (NSString *) message
{
    if (message.length) {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Info", @"")
                                                                            message:message
                                                                     preferredStyle: UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                         //
                                                     }]];
        
        [[UIAlertController rootViewController] presentViewController: controller animated: YES completion: nil];
    }
}

+(void) message: (NSString *) message
{
    if (message.length) {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"", @"")
                                                                            message:message
                                                                     preferredStyle: UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                         //
                                                     }]];
        
        [[UIAlertController rootViewController] presentViewController: controller animated: YES completion: nil];
    }
}

+(void) error: (NSString *) message
{
    if (message.length) {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", @"")
                                                                            message:message
                                                                     preferredStyle: UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleCancel
                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                         //
                                                     }]];
        
        [[UIAlertController rootViewController] presentViewController: controller animated: YES completion: nil];
    }
}

+(UIViewController *) rootViewController
{
    return [[UIApplication sharedApplication].keyWindow rootViewController];
}

@end
