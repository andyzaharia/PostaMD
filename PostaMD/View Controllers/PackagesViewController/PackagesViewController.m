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
#import "MBProgressHUD.h"
#import "UITableView+RemoveSeparators.h"
#import "NSManagedObjectContext+CloudKit.h"
#import "UIAlertView+Alert.h"

@interface PackagesViewController () <NSFetchedResultsControllerDelegate>
{
    NSInteger _totalItemsToRefresh;
}

@property (nonatomic, strong) NSFetchedResultsController          *fetchedResultsController;

@end

@implementation PackagesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView removeExtraSeparators];
    [self loadData];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshData) forControlEvents: UIControlEventValueChanged];
    [self.tableView addSubview: self.refreshControl];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:YES];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:YES];
}

-(void) loadData
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    
    NSSortDescriptor *sortByReceived = [[NSSortDescriptor alloc] initWithKey:@"received" ascending: YES];
    NSSortDescriptor *sortByDate = [[NSSortDescriptor alloc] initWithKey:@"date" ascending: NO];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName: @"Package"];
    [request setSortDescriptors: @[sortByReceived, sortByDate]];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                        managedObjectContext:context
                                                                          sectionNameKeyPath:@"received"
                                                                                   cacheName:nil];
    self.fetchedResultsController.delegate = self;
    NSError *error;
    if (![self.fetchedResultsController performFetch:&error]) {
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

#pragma mark -

-(void) updateHudProgressWithItemsToRefresh: (NSInteger) itemsToRefresh
{
    NSArray *huds = [MBProgressHUD allHUDsForView: self.navigationController.view];
    MBProgressHUD *hud = huds.firstObject;
    if (hud) {
        NSInteger refreshedItems = _totalItemsToRefresh - itemsToRefresh;
        CGFloat progress = (float)refreshedItems / (float)(_totalItemsToRefresh);
        [hud setProgress: progress];
    }
}

-(void) downloadTrackingDataWithTrackingNumbers: (NSMutableArray *) trackingNumbers forIndex: (NSInteger) index
{
    __weak PackagesViewController *weakSelf = self;
    [[DataLoader shared] getTrackingInfoForItemWithID: trackingNumbers[index]
                                               onDone: ^(id data) {
                                                   [trackingNumbers removeObjectAtIndex: index];
                                                   [weakSelf updateHudProgressWithItemsToRefresh: trackingNumbers.count];
                                                   
                                                   if ([trackingNumbers count] == 0) {
                                                       [weakSelf didFinishDownloading];
                                                   } else {
                                                       [weakSelf downloadTrackingDataWithTrackingNumbers: trackingNumbers forIndex: 0];
                                                   }
                                          
                                               } onFailure:^(NSError *error) {
                                                   [trackingNumbers removeObjectAtIndex: index];
                                                   [weakSelf updateHudProgressWithItemsToRefresh: trackingNumbers.count];
                                                   
                                                   if ([trackingNumbers count] == 0) {
                                                       [weakSelf didFinishDownloading];
                                                   } else {
                                                       [weakSelf downloadTrackingDataWithTrackingNumbers: trackingNumbers forIndex: 0];
                                                   }
                                               }];
}

-(void) didFinishDownloading
{
    [MBProgressHUD hideAllHUDsForView:self.navigationController.view animated: YES];
    [self.refreshControl endRefreshing];
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
}

-(void) refreshData
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"received == NO"];
    _totalItemsToRefresh = [Package countOfEntitiesWithPredicate: predicate];
    
    if (_totalItemsToRefresh) {
        [self refreshDataWithHud: NO];
    } else {
        [self.refreshControl endRefreshing];
    }
}

-(void) refreshDataWithHud: (BOOL) withHudPresent
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"received == NO"];
    _totalItemsToRefresh = [Package countOfEntitiesWithPredicate: predicate];
    
    NSMutableArray *trackingNumbers = [NSMutableArray arrayWithCapacity: _totalItemsToRefresh];
    for (int i = 0; i < _totalItemsToRefresh; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow: i inSection: 0];
        Package *package = [self.fetchedResultsController objectAtIndexPath: indexPath];
        if (!package.received.boolValue || (package.info.count == 0)) {
            [trackingNumbers addObject: package.trackingNumber];
        }
    }
    
    if ([trackingNumbers count]) {
        _totalItemsToRefresh = trackingNumbers.count;
        
        if (withHudPresent) {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated: YES];
            [hud setLabelText: NSLocalizedString(@"Loading...", nil)];
            [hud setMode: _totalItemsToRefresh <= 1 ? MBProgressHUDModeIndeterminate : MBProgressHUDModeDeterminateHorizontalBar];
            [hud setDimBackground: YES];
            
            [self.navigationItem.rightBarButtonItem setEnabled: NO];
        }
        
        [self downloadTrackingDataWithTrackingNumbers: trackingNumbers forIndex: 0];
    }
    
    [[DataLoader shared] syncWithCloudKit];
}

-(void) deletePackage: (Package *) package
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlock:^{
        if (package.cloudID.length) {
            //[SVProgressHUD showWithMaskType: SVProgressHUDMaskTypeBlack];
            
            [context cloudKitDeleteObject:package
                    andRecordNameProperty:@"cloudID"
                               completion:^(NSError *error) {
                                   dispatch_async(dispatch_get_main_queue(), ^(void){
                                       //[SVProgressHUD dismiss];
                                       if (error) [UIAlertView error: error.localizedDescription];
                                   });
                               }];
        } else {
            [context deleteObject: package];
        }
        [context save: nil];
    }];
}

#pragma mark - Actions

- (IBAction)refreshPackages:(id)sender {
    [self refreshDataWithHud: YES];
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return (section == 0) ? NSLocalizedString(@"Waiting", nil) : NSLocalizedString(@"Received", nil);
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

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        Package *package = [self.fetchedResultsController objectAtIndexPath: indexPath];
        [self deletePackage: package];
    }  else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

-(void) configureCell: (PackageCell *) cell forIndexPath: (NSIndexPath *) indexPath
{
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"eventId" ascending: YES];
    Package *package = [self.fetchedResultsController objectAtIndexPath: indexPath];
    [package.managedObjectContext performBlockAndWait:^{
        NSArray *items = [package.info allObjects];
        items = [items sortedArrayUsingDescriptors:@[descriptor]];
        
        TrackingInfo *lastTrackInfo = [items lastObject];
        if (lastTrackInfo) {
            NSString *trackingStr = (lastTrackInfo) ? lastTrackInfo.eventStr : @"";
            if ([lastTrackInfo.localityStr length]) {
                trackingStr = [trackingStr stringByAppendingFormat:@" - %@", lastTrackInfo.localityStr];
            }
            cell.lbLastTrackingInfo.text = trackingStr;
            cell.lastTrackingInfoHeightConstraint.constant = 21.0;
        } else {
            cell.lbLastTrackingInfo.text = NSLocalizedString(@"No data.", nil);
            cell.lastTrackingInfoHeightConstraint.constant = 21.0;
        }
        
        cell.lbName.text = package.name;
        cell.lbTrackingNumber.text = package.trackingNumber;
        cell.accessoryType = ([package.received boolValue]) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryDisclosureIndicator;
    }];
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
        default:;
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
