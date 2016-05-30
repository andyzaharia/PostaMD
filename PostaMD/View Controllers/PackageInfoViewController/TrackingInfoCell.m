//
//  TrackingInfoCell.m
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "TrackingInfoCell.h"

@interface TrackingInfoCell ()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *additionalLabelTopConstraint;
@property (weak, nonatomic) IBOutlet UIView *vAdditionalContainer;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *expandButtonWidthConstraint;
@property (weak, nonatomic) IBOutlet UIButton *btnExpand;

@end

@implementation TrackingInfoCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void) awakeFromNib
{
    [super awakeFromNib];
    
    self.vAdditionalContainer.layer.cornerRadius = 3.0;
    self.vAdditionalContainer.layer.masksToBounds = YES;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void) configureWithInfo:(TrackingInfo *) trackingInfo expanded: (BOOL) expanded
{
    self.lbInfo.text = trackingInfo.eventStr;
    self.lbDate.text = trackingInfo.dateStr;
    self.lbCountry.text = [trackingInfo.countryStr stringByAppendingFormat:@" - %@", trackingInfo.localityStr];
    
    NSString *additionalInfoStr = trackingInfo.infoStr.length ? trackingInfo.infoStr : @"";
    self.lbAdditionalInfo.text = (expanded) ? additionalInfoStr : @"";
    
    BOOL canExpand = (expanded && additionalInfoStr.length);
    
    self.additionalLabelTopConstraint.constant = canExpand ? 4.0 : 0.0;
    self.expandButtonWidthConstraint.constant = additionalInfoStr.length ? 40.0 : 0.0;
    self.vAdditionalContainer.hidden = !canExpand;
    
    NSString *imageName = expanded ? @"CollapseTrackInfo" : @"ExpandTrackInfo";
    [self.btnExpand setImage:[UIImage imageNamed: imageName] forState: UIControlStateNormal];
}

- (IBAction)didTouchUpExpand:(id)sender {
    if (self.onExpandToggle) {
        self.onExpandToggle();
    }
}

@end
