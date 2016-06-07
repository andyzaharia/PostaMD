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
#import "Package+CoreDataProperties.h"
#import "DataLoader.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "UIAlertView+Alert.h"

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
    
    //RR123456785RO
}

- (IBAction)save:(id)sender {
    
    [self.view endEditing: YES];
    
    if (self.tfTrackingNumber.text.length == 0) {
        [UIAlertView info: NSLocalizedString(@"Empty tracking number not allowed.", nil)];
        return;
    }

    if (self.tfName.text.length == 0) {
        [UIAlertView info: NSLocalizedString(@"Empty name not allowed.", nil)];
        return;
    }
    
    if (![self isValidTrackingNumber: self.tfTrackingNumber.text]) {
        [UIAlertView info: NSLocalizedString(@"Invalid tracking number.", nil)];
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
        [UIAlertView info: message];
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
    
    [SVProgressHUD showWithMaskType: SVProgressHUDMaskTypeBlack];
    
    AddPackageViewController *__weak weakSelf = self;
    [[DataLoader shared] getTrackingInfoForItemWithID:trackingNumberStr
                                               onDone:^(id data) {
                                                   [weakSelf.navigationController popViewControllerAnimated: YES];
                                                   [SVProgressHUD dismiss];
                                               } onFailure:^(NSError *error) {
                                                   [weakSelf.navigationController popViewControllerAnimated: YES];
                                                   [SVProgressHUD dismiss];
                                               }];
    
    [[DataLoader shared] syncWithCloudKit];
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

#pragma mark -

-(BOOL) isValidTrackingNumber: (NSString *) trackingNumberStr
{
    NSError *error = NULL;
    NSString *pattern = @"^[A-Z]{2}\\d{9}[A-Z]{2}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern: pattern
                                                                           options: NSRegularExpressionCaseInsensitive
                                                                             error: &error];
   
    NSArray *matches = [regex matchesInString: trackingNumberStr
                                      options: 0
                                        range: NSMakeRange(0, trackingNumberStr.length)];
    return matches.count > 0;
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
            if ((self.tfName.text.length > 0) && ([self isValidTrackingNumber: self.tfTrackingNumber.text])) {
                [self save: nil];
            }
        }
        
        NSString *freshStr = [textField.text stringByReplacingCharactersInRange:range withString: string];

        NSString *notAllowedStr = [freshStr stringByTrimmingCharactersInSet: [NSCharacterSet alphanumericCharacterSet]];
        if (notAllowedStr.length > 0) {
            return NO;
        }
        
        UIKeyboardType keyboardType = UIKeyboardTypeDefault;
        if ((freshStr.length < 2) || (freshStr.length >= maxTrackingNumberLength - 2)) {
            //Check if the first 2 chars and the last 2 are letters.
            if ((freshStr.length > 0) && (freshStr.length <= 2)) {
                NSString *prefixSubString = [freshStr substringWithRange:NSMakeRange(0, freshStr.length)];
                NSString *notAllowedStr = [prefixSubString stringByTrimmingCharactersInSet: [NSCharacterSet letterCharacterSet]];
                if (notAllowedStr.length > 0) {
                    return NO;
                }
            }
            
            // Check the last 2 characters.
            if (freshStr.length > maxTrackingNumberLength - 2) {
                NSRange range = NSMakeRange(maxTrackingNumberLength - 2 , freshStr.length - (maxTrackingNumberLength - 2));
                NSString *suffixSubString = [freshStr substringWithRange: range];
                NSString *notAllowedStr = [suffixSubString stringByTrimmingCharactersInSet: [NSCharacterSet letterCharacterSet]];
                if (notAllowedStr.length > 0) {
                    return NO;
                }
            }
            
            
            keyboardType = UIKeyboardTypeASCIICapable;
        } else {
            keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        }
        
        if (keyboardType != textField.keyboardType) {
            [textField setKeyboardType: keyboardType];
            [textField reloadInputViews];
        }
        
        
        return (freshStr.length <= maxTrackingNumberLength);
    }
    
    return YES;
}

@end
