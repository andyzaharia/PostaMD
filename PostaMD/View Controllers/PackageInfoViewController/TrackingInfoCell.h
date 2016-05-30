//
//  TrackingInfoCell.h
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TrackingInfo.h"

typedef void (^OnExpandToggle)(void);

@interface TrackingInfoCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *lbInfo;
@property (weak, nonatomic) IBOutlet UILabel *lbDate;
@property (weak, nonatomic) IBOutlet UILabel *lbCountry;
@property (weak, nonatomic) IBOutlet UILabel *lbAdditionalInfo;

@property (nonatomic, copy) OnExpandToggle onExpandToggle;

-(void) configureWithInfo:(TrackingInfo *) trackingInfo expanded: (BOOL) expanded;

@end
