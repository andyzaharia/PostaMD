//
//  UIAlertView+Alert.h
//  
//
//  Created by Admin on 06.10.2012.
//  Copyright (c) 2012 Admin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIAlertView (Alert)

+(void) info: (NSString *) message;
+(void) message: (NSString *) message;
+(void) error: (NSString *) message;

@end
