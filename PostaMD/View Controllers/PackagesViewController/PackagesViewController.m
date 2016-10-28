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
#import "Package+CoreDataProperties.h"
#import "TrackingInfo.h"
#import "DataLoader.h"
#import "PackageInfoViewController.h"
#import "MBProgressHUD.h"
#import "UITableView+RemoveSeparators.h"
#import "NSManagedObjectContext+CloudKit.h"
#import "UIAlertController+Alert.h"
#import "NSString+Utils.h"
#import "PasteboardSuggestionView.h"
#import "AddPackageViewController.h"
#import "Constants.h"

@interface PackagesViewController () <NSFetchedResultsControllerDelegate, UISearchResultsUpdating>
{
    
}

@property (nonatomic, strong) UISearchController                  *searchController;
@property (nonatomic, strong) NSFetchedResultsController          *fetchedResultsController;

@property (nonatomic, strong) PasteboardSuggestionView            *pasteboardView;

@property (nonatomic) NSInteger totalItemsToRefresh;

@end

@implementation PackagesViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView removeExtraSeparators];
    [self loadData];
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController: nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.definesPresentationContext = YES;
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refreshData) forControlEvents: UIControlEventValueChanged];
    [self.tableView addSubview: self.refreshControl];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(checkPasteboardValue)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    //[self.navigationController setToolbarHidden:YES animated:YES];
    
    if (self.pasteboardView) {
        [self dismissSuggestionView];
    }
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //[self.navigationController setToolbarHidden:NO animated:YES];
    
    [self checkPasteboardValue];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -

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
                [self showPasteboardSuggestionWithTrackingNumber: pasteboardValue];
            }
        }];
    }
}

-(void) showPasteboardSuggestionWithTrackingNumber: (NSString *) trackingNumber
{
    if (self.pasteboardView.superview) {
        return;
    }
    
    self.pasteboardView = [[[NSBundle mainBundle] loadNibNamed:@"PasteboardSuggestionView" owner:self options: nil] lastObject];
    [self.pasteboardView setFrame: CGRectMake((self.navigationController.view.frame.size.width - self.pasteboardView.frame.size.width) * 0.5,
                                              self.navigationController.view.frame.size.height,
                                              self.pasteboardView.frame.size.width,
                                              self.pasteboardView.frame.size.height)];
    [self.navigationController.view addSubview: self.pasteboardView];
    
    [self.navigationController setToolbarHidden:YES animated: YES];
    
    [UIView animateWithDuration:0.2
                          delay:0.3
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [self.pasteboardView setFrame: CGRectMake((self.navigationController.view.frame.size.width - self.pasteboardView.frame.size.width) * 0.5,
                                                                   self.navigationController.view.frame.size.height - self.pasteboardView.frame.size.height - 20.0,
                                                                   self.pasteboardView.frame.size.width,
                                                                   self.pasteboardView.frame.size.height)];
                     } completion:^(BOOL finished) {
                         
                     }];
    
    [self.pasteboardView.btnNo addTarget:self action:@selector(dismissSuggestionView) forControlEvents: UIControlEventTouchUpInside];
    [self.pasteboardView.btnYes addTarget:self action:@selector(addSuggestedTrackingNumber) forControlEvents: UIControlEventTouchUpInside];
    [self.pasteboardView.lbTrackingNumber setText: trackingNumber];
}

#pragma mark -

-(void) updateHudProgressWithItemsToRefresh: (NSInteger) itemsToRefresh
{
    MBProgressHUD *hud = [MBProgressHUD HUDForView: self.navigationController.view];
    if (hud) {
        NSInteger refreshedItems = self.totalItemsToRefresh - itemsToRefresh;
        CGFloat progress = (float)refreshedItems / (float)(self.totalItemsToRefresh);
        [hud setProgress: progress];
    }
}

-(void) downloadTrackingDataWithTrackingNumbers: (NSMutableArray *) trackingNumbers forIndex: (NSInteger) index
{
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlock:^{
        Package *package = [Package findFirstByAttribute:@"trackingNumber" withValue:trackingNumbers[index] inContext: context];
        NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject: package];
        if(indexPath.row != NSNotFound) {
            UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleGray];
            indicatorView.hidesWhenStopped = YES;
            [indicatorView startAnimating];
            
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath: indexPath];
            cell.accessoryView = indicatorView;
        }
    }];

    
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
    [MBProgressHUD hideHUDForView:self.navigationController.view animated: YES];
    [self.refreshControl endRefreshing];
    [self.navigationItem.rightBarButtonItem setEnabled:YES];
    
    self.totalItemsToRefresh = 0;
}

-(void) refreshData
{
    if (self.totalItemsToRefresh == 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"received == NO"];
        NSInteger itemsToRefresh = [Package countOfEntitiesWithPredicate: predicate];
        
        if (itemsToRefresh) {
            [self refreshDataWithHud: NO];
        } else {
            [self.refreshControl endRefreshing];
        }
    }
}

-(void) refreshDataWithHud: (BOOL) withHudPresent
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"received == NO"];
    NSManagedObjectContext *context = [NSManagedObjectContext contextForMainThread];
    [context performBlock:^{
        NSArray *items = [Package findAllWithPredicate: predicate inContext: context];
        NSMutableArray *trackingNumbers = [NSMutableArray arrayWithArray: [items valueForKeyPath: @"trackingNumber"]];
        
        if ([trackingNumbers count]) {
            self.totalItemsToRefresh = trackingNumbers.count;
            
            if (withHudPresent) {
                MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.navigationController.view animated: YES];
                //hud.backgroundView.style = MBProgressHUDBackgroundStyleSolidColor;
                //hud.backgroundView.color = [UIColor colorWithWhite:0.f alpha:0.1f];
                
                [hud.label setText: NSLocalizedString(@"Loading...", nil)];
                [hud setMode: self.totalItemsToRefresh <= 1 ? MBProgressHUDModeIndeterminate : MBProgressHUDModeDeterminateHorizontalBar];
                
                [self.navigationItem.rightBarButtonItem setEnabled: NO];
            }
            
            [self downloadTrackingDataWithTrackingNumbers: trackingNumbers forIndex: 0];
        }
    }];
    
    [[DataLoader shared] syncWithCloudKit];
}

-(void) deletePackage: (Package *) package
{
    if(package) [Package deleteWithItem: package];
}

#pragma mark - Actions

- (IBAction)refreshPackages:(id)sender {
    if (self.totalItemsToRefresh == 0) {
        [self refreshDataWithHud: YES];
    }
}

-(void) dismissSuggestionView
{
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         [self.pasteboardView setFrame: CGRectMake((self.navigationController.view.frame.size.width - self.pasteboardView.frame.size.width) * 0.5,
                                                                   self.navigationController.view.frame.size.height,
                                                                   self.pasteboardView.frame.size.width,
                                                                   self.pasteboardView.frame.size.height)];
                     } completion:^(BOOL finished) {
                         [self.navigationController setToolbarHidden:NO animated: YES];
                         
                         [self.pasteboardView removeFromSuperview];
                         self.pasteboardView = nil;
                     }];
 
    NSString *pastBoardTackingNumber = self.pasteboardView.lbTrackingNumber.text;
    if (pastBoardTackingNumber.length) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray *ignoredItems = [defaults objectForKey: kDEFAULTS_IGNORED_TRACKING_NUMBERS_KEY];
        NSMutableArray *array = [NSMutableArray arrayWithArray: ignoredItems];
        [array addObject: pastBoardTackingNumber];
        
        [defaults setObject:array forKey: kDEFAULTS_IGNORED_TRACKING_NUMBERS_KEY];
        [defaults synchronize];
    }
}

-(void) addSuggestedTrackingNumber
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    AddPackageViewController *controller = [storyboard instantiateViewControllerWithIdentifier:@"AddPackageViewController"];
    controller.autoFillTrackingNumber = self.pasteboardView.lbTrackingNumber.text;
    [self.navigationController pushViewController:controller animated: YES];
    
    [self.pasteboardView removeFromSuperview];
    self.pasteboardView = nil;
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
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection: section];
    Package *package = [self.fetchedResultsController objectAtIndexPath: indexPath];
    
    return (package.received.boolValue == NO) ? NSLocalizedString(@"Waiting", nil) : NSLocalizedString(@"Received", nil);
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
    cell.unRead = package.unread.boolValue && (!package.received.boolValue);
    cell.accessoryView = nil;
    cell.accessoryType = (package.received.boolValue) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryDisclosureIndicator;
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

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    if(searchController.active) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name contains[cd] %@", searchController.searchBar.text];
        [self.fetchedResultsController.fetchRequest setPredicate: predicate];
    } else {
        [self.fetchedResultsController.fetchRequest setPredicate: nil];
    }
    
    [self.fetchedResultsController performFetch: nil];
    
    [UIView transitionWithView:self.tableView
                      duration:0.15
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                        [self.tableView reloadData];
                    } completion:^(BOOL finished) {
                        
                    }];
}

@end
