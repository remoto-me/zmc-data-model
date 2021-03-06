// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


@import ZMUtilities;

#import "ZMSyncMergePolicy.h"
#import "ZMConversation+Internal.h"
#import "ZMMessage+Internal.h"
#import <libkern/OSAtomic.h>


#define ZMTAG_CORE_DATA "Core Data"

static char* const ZMLogTag ZM_UNUSED = ZMTAG_CORE_DATA;
static NSString * const MessageKeyForDebugging = @"eventID";


@interface ZMSyncMergePolicy ()

/// Object to dictionary of values
@property (nonatomic) NSMapTable *objectToValueDictionaryMap;

@end



@implementation ZMSyncMergePolicy

- (instancetype)initWithMergeType:(NSMergePolicyType)type;
{
    return [super initWithMergeType:type];
}

- (BOOL)resolveConflicts:(NSArray *)list
                   error:(NSError **)outError
{
    if (ZMLogLevelIsActive(ZMTAG_CORE_DATA, ZMLogLevelDebug)) {
        static int32_t counter;
        int32_t const c = OSAtomicIncrement32Barrier(&counter);
        ZMLogDebug(@"Resolving conflicts (%d)", c);
    }
 
    self.objectToValueDictionaryMap = [NSMapTable strongToStrongObjectsMapTable];
    
    [self prepareMergeWithConflicts:list];
    
    [super resolveConflicts:list error:outError];
    
    [self finalizeMerge];
    
    return YES;
}

- (void)prepareMergeWithConflicts:(NSArray *)list
{
    [self prepareMessagesInConversationForMergeWithConflicts:list];
}


- (void)prepareMessagesInConversationForMergeWithConflicts:(NSArray *)list
{
    
    [list enumerateObjectsUsingBlock:^(NSMergeConflict *conflict, NSUInteger idx, BOOL *stop) {
        NOT_USED(stop);
        NOT_USED(idx);

        if (ZMLogLevelIsActive(ZMTAG_CORE_DATA, ZMLogLevelDebug)) {
            ZMLogDebug(@"  context '%@'", conflict.sourceObject.managedObjectContext.userInfo);
            ZMLogDebug(@"  source object %@ (%p): %@", conflict.sourceObject.class, conflict.sourceObject, conflict.sourceObject.objectID.URIRepresentation);
            ZMLogDebug(@"  old version %u -> new version %u", (unsigned) conflict.oldVersionNumber, (unsigned) conflict.newVersionNumber);
            if (conflict.objectSnapshot != nil) {
                ZMLogDebug(@"  objectSnapshot %@", conflict.objectSnapshot);
            }
            if (conflict.cachedSnapshot != nil) {
                ZMLogDebug(@"  cachedSnapshot %@", conflict.cachedSnapshot);
            }
            if (conflict.persistedSnapshot != nil) {
                ZMLogDebug(@"  persistedSnapshot %@", conflict.persistedSnapshot);
            }
        }
        
        ZMConversation *conversation = (id) conflict.sourceObject;
        if (! [conversation isKindOfClass:ZMConversation.class]) {
            return;
        }
        
        NSMutableOrderedSet *addedMessages;
        {
            NSString *key = ZMConversationMessagesKey;
            NSOrderedSet *commitedMessages = [conversation committedValuesForKeys:@[key]][key];
            ZMLogDebug(@"  commited value for 'messages': %@", [[commitedMessages.array valueForKey:MessageKeyForDebugging] componentsJoinedByString:@"; "]);
            
            if (ZMLogLevelIsActive(ZMTAG_CORE_DATA, ZMLogLevelDebug) && ! [conversation hasFaultForRelationshipNamed:key]) {
                NSOrderedSet *messages = [conversation valueForKey:key];
                ZMLogDebug(@"  current value for 'messages': %@", [[messages.array valueForKey:MessageKeyForDebugging] componentsJoinedByString:@"; "]);
            }
            
            NSOrderedSet *changedMessages = [conversation changedValues][key];
            if (changedMessages != nil) {
                ZMLogDebug(@"  changed value for 'messages': %@", [[changedMessages.array valueForKey:MessageKeyForDebugging] componentsJoinedByString:@"; "]);
            }
            addedMessages = [changedMessages mutableCopy];
            [addedMessages minusOrderedSet:commitedMessages];
        }
        
        if (addedMessages.count == 0) {
            ZMLogDebug(@"No added messages. Not merging.");
            return;
        }
        ZMLogDebug(@"%lu added message(s). Merging.", (long unsigned) addedMessages.count);
        
        // Check what the persistent store coordinator is up to:
        NSArray * const sortDescriptors = ZMMessage.defaultSortDescriptors;
        NSArray *messagesFromPSC;
        {
            NSManagedObjectContext *moc = conflict.sourceObject.managedObjectContext;
            NSPersistentStoreCoordinator *psc = moc.persistentStoreCoordinator;
            NSRelationshipDescription *messagesRelationship = conflict.sourceObject.entity.relationshipsByName[@"messages"];
            
            // We'll fetch from the PSC. This will not retain the ordering, but at least show us what's there:
            NSFetchRequest *request = [[NSFetchRequest alloc] init];
            request.entity = messagesRelationship.destinationEntity;
            request.predicate = [NSPredicate predicateWithFormat:@"%K == %@", messagesRelationship.inverseRelationship.name, conflict.sourceObject];
            request.sortDescriptors = sortDescriptors;
            NSError *error;
            messagesFromPSC = [psc executeRequest:request withContext:moc error:&error];
            RequireString(messagesFromPSC != nil, "Failed to execute request to PSC: %lu", (long) error.code);
            ZMLogDebug(@"  (unordered) messages from PSC: %@", [[messagesFromPSC valueForKey:MessageKeyForDebugging] componentsJoinedByString:@"; "]);
        }
        
        NSMutableOrderedSet *mergedMessages = [NSMutableOrderedSet orderedSetWithArray:messagesFromPSC];
        for (ZMMessage *m in addedMessages) {
            [mergedMessages zm_insertObject:m sortedByDescriptors:sortDescriptors];
        }
        
        [self.objectToValueDictionaryMap setObject:@{ZMConversationMessagesKey : mergedMessages} forKey:conversation];
        ZMLogDebug(@"  resolved messages: %@", [[mergedMessages.array valueForKey:MessageKeyForDebugging] componentsJoinedByString:@"; "]);
    }];
}

- (void)finalizeMerge;
{
    for (ZMConversation *conversation in self.objectToValueDictionaryMap.keyEnumerator) {
        NSArray * const trackedKeys = conversation.keysTrackedForLocalModifications;
        NSDictionary *d = [self.objectToValueDictionaryMap objectForKey:conversation];
        [d enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *value, BOOL *stop) {
            NOT_USED(stop);
            [conversation setValue:value forKey:key];
            if ([trackedKeys indexOfObject:key] != NSNotFound) {
                [conversation setLocallyModifiedKeys:[NSSet setWithObject:key]];
            }
            
            if (ZMLogLevelIsActive(ZMTAG_CORE_DATA, ZMLogLevelDebug)) {
                if ([key isEqualToString:ZMConversationMessagesKey]) {
                    ZMLogDebug(@"  final messages: %@", [[conversation.messages.array valueForKey:MessageKeyForDebugging] componentsJoinedByString:@"; "]);
                } else {
                    ZMLogDebug(@"  final value for %@: %@", key, value);
                }
            }

        }];
    }
    self.objectToValueDictionaryMap = nil;
}

@end
