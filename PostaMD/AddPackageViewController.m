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


@interface AddPackageViewController ()


@property (weak, nonatomic) IBOutlet UITextField *tfName;
@property (weak, nonatomic) IBOutlet UITextField *tfTrackingNumber;

@end

@implementation AddPackageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)save:(id)sender {
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlockAndWait:^{
        
        Package *package = [Package createEntityInContext: context];
        package.name = self.tfName.text;
        package.trackingNumber = self.tfTrackingNumber.text;
        package.date = [NSDate date];
        [context save];

    }];
    
    [DataLoader getTrackingInfoForItemWithID: self.tfTrackingNumber.text
                                      onDone:^(id data) {
                                      } onFailure:^(NSError *error) {
                                          
                                      }];
    
    [self.navigationController popViewControllerAnimated: YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)postTrack:(id)sender {

}

- (IBAction)pasteTrackingNumber:(id)sender {
    if (![self.tfTrackingNumber isFirstResponder]) {
        [self.tfTrackingNumber becomeFirstResponder];
    }
    
    [self.tfTrackingNumber paste: sender];
    
    [self.tfName becomeFirstResponder];
}

@end
