//
//  NSString+Utils.m
//  PostaMD
//
//  Created by Andrei Zaharia on 7/29/16.
//  Copyright © 2016 Andrei Zaharia. All rights reserved.
//

#import "NSString+Utils.h"

@implementation NSString (Utils)

-(BOOL) isValidTrackingNumber
{
    if (self.length == 0) {
        return NO;
    }
    
    
    NSError *error = NULL;
    NSString *pattern = @"^[A-Z]{2}[0-9]{9,10}[A-Z]{2}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern: pattern
                                                                           options: NSRegularExpressionCaseInsensitive
                                                                             error: &error];
    
    NSArray *matches = [regex matchesInString: self
                                      options: 0
                                        range: NSMakeRange(0, self.length)];
    return matches.count > 0;
}

@end
