//
//  PasteboardSuggestionView.m
//  PostaMD
//
//  Created by Andrei Zaharia on 7/29/16.
//  Copyright © 2016 Andrei Zaharia. All rights reserved.
//

#import "PasteboardSuggestionView.h"

@implementation PasteboardSuggestionView

-(void) awakeFromNib
{
    [super awakeFromNib];
    
    self.layer.borderWidth = 1.0 / [UIScreen mainScreen].scale;
    self.layer.borderColor = [[UIColor colorWithWhite:0.333 alpha:0.500] CGColor];
    self.layer.cornerRadius = 4.0;
    
    self.layer.shadowOffset = CGSizeMake(0.0, 2);
    self.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.layer.shadowRadius = 5.0;
    self.layer.shadowOpacity = .25;
}

@end
