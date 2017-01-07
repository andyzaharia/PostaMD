//
//  ViewController.m
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "AddPackageViewController.h"
#import "Package.h"
#import "Package+CoreDataProperties.h"
#import "DataLoader.h"
#import <MBProgressHUD/MBProgressHUD.h>
#import "UIAlertController+Alert.h"
#import "NSString+Utils.h"
#import "Constants.h"

@interface AddPackageViewController () <UITextFieldDelegate>

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
    self.tfTrackingNumber.keyboardType = UIKeyboardTypeASCIICapable;
    
    if (self.autoFillTrackingNumber.length) {
        [self.tfTrackingNumber setText: self.autoFillTrackingNumber];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkPasteboardValue)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

#pragma mark -

-(void) checkPasteboardValue
{
    // Lets check first if we actually have this controller as the visible one in the Navigation stack
    if (self.navigationController.topViewController != self) {
        // Bail out.
        return;
    }
    
    NSString *pasteboardValue = [UIPasteboard generalPasteboard].string;
    if ([pasteboardValue isValidTrackingNumber]) {
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *ignoredItems = [defaults objectForKey: kDEFAULTS_IGNORED_TRACKING_NUMBERS_KEY];
        if ([ignoredItems containsObject: pasteboardValue]) {
            return;
        }
        
        NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
        [context performBlock:^{
            Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:pasteboardValue inContext: context];
            if (package == nil) {
                // Show Clipboard tracking number add request.
                self.tfTrackingNumber.text = pasteboardValue;
            }
        }];
    }
}

- (IBAction)save:(id)sender {
    
    [self.view endEditing: YES];
    
    if (self.tfTrackingNumber.text.length == 0) {
        [UIAlertController info: NSLocalizedString(@"Empty tracking number not allowed.", nil)];
        return;
    }

    if (self.tfName.text.length == 0) {
        [UIAlertController info: NSLocalizedString(@"Empty name not allowed.", nil)];
        return;
    }
    
    if (![self.tfTrackingNumber.text isValidTrackingNumber]) {
        [UIAlertController info: NSLocalizedString(@"Invalid tracking number.", nil)];
        return;
    }
    
    BOOL __block itemAlreadyExists = NO;
    NSString *__block alreadyExistingPackageName = nil;
    NSString *trackingNumberStr = [self.tfTrackingNumber.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlockAndWait:^{
        Package *package = [Package findFirstByAttribute: @"trackingNumber"
                                               withValue: trackingNumberStr
                                               inContext: context];
        if (package) {
            itemAlreadyExists = YES;
            alreadyExistingPackageName = package.name;
        }
    }];
    
    if (itemAlreadyExists) {
        NSString *message = NSLocalizedString(@"An item with this tracking number already exists.", nil);
        if (alreadyExistingPackageName.length) {
            message = [message stringByAppendingFormat:@"\n The item is called %@.", alreadyExistingPackageName];
        }
        [UIAlertController info: message];
        return;
    }
   
    [context performBlockAndWait:^{
        Package *package = [Package createEntityInContext: context];
        package.name = self.tfName.text;
        package.trackingNumber = trackingNumberStr;
        package.date = [NSDate date];
        package.received = @(NO);
        
        NSError *error;
        [context save: &error];
        
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
        }
    }];
    
    [MBProgressHUD showHUDAddedTo:self.view animated: YES];
    
    AddPackageViewController *__weak weakSelf = self;
    [[DataLoader shared] getTrackingInfoForItemWithID:trackingNumberStr
                                               onDone:^(id data) {
                                                   [weakSelf.navigationController popViewControllerAnimated: YES];
                                                   [MBProgressHUD hideHUDForView:weakSelf.view animated: YES];
                                               } onFailure:^(NSError *error) {
                                                   [weakSelf.navigationController popViewControllerAnimated: YES];
                                                   [MBProgressHUD hideHUDForView:weakSelf.view animated: YES];
                                               }];
    
    [[DataLoader shared] syncWithCloudKit];
}

- (IBAction)postTrack:(id)sender {

}

- (IBAction)pasteText:(id)sender {
    
    if ([self.tfTrackingNumber isFirstResponder]) {
        [self.tfTrackingNumber paste: sender];
    } else if ([self.tfName isFirstResponder]) {
        [self.tfName paste: sender];
    } else {
        NSString *pasteboardValue = [UIPasteboard generalPasteboard].string;
        if ([pasteboardValue isValidTrackingNumber]) {
            self.tfTrackingNumber.text = pasteboardValue;
            [self.tfName becomeFirstResponder];
        }
    }
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    textField.placeholder = @"EE123456789XX";
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == self.tfTrackingNumber) {
        
        if ([string isEqualToString:@"\n"]) {
            if ((self.tfName.text.length > 0) && ([self.tfTrackingNumber.text isValidTrackingNumber])) {
                [self save: nil];
            }
        }
        
        NSString *freshStr = [textField.text stringByReplacingCharactersInRange:range withString: string];

        NSString *notAllowedStr = [freshStr stringByTrimmingCharactersInSet: [NSCharacterSet alphanumericCharacterSet]];
        if (notAllowedStr.length > 0) {
            return NO;
        }
    }
    
    return YES;
}

@end
