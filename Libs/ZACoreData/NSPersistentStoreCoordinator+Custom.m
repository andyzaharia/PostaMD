//
//  NSPersistentStoreCoordinator+Custom.m
//
//
//  Created by Andrei Zaharia on 9/18/13.
//  Copyright (c) 2013 Andy. All rights reserved.
//

#import "NSPersistentStoreCoordinator+Custom.h"

@implementation NSPersistentStoreCoordinator (Custom)

static NSPersistentStoreCoordinator *_sharedPersistentStore = nil;
static NSString *_dataModelName = nil;
static NSString *_storeFileName = nil;

+ (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

+ (void) setDataModelName: (NSString *) name withStoreName: (NSString *) storeFileName {
    _dataModelName = name;
    _storeFileName = storeFileName;
}

+(NSPersistentStoreCoordinator *) sharedPersisntentStoreCoordinator
{
    @synchronized (_sharedPersistentStore) {
        //NSAssert(_dataModelName, @"Core Data model name has not been set. Use [NSPersistentStoreCoordinator setDataModelName:].");
        
        if (!_sharedPersistentStore && _dataModelName) {
            NSString *storePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent: _storeFileName];
            NSURL *storeUrl = [NSURL fileURLWithPath:storePath];
            
            NSBundle *bundle = [NSBundle mainBundle];
            NSString *resourcePath = [bundle resourcePath];
            NSString *modelFileName = [_dataModelName stringByAppendingPathExtension:@"momd"];
            NSString *modelPath = [resourcePath stringByAppendingPathComponent: modelFileName];
            
            NSURL *modelUrl = [NSURL fileURLWithPath: modelPath];
            
            NSManagedObjectModel *_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL: modelUrl];
            
            NSMutableDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @(YES),
                                             NSInferMappingModelAutomaticallyOption : @(YES)}.mutableCopy;
            
            NSError *error;
            _sharedPersistentStore = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: _managedObjectModel];
            if (![_sharedPersistentStore addPersistentStoreWithType: NSSQLiteStoreType
                                                      configuration: nil
                                                                URL: storeUrl
                                                            options: options
                                                              error: &error]) {
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }
        
        return _sharedPersistentStore;
    }
}

+ (void) setNewPresistentStore: (NSPersistentStoreCoordinator *) store
{
    _sharedPersistentStore = store;
}

@end
