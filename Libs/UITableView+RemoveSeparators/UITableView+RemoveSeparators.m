//
//  UITableView+RemoveSeparators.m
//  SamyRoad
//
//  Created by Andrei Zaharia on 28/02/15.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "UITableView+RemoveSeparators.h"

@implementation UITableView (RemoveSeparators)

-(void) removeExtraSeparators
{
    self.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

@end
