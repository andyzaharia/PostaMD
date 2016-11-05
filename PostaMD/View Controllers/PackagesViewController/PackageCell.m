//
//  PackageCell.m
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "PackageCell.h"

@interface PackageCell()

@property (weak, nonatomic) IBOutlet UIImageView *ivUnread;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *containerLeadingConstraint;

@end

@implementation PackageCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
        
        _ivUnread.alpha = 0.0;
    }
    return self;
}

-(void) prepareForReuse
{
    [super prepareForReuse];
    
    self.accessoryView = nil;
    self.ivUnread.alpha = 0.0;
    self.containerLeadingConstraint.constant = 16.0;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void) setUnRead:(BOOL)unRead
{
    _unRead = unRead;
    
    self.ivUnread.alpha = unRead ? 1.0 : 0.0;
    self.containerLeadingConstraint.constant = unRead ? 28.0 : 16.0;
}

@end
