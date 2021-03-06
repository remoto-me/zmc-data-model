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


@import Foundation;
@import CoreData;
@class ZMConversationList;
@class ZMSharableConversations;


@interface ZMConversationListDirectory : NSObject

@property (nonatomic, readonly) ZMConversationList* unarchivedAndNotCallingConversations; ///< archived and unarchived, not pending, any call state
@property (nonatomic, readonly) ZMConversationList* conversationsIncludingArchived; ///< unarchived, not pending,
@property (nonatomic, readonly) ZMConversationList* archivedConversations; ///< archived, not pending, not calling
@property (nonatomic, readonly) ZMConversationList* pendingConnectionConversations; ///< pending
@property (nonatomic, readonly) ZMConversationList* nonIdleVoiceChannelConversations; ///< calling, ringing, someone else in call for group conversations, actively talking
@property (nonatomic, readonly) ZMConversationList* activeCallConversations; ///< actively taking. barring bugs, this will have at most one conversation.
@property (nonatomic, readonly) ZMConversationList *clearedConversations; /// conversations with deleted messages (clearedEventId is set)

- (NSArray *)allConversationLists;

@end



@interface NSManagedObjectContext (ZMConversationListDirectory)

- (ZMConversationListDirectory *)conversationListDirectory;

@end
