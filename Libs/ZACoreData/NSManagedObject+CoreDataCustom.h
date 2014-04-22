//
//  NSManagedObject+CoreData.h
//  GolfOle
//
//  Created by Admin on 16.10.2012.
//  Copyright (c) 2012 StaS Bandol. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (CoreDataCustom)

-(void) setUnkownValue: (id) value forKey: (NSString *) key;
-(void) setValue:(id)value forCustomMappedKey:(NSString *)key;
-(void) setPropertiesFromDictionary: (NSDictionary *) info;

-(void) setListToRelationName: (NSString *) relName list: (NSArray *) items clean: (BOOL) clean;


@end
