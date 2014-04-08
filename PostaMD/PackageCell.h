//
//  PackageCell.h
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PackageCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *lbTrackingNumber;
@property (weak, nonatomic) IBOutlet UILabel *lbName;
@property (weak, nonatomic) IBOutlet UILabel *lbLastTrackingInfo;

@end
