//
//  PackageInfoViewController.m
//  PostaMD
//
//  Created by Andrei Zaharia on 3/1/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "PackageInfoViewController.h"
#import "TrackingInfoCell.h"
#import "DataLoader.h"
#import "SVProgressHUD.h"
#import "UITableView+RemoveSeparators.h"

@interface PackageInfoViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong)           NSFetchedResultsController          *fetchedResultsController;
@property (weak, nonatomic) IBOutlet UITextField *tfTrackingNumber;

@end

@implementation PackageInfoViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = self.package.name;
    self.tfTrackingNumber.text = self.package.trackingNumber;

    if ([self.package.received boolValue]) {
        self.navigationItem.rightBarButtonItem = nil;
    }
    
    __weak PackageInfoViewController *weakSelf = self;
    
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserverForName:NSManagedObjectContextDidSaveNotification
                                    object:context
                                     queue:nil
                                usingBlock:^(NSNotification *note) {
                                    NSManagedObjectContext *savedContext = [note object];
                                    if (savedContext == context) {
                                        return;
                                    }
                                    
                                    dispatch_sync(dispatch_get_main_queue(), ^{
                                        [weakSelf.tableView reloadData];
                                    });
                                }];
    
    [self.tableView removeExtraSeparators];
    [self loadData];
}

-(void) loadData
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"package == %@", self.package];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"eventId" ascending: YES];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName: @"TrackingInfo"];
    [request setFetchBatchSize: 20];
    [request setPredicate: predicate];
    [request setSortDescriptors: @[sort]];
    
    NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest: request
                                                                                 managedObjectContext: context
                                                                                   sectionNameKeyPath: nil
                                                                                            cacheName: nil];
    self.fetchedResultsController = controller;
    NSError *error;
    controller.delegate = self;
    if (![[self fetchedResultsController] performFetch:&error]) {
        // Update to handle the error appropriately.
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TrackingInfo";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    [self configureCell:(id)cell forIndexPath: indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.tfTrackingNumber isFirstResponder]) {
        [self.tfTrackingNumber resignFirstResponder];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated: YES];
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

- (IBAction)refreshData:(id)sender {

    [SVProgressHUD showWithMaskType: SVProgressHUDMaskTypeBlack];
    
    __weak PackageInfoViewController *weakSelf = self;
    
    [[DataLoader shared] getTrackingInfoForItemWithID: self.package.trackingNumber
                                               onDone: ^(id data) {
                                                   [SVProgressHUD dismiss];
                                                   [weakSelf loadData];
                                          
                                               } onFailure:^(NSError *error) {
                                                   [SVProgressHUD dismiss];
                                               }];
}

-(void) configureCell: (TrackingInfoCell *) cell forIndexPath: (NSIndexPath *) indexPath
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:indexPath.section];
    
    if (indexPath.row < [sectionInfo numberOfObjects]) {
        TrackingInfo *lastTrackInfo = [self.fetchedResultsController objectAtIndexPath: indexPath];
        
        cell.lbInfo.text = lastTrackInfo.eventStr;
        cell.lbDate.text = lastTrackInfo.dateStr;
        cell.lbCountry.text = [lastTrackInfo.countryStr stringByAppendingFormat:@" - %@", lastTrackInfo.localityStr];
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        default: ;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:(id)[tableView cellForRowAtIndexPath:indexPath] forIndexPath: indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlockAndWait:^{
        self.package.trackingNumber = self.tfTrackingNumber.text;
        [context save: nil];
    }];
    
    [textField resignFirstResponder];
    return YES;
}

@end
