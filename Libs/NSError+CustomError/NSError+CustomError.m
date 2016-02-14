//
//  NSError+CustomError.m
//
//
//  Created by Andrei Zaharia on 5/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "NSError+CustomError.h"

@implementation NSError (CustomError)

+(NSError *) errorWithDescription: (NSString *) desc
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = [bundle infoDictionary];
    return [NSError errorWithDomain: [info objectForKey:@"CFBundleDisplayName"]
                               code: -1
                           userInfo: @{NSLocalizedDescriptionKey: desc}];
}

@end
