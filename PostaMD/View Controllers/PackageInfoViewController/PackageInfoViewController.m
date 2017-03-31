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
#import <MBProgressHUD/MBProgressHUD.h>
#import "UITableView+RemoveSeparators.h"

@interface PackageInfoViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong)           NSFetchedResultsController      *fetchedResultsController;
@property (weak, nonatomic) IBOutlet    UITextField                     *tfTrackingNumber;

@property (nonatomic, strong) NSMutableArray *cellExpandedState;

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

    self.tableView.estimatedRowHeight = 66.0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    self.cellExpandedState = [NSMutableArray array];
    
    if ([self.package.received boolValue]) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                                               target:self
                                                                                               action:@selector(delete:)];
    }
    
    PackageInfoViewController *__weak weakSelf = self;
    
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear: animated];
    
    if(self.package) {
        if (self.package.unread.boolValue) {
            [self.package.managedObjectContext performBlock:^{
                self.package.unread = @(NO);
                [self.package.managedObjectContext recursiveSave];
            }];
        }
    }
}

#pragma mark -

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

#pragma mark - Actions

- (IBAction)refreshData:(id)sender {
    
    [MBProgressHUD showHUDAddedTo:self.view animated: YES];
    
    __weak PackageInfoViewController *weakSelf = self;
    
    [[DataLoader shared] getTrackingInfoForItemWithID: self.package.trackingNumber
                                               onDone: ^(id data) {
                                                   [MBProgressHUD hideHUDForView:weakSelf.view animated: YES];
                                                   [weakSelf loadData];
                                                   
                                               } onFailure:^(NSError *error) {
                                                   [MBProgressHUD hideHUDForView:weakSelf.view animated: YES];
                                               }];
}

-(void) delete:(id)sender
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Are you sure?"
                                                                        message:nil
                                                                 preferredStyle:UIAlertControllerStyleActionSheet];
    [controller addAction:[UIAlertAction actionWithTitle:@"Yes"
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     if(self.package) [Package deleteWithItem: self.package];
                                                     self.package = nil;
                                                     [self.navigationController popViewControllerAnimated: YES];
                                                 }]];
    [controller addAction:[UIAlertAction actionWithTitle:@"No"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction * _Nonnull action) {
                                                     
                                                 }]];
    [self presentViewController:controller animated:YES completion: nil];
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
    
    //id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:indexPath.section];
    //TrackingInfo *lastTrackInfo = [self.fetchedResultsController objectAtIndexPath: indexPath];
    //NSLog(@"%@", lastTrackInfo);
    
    NSNumber *expandedState = self.cellExpandedState[indexPath.row];
    [self.cellExpandedState replaceObjectAtIndex:indexPath.row withObject: @(!expandedState.boolValue)];
    
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation: UITableViewRowAnimationFade];
}

-(void) configureCell: (TrackingInfoCell *) cell forIndexPath: (NSIndexPath *) indexPath
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:indexPath.section];
    __weak PackageInfoViewController *weakSelf = self;
    
    if (indexPath.row < [sectionInfo numberOfObjects]) {
        TrackingInfo *trackingInfo = [self.fetchedResultsController objectAtIndexPath: indexPath];
        
        NSNumber *expandedState = @(NO);
        if (indexPath.row < self.cellExpandedState.count) {
            expandedState = self.cellExpandedState[indexPath.row];
        } else {
            [self.cellExpandedState addObject: expandedState];
        }
        
        [cell configureWithInfo:trackingInfo expanded: expandedState.boolValue];
        [cell setOnExpandToggle: ^{
            [weakSelf tableView:weakSelf.tableView didSelectRowAtIndexPath: indexPath];
        }];
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
        [context recursiveSave];
    }];
    
    [textField resignFirstResponder];
    return YES;
}

@end
