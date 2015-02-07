//
//  PackageInfoViewController.h
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Package.h"
#import "TrackingInfo.h"

@interface PackageInfoViewController : UITableViewController

@property (nonatomic, weak) Package *package;

@end
