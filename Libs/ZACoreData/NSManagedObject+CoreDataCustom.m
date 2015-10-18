//
//  NSManagedObject+CoreData.m
//  GolfOle
//
//  Created by Admin on 16.10.2012.
//  Copyright (c) 2012 Andrei Zaharia. All rights reserved.
//

#import "NSManagedObject+CoreDataCustom.h"

@implementation NSManagedObject (CoreDataCustom)

static NSDateFormatter *_dateFormatter = nil;

// Used to convert value to their corresponding types, its not 100% completed
-(void) setUnkownValue: (id) value forKey: (NSString *) key
{
    NSAttributeDescription *attribute = [self.entity.attributesByName objectForKey: key];
    NSAttributeType type = attribute.attributeType;
    
    if([value isKindOfClass:[NSString class]])
    {
        if ((type == NSInteger16AttributeType) || (type == NSInteger32AttributeType) || (type == NSInteger64AttributeType)) {
            
            if ([value isKindOfClass:[NSString class]]) {
                [self setValue: [NSNumber numberWithInteger:[(NSString *)value integerValue]]
                        forKey: key];
            }
        }
        else
            if (type == NSDoubleAttributeType) {
                [self setValue: [NSNumber numberWithDouble:[(NSString *)value doubleValue]]
                        forKey: key];
            }
            else
                if (type == NSFloatAttributeType) {
                    [self setValue: [NSNumber numberWithFloat:[(NSString *)value floatValue]]
                            forKey: key];
                }
                else
                    if (type == NSBooleanAttributeType) {
                        [self setValue: [NSNumber numberWithBool:[(NSString *)value boolValue]]
                                forKey: key];
                    }
                        else
                            if (type == NSDateAttributeType) {
                                @synchronized(_dateFormatter)
                                {
                                    if (!_dateFormatter) {
                                        _dateFormatter = [[NSDateFormatter alloc] init];
                                        [_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                                        [_dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
                                        [_dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
                                    }

                                    NSDate *date = [_dateFormatter dateFromString: value];
                                    [self setValue: date forKey: key];
                                }
                            }
                            else
                                [self setValue:value forKey: key];
    }
    else
        [self setValue:value forKey: key];
}

-(void) setValue:(id)value forCustomMappedKey:(NSString *)key
{
    if ([key isEqualToString:@"Id"]) {
        [self setUnkownValue:value forKey: @"userID"];
    }
}

-(void) setPropertiesFromDictionary: (NSDictionary *) info
{
    NSArray *infoKeys = [info allKeys];
    NSArray *attributeNames  = [self.entity.attributesByName allKeys];
    [infoKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
        id value = [info valueForKey: key];
        if (![value isKindOfClass:[NSNull class]])
        {
            if ([attributeNames containsObject: key]) {
                [self setUnkownValue:value forKey: key];
            }
            else
            {
                [self setValue:value forCustomMappedKey: key];
            }
        }
    }];
}

#pragma mark -

-(void) setListToRelationName: (NSString *) relName list: (NSArray *) items clean: (BOOL) clean
{
    if ([relName length] == 0) {
        return;
    }
    
    NSString *capitalisedSelStr = [relName stringByReplacingCharactersInRange: NSMakeRange(0,1)
                                                                   withString: [[relName substringToIndex:1] capitalizedString]];
    
    SEL addSelector = NSSelectorFromString([NSString stringWithFormat:@"add%@:", capitalisedSelStr]);
    NSSet *existingObjects = [self valueForKey: relName];
    
    if(clean) {
        
        __block NSMutableArray *_itemsToRemove = [NSMutableArray array];
        [existingObjects enumerateObjectsUsingBlock:^(NSManagedObject *existingObject, BOOL *stop) {
            
            __block BOOL exists = NO;
            [items enumerateObjectsUsingBlock:^(NSManagedObject *freshObject, NSUInteger idx, BOOL *stop) {
                if ([existingObject.objectID isEqual: freshObject.objectID]) {
                    exists = YES;
                    *stop = YES;
                }
            }];
            
            if (!exists) {
                [_itemsToRemove addObject: existingObject];
            }
        }];
        
        [_itemsToRemove enumerateObjectsUsingBlock:^(NSManagedObject *item, NSUInteger idx, BOOL *stop) {
            [[self managedObjectContext] deleteObject: item];
        }];
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:addSelector withObject:[NSSet setWithArray: items]];
    #pragma clang diagnostic pop
}

-(void) setListToRelationName: (NSString *) relName list: (NSArray *) items
{
    [self setListToRelationName:relName list: items clean: YES];
}

@end
