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


#import "ZMConversationListDirectory.h"
#import "ZMConversation+Internal.h"
#import "ZMConversationList+Internal.h"

static NSString * const ConversationListDirectoryKey = @"ZMConversationListDirectory";

static NSString * const AllKey = @"All";
static NSString * const UnarchivedKey = @"Unarchived";
static NSString * const ArchivedKey = @"Archived";
static NSString * const PendingKey = @"Pending";



@interface ZMConversationListDirectory ()

@property (nonatomic) ZMConversationList* unarchivedAndNotCallingConversations;
@property (nonatomic) ZMConversationList* conversationsIncludingArchived;
@property (nonatomic) ZMConversationList* archivedConversations;
@property (nonatomic) ZMConversationList* pendingConnectionConversations;
@property (nonatomic) ZMConversationList* nonIdleVoiceChannelConversations;
@property (nonatomic) ZMConversationList* activeCallConversations;
@property (nonatomic) ZMConversationList* clearedConversations;

@end



@implementation ZMConversationListDirectory

- (instancetype)initWithManagedObjectContext:(NSManagedObjectContext *)moc
{
    self = [super init];
    if (self) {
        NSArray *allConversations = [self fetchAllConversations:moc];
        
        self.unarchivedAndNotCallingConversations = [[ZMConversationList alloc] initWithAllConversations:allConversations filteringPredicate:[ZMConversation predicateForConversationsExcludingArchivedAndInCall] moc:moc debugDescription:@"unarchivedAndNotCallingConversations"];
        self.archivedConversations = [[ZMConversationList alloc] initWithAllConversations:allConversations filteringPredicate:[ZMConversation predicateForArchivedConversations] moc:moc debugDescription:@"archivedConversations"];
        self.conversationsIncludingArchived = [[ZMConversationList alloc] initWithAllConversations:allConversations filteringPredicate:[ZMConversation predicateForConversationsIncludingArchived] moc:moc debugDescription:@"conversationsIncludingArchived"];
        self.pendingConnectionConversations = [[ZMConversationList alloc] initWithAllConversations:allConversations filteringPredicate:[ZMConversation predicateForPendingConversations] moc:moc debugDescription:@"pendingConnectionConversations"];
        self.nonIdleVoiceChannelConversations = [[ZMConversationList alloc] initWithAllConversations:allConversations filteringPredicate:[ZMConversation predicateForConversationsWithNonIdleVoiceChannel] moc:moc debugDescription:@"nonIdleVoiceChannelConversations"];
        self.activeCallConversations = [[ZMConversationList alloc] initWithAllConversations:allConversations filteringPredicate:[ZMConversation predicateForConversationWithActiveCalls] moc:moc debugDescription:@"activeCallConversations"];
        self.clearedConversations = [[ZMConversationList alloc] initWithAllConversations:allConversations filteringPredicate:[ZMConversation predicateForClearedConversations] moc:moc debugDescription:@"clearedConversations"];
        
    }
    return self;
}


- (NSArray *)fetchAllConversations:(NSManagedObjectContext *)context {
    NSFetchRequest *allConversationsRequest = [ZMConversation sortedFetchRequest];
    // Since this is extremely likely to trigger the "otherActiveParticipants" and "connection" relationships, we make sure these gets prefetched:
    NSMutableArray *keyPaths = [NSMutableArray arrayWithArray:allConversationsRequest.relationshipKeyPathsForPrefetching];
    [keyPaths addObject:ZMConversationOtherActiveParticipantsKey];
    [keyPaths addObject:ZMConversationConnectionKey];
    allConversationsRequest.relationshipKeyPathsForPrefetching = keyPaths;
    
    NSError *error;
    return [context executeFetchRequest:allConversationsRequest error:&error];
    NSAssert(error != nil, @"Failed to fetch");
}

- (NSArray *)allConversationLists;
{
    return @[
             self.pendingConnectionConversations,
             self.archivedConversations,
             self.conversationsIncludingArchived,
             self.unarchivedAndNotCallingConversations,
             self.nonIdleVoiceChannelConversations,
             self.activeCallConversations
             ];
}

@end



@implementation NSManagedObjectContext (ZMConversationListDirectory)

- (ZMConversationListDirectory *)conversationListDirectory;
{
    ZMConversationListDirectory *directory = self.userInfo[ConversationListDirectoryKey];
    if (directory == nil) {
        directory = [[ZMConversationListDirectory alloc] initWithManagedObjectContext:self];
        self.userInfo[ConversationListDirectoryKey] = directory;
    }
    return directory;
}

@end


