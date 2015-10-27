//
//  ViewController.m
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "AddPackageViewController.h"
#import "AFNetworking.h"
#import "TFHpple.h"
#import "Package.h"
#import "DataLoader.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface AddPackageViewController ()

@property (weak, nonatomic) IBOutlet UITextField *tfName;
@property (weak, nonatomic) IBOutlet UITextField *tfTrackingNumber;

@end

@implementation AddPackageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.tfName.layer.borderWidth = 1.0;
    self.tfName.layer.borderColor = [[UIColor colorWithWhite:0.9 alpha:1.000] CGColor];
    self.tfName.layer.cornerRadius = 3.0;
    
    self.tfTrackingNumber.layer.borderWidth = 1.0;
    self.tfTrackingNumber.layer.borderColor = [[UIColor colorWithWhite:0.9 alpha:1.000] CGColor];
    self.tfTrackingNumber.layer.cornerRadius = 3.0;
    
    self.tfName.leftView = [[UIView alloc] initWithFrame: CGRectMake(0.0, 0.0, 10.0, 0.0)];
    self.tfName.leftViewMode = UITextFieldViewModeAlways;
    
    self.tfTrackingNumber.leftView = [[UIView alloc] initWithFrame: CGRectMake(0.0, 0.0, 10.0, 0.0)];
    self.tfTrackingNumber.leftViewMode = UITextFieldViewModeAlways;
}

- (IBAction)save:(id)sender {
    
    [self.view endEditing: YES];

    [SVProgressHUD showWithMaskType: SVProgressHUDMaskTypeBlack];
    
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlockAndWait:^{
        Package *package = [Package createEntityInContext: context];
        package.name = self.tfName.text;
        package.trackingNumber = self.tfTrackingNumber.text;
        package.date = [NSDate date];
        [context save];
    }];
    
    
    __weak AddPackageViewController *weakSelf = self;
    [[DataLoader shared] getTrackingInfoForItemWithID: self.tfTrackingNumber.text
                                               onDone:^(id data) {
                                                   [weakSelf.navigationController popViewControllerAnimated: YES];
                                                   [SVProgressHUD dismiss];
                                               } onFailure:^(NSError *error) {
                                                   [weakSelf.navigationController popViewControllerAnimated: YES];
                                                   [SVProgressHUD dismiss];
                                               }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)postTrack:(id)sender {

}

- (IBAction)pasteText:(id)sender {
    
    if ([self.tfTrackingNumber isFirstResponder]) {
        [self.tfTrackingNumber paste: sender];
    }
    
    if ([self.tfName isFirstResponder]) {
        [self.tfName paste: sender];
    }

}

@end
