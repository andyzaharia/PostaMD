//
//  AboutViewController.m
//  PostaMD
//
//  Created by Andrei Zaharia on 10/16/15.
//  Copyright © 2015 Andrei Zaharia. All rights reserved.
//

#import "AboutViewController.h"
#import <MessageUI/MessageUI.h>
#import "UIAlertView+Alert.h"

@interface AboutViewController () <MFMailComposeViewControllerDelegate>

@end

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:YES];
}

#pragma mark -

-(IBAction)contactMe:(id)sender {
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        mailer.mailComposeDelegate = self;
        [mailer setSubject:@"Support Message"];
        
        [mailer setToRecipients:@[@"andyzaharia@me.com"]];
        
        [self presentViewController:mailer animated: YES completion: nil];
    }  else {
        [UIAlertView error: @"You have to set up an email account first."];
    }
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    [controller dismissViewControllerAnimated:YES completion: nil];
}

@end
