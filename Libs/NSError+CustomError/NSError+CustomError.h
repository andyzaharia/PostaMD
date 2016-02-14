//
//  NSError+CustomError.h
//  
//
//  Created by Andrei Zaharia on 5/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (CustomError)

+(NSError *) errorWithDescription: (NSString *) desc;

@end
