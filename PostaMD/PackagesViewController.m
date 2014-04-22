//
//  PackagesViewController.m
//  PostaMD
//
//  Created by Andrei Zaharia on 2/28/14.
//  Copyright (c) 2014 Andrei Zaharia. All rights reserved.
//

#import "PackagesViewController.h"
#import "PackageCell.h"
#import "Package.h"
#import "TrackingInfo.h"
#import "DataLoader.h"
#import "PackageInfoViewController.h"
#import "SVProgressHUD.h"

@interface PackagesViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong)           NSFetchedResultsController          *fetchedResultsController;

@end

@implementation PackagesViewController

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

    [self loadData];
    
    __weak PackagesViewController *weakSelf = self;
    
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

}

-(void) loadData
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    NSPredicate *predicate = [NSPredicate predicateWithValue: YES];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"date" ascending: NO];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName: @"Package"];
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

-(void) downloadTrackingDataWithTrackingNumbers: (NSMutableArray *) trackingNumbers forIndex: (NSInteger) index
{
    __weak PackagesViewController *weakSelf = self;
    [DataLoader getTrackingInfoForItemWithID: trackingNumbers[index]
                                      onDone: ^(id data) {
                                          [trackingNumbers removeObjectAtIndex: index];
                                          
                                          if ([trackingNumbers count] == 0) {
                                              [SVProgressHUD dismiss];
                                          } else {
                                              [weakSelf downloadTrackingDataWithTrackingNumbers: trackingNumbers forIndex: 0];
                                          }
                                          
                                      } onFailure:^(NSError *error) {
                                          [trackingNumbers removeObjectAtIndex: index];
                                          
                                          if ([trackingNumbers count] == 0) {
                                              [SVProgressHUD dismiss];
                                          } else {
                                              [weakSelf downloadTrackingDataWithTrackingNumbers: trackingNumbers forIndex: 0];
                                          }
                                      }];
}

- (IBAction)refreshPackages:(id)sender {
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex: 0];
    __block NSInteger itemsToFetch = [sectionInfo numberOfObjects];
    
    NSMutableArray *trackingNumbers = [NSMutableArray arrayWithCapacity: itemsToFetch];
    for (int i = 0; i < itemsToFetch; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow: i inSection: 0];
        Package *package = [self.fetchedResultsController objectAtIndexPath: indexPath];
        if (![package.received boolValue]) {
            [trackingNumbers addObject: package.trackingNumber];
        }
    }
    
    if ([trackingNumbers count]) {
        [[SVProgressHUD appearance] setHudBackgroundColor: [UIColor blackColor]];
        [[SVProgressHUD appearance] setHudForegroundColor: [UIColor whiteColor]];
        [SVProgressHUD show];
        
        [self downloadTrackingDataWithTrackingNumbers: trackingNumbers forIndex: 0];
    }
}

#pragma mark -

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"PackageInfo"]) {
        
        NSIndexPath *indexPath = [self.tableView indexPathForCell: sender];
        if (indexPath) {
            PackageInfoViewController *controller = segue.destinationViewController;
            controller.package = [self.fetchedResultsController objectAtIndexPath: indexPath];
        }
    } else {
        
    }
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
    static NSString *CellIdentifier = @"PackageCell";
    PackageCell *cell = (PackageCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forIndexPath: indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
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


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        Package *package = [self.fetchedResultsController objectAtIndexPath: indexPath];
        
        NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
        [context performBlockAndWait:^{
            [context deleteObject: package];
            [context save];
        }];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}


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

-(void) configureCell: (PackageCell *) cell forIndexPath: (NSIndexPath *) indexPath
{
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"date" ascending: YES];
    Package *package = [self.fetchedResultsController objectAtIndexPath: indexPath];
    NSArray *items = [package.info allObjects];
    items = [items sortedArrayUsingDescriptors:@[descriptor]];
    
    TrackingInfo *lastTrackInfo = [items lastObject];
    if (lastTrackInfo) {
        cell.lbLastTrackingInfo.text = (lastTrackInfo) ? lastTrackInfo.eventStr : @"";
    } else {
        cell.lbLastTrackingInfo.text = @"";
    }
    
    cell.lbName.text = package.name;
    cell.lbTrackingNumber.text = package.trackingNumber;
    cell.accessoryType = ([package.received boolValue]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryDisclosureIndicator;
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

@end
