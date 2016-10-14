//
//  UIAlertController+Alert.h
//  PostaMD
//
//  Created by Andrei Zaharia on 8/26/16.
//  Copyright © 2016 Andrei Zaharia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIAlertController (Alert)

+(void) info: (NSString *) message;
+(void) message: (NSString *) message;
+(void) error: (NSString *) message;

@end
