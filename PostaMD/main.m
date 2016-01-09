//
//  main.m
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import <GDCoreDataConcurrencyDebugging/GDCoreDataConcurrencyDebugging.h>
#import "AppDelegate.h"

//static void CoreDataConcurrencyFailureHandler(SEL _cmd)
//{
//    // Simply checking _cmd == @selector(autorelease) won't work in ARC code.
//    // You really shouldn't ignore -autorelease messages sent on the wrong thread,
//    // but if you want to live on the wild side...
//    if (_cmd == NSSelectorFromString(@"autorelease")) return;
//    NSLog(@"CoreData concurrency failure: Selector '%@' called on wrong queue/thread.", NSStringFromSelector(_cmd));
//}

int main(int argc, char * argv[])
{
    //GDCoreDataConcurrencyDebuggingSetFailureHandler(CoreDataConcurrencyFailureHandler);
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
