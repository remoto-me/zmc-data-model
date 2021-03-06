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


#import "ZMBaseManagedObjectTest.h"
#import "ZMConversationList+Internal.h"
#import "ZMConversationListDirectory.h"
#import "ZMConversation+Internal.h"
#import "NSManagedObjectContext+zmessaging.h"
#import "ZMConnection+Internal.h"
#import "ZMUser+Internal.h"
#import "ZMNotifications+Internal.h"
#import "ZMVoiceChannel+Testing.h"
#import "ZMMessage+Internal.h"
#import "NotificationObservers.h"

@interface ZMConversationListTests : ZMBaseManagedObjectTest
@end



@implementation ZMConversationListTests

- (void)setUp {
    [super setUp];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ZMApplicationDidEnterEventProcessingStateNotification" object:nil];
    WaitForAllGroupsToBeEmpty(0.5);

}

- (void)tearDown {
    [super tearDown];
}
- (void)testThatItDoesNotReturnTheSelfConversation;
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeSelf;
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeGroup;
    
    // then
    NSArray *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqual(list.count, 2u);
    NSArray *expected = @[c2, c3];
    AssertArraysContainsSameObjects(list, expected);
}

- (void)testThatItReturnsAllConversations
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeGroup;
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeGroup;
    
    // then
    NSArray *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqual(list.count, 3u);
    NSArray *expected = @[c1, c2, c3];
    AssertArraysContainsSameObjects(list, expected);
}

- (void)testThatItReturnsAllArchivedConversations
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeGroup;
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeGroup;
    c3.isArchived = YES;
    
    // then
    NSArray *list = [ZMConversation archivedConversationsInContext:self.uiMOC];
    XCTAssertEqual(list.count, 1u);
    NSArray *expected = @[c3];
    AssertArraysContainsSameObjects(list, expected);
}

- (void)testThatItDoesNotReturnIgnoredConnections
{
    // given
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeConnection;
    ZMConnection *connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    connection.conversation = c2;
    connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    connection.status = ZMConnectionStatusIgnored;
    
    // then
    NSArray *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqual(list.count, 0u);
}

- (void)testThatItReturnsAllUnarchivedConversations
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeGroup;
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeGroup;
    c3.isArchived = YES;
    ZMConversation *c4 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c4.conversationType = ZMConversationTypeOneOnOne;
    c4.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    c4.connection.status = ZMConnectionStatusBlocked;
    
    // then
    NSArray *list = [ZMConversation conversationsExcludingArchivedAndCallingInContext:self.uiMOC];
    XCTAssertEqual(list.count, 2u);
    NSArray *expected = @[c1, c2];
    AssertArraysContainsSameObjects(list, expected);
}

- (void)testThatItReturnsConversationsSorted
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeGroup;
    c1.lastModifiedDate = [NSDate dateWithTimeIntervalSinceReferenceDate:417000000];
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    c2.lastModifiedDate = [c1.lastModifiedDate dateByAddingTimeInterval:10];
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeGroup;
    c3.lastModifiedDate = [c1.lastModifiedDate dateByAddingTimeInterval:-10];
    
    // then
    NSArray *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqual(list.count, 3u);
    NSArray *expected = @[c2, c1, c3];
    XCTAssertEqualObjects(list, expected);
}

- (void)testThatItUpdatesWhenNewConversationsAreInserted
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeGroup;
    c1.userDefinedName = @"c1";
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    c2.userDefinedName = @"c2";
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeGroup;
    c3.userDefinedName = @"c3";
    XCTAssert([self.uiMOC saveOrRollback]);

    // then
    ZMConversationList *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqual(list.count, 3u);
    NSArray *expected = @[c1, c2, c3];
    AssertArraysContainsSameObjects(list, expected);
    
    // when
    ConversationListChangeObserver *observer = [[ConversationListChangeObserver alloc] initWithConversationList:list];
    
    ZMConversation *c4 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c4.conversationType = ZMConversationTypeGroup;
    XCTAssert([self.uiMOC saveOrRollback]);

    // then
    XCTAssertEqual(list.count, 4u);
    expected = @[c1, c2, c3, c4];
    AssertArraysContainsSameObjects(list, expected);
    [observer tearDown];
}

- (void)testThatItUpdatesWhenNewConversationLastModifiedChangesThroughTheNotificationDispatcher
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeGroup;
    c1.lastModifiedDate = [NSDate dateWithTimeIntervalSinceReferenceDate:417000000];
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    c2.lastModifiedDate = [c1.lastModifiedDate dateByAddingTimeInterval:10];
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeGroup;
    c3.lastModifiedDate = [c1.lastModifiedDate dateByAddingTimeInterval:-10];
    
    // then
    ZMConversationList *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqual(list.count, 3u);
    NSArray *expected = @[c2, c1, c3];
    XCTAssertEqualObjects(list, expected);
   
    ConversationListChangeObserver *observer = [[ConversationListChangeObserver alloc] initWithConversationList:list];
    
    // when
    XCTAssert([self.uiMOC saveOrRollback]);
    
    c3.lastModifiedDate = [c1.lastModifiedDate dateByAddingTimeInterval:20];
    [self.uiMOC processPendingChanges];
    
    // then
    XCTAssertEqual(list.count, 3u);
    expected = @[c3, c2, c1];
    XCTAssertEqualObjects(list, expected);
    [observer tearDown];
}

- (void)testThatItUpdatesWhenNewConnectionIsIgnored;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.conversationType = ZMConversationTypeConnection;
    conversation.lastModifiedDate = [NSDate date];
    conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.connection.status = ZMConnectionStatusPending;
    conversation.connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    XCTAssert([self.uiMOC saveOrRollback]);

    // then
    ZMConversationList *list = [ZMConversation pendingConversationsInContext:self.uiMOC];
    XCTAssertEqual(list.count, 1u);
    NSArray *expected = @[conversation];
    XCTAssertEqualObjects(list, expected);
    
    ConversationListChangeObserver *observer = [[ConversationListChangeObserver alloc] initWithConversationList:list];

    // when
    XCTAssert([self.uiMOC saveOrRollback]);
    
    conversation.connection.status = ZMConnectionStatusIgnored;
    XCTAssert([self.uiMOC saveOrRollback]);
    
    // then
    XCTAssertEqual(list.count, 0u);
    XCTAssertEqualObjects(list, @[]);
    [observer tearDown];
}

- (void)testThatItUpdatesWhenNewConnectionIsCancelled;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.conversationType = ZMConversationTypeConnection;
    conversation.lastModifiedDate = [NSDate date];
    conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.connection.status = ZMConnectionStatusSent;
    conversation.connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    ZMConversationList *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqual(list.count, 1u);
    NSArray *expected = @[conversation];
    XCTAssertEqualObjects(list, expected);
    
    ConversationListChangeObserver *observer = [[ConversationListChangeObserver alloc] initWithConversationList:list];
    
    // when
    XCTAssert([self.uiMOC saveOrRollback]);
    
    conversation.connection.status = ZMConnectionStatusIgnored;
    XCTAssert([self.uiMOC saveOrRollback]);
    
    // then
    XCTAssertEqual(list.count, 0u);
    XCTAssertEqualObjects(list, @[]);
    [observer tearDown];
}

- (void)testThatItUpdatesWhenNewConnectionIsAccepted;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.conversationType = ZMConversationTypeConnection;
    conversation.lastModifiedDate = [NSDate date];
    conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.connection.status = ZMConnectionStatusPending;
    conversation.connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    ZMConversationList *normalList = [ZMConversation conversationsExcludingArchivedAndCallingInContext:self.uiMOC];
    ZMConversationList *pendingList = [ZMConversation pendingConversationsInContext:self.uiMOC];
    XCTAssertEqual(normalList.count, 0u);
    XCTAssertEqualObjects(normalList, @[]);
    XCTAssertEqual(pendingList.count, 1u);
    XCTAssertEqualObjects(pendingList, @[conversation]);
    
    ConversationListChangeObserver *normalObserver = [[ConversationListChangeObserver alloc] initWithConversationList:normalList];
    ConversationListChangeObserver *pendingObserver =[[ConversationListChangeObserver alloc] initWithConversationList:pendingList];

    // when
    XCTAssert([self.uiMOC saveOrRollback]);
    
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.connection.status = ZMConnectionStatusAccepted;
    XCTAssert([self.uiMOC saveOrRollback]);
    
    // then
    XCTAssertEqual(normalList.count, 1u);
    XCTAssertEqualObjects(normalList, @[conversation]);
    XCTAssertEqual(pendingList.count, 0u);
    XCTAssertEqualObjects(pendingList, @[]);
    [normalObserver tearDown];
    [pendingObserver tearDown];
}

- (void)testThatItUpdatesWhenNewAUserIsUnblocked;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.lastModifiedDate = [NSDate date];
    conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.connection.status = ZMConnectionStatusBlocked;
    conversation.connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    XCTAssert([self.uiMOC saveOrRollback]);

    // then
    ZMConversationList *normalList = [ZMConversation conversationsExcludingArchivedAndCallingInContext:self.uiMOC];
    XCTAssertEqual(normalList.count, 0u);
    XCTAssertEqualObjects(normalList, @[]);

    ConversationListChangeObserver *observer = [[ConversationListChangeObserver alloc] initWithConversationList:normalList];
    
    // when
    [conversation.connection.to accept];
    XCTAssert([self.uiMOC saveOrRollback]);
    
    // then
    XCTAssertEqual(normalList.count, 1u);
    XCTAssertEqualObjects(normalList, @[conversation]);
    [observer tearDown];
}

- (void)testThatItUpdatesWhenTwoNewConnectionsAreAccepted;
{
    // given
    ZMConversation *conversation1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation1.conversationType = ZMConversationTypeConnection;
    conversation1.lastModifiedDate = [NSDate date];
    conversation1.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation1.connection.status = ZMConnectionStatusPending;
    conversation1.connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    
    ZMConversation *conversation2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation2.conversationType = ZMConversationTypeConnection;
    conversation2.lastModifiedDate = [NSDate date];
    conversation2.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation2.connection.status = ZMConnectionStatusPending;
    conversation2.connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    ZMConversationList *normalList = [ZMConversation conversationsExcludingArchivedAndCallingInContext:self.uiMOC];
    ZMConversationList *pendingList = [ZMConversation pendingConversationsInContext:self.uiMOC];
    NSArray *conversations = @[conversation2, conversation1];
    XCTAssertEqual(normalList.count, 0u);
    XCTAssertEqualObjects(normalList, @[]);
    XCTAssertEqual(pendingList.count, 2u);
    XCTAssertEqualObjects(pendingList, conversations);
    
    ConversationListChangeObserver *normalObserver = [[ConversationListChangeObserver alloc] initWithConversationList:normalList];
    ConversationListChangeObserver *pendingObserver =[[ConversationListChangeObserver alloc] initWithConversationList:pendingList];

    // when
    XCTAssert([self.uiMOC saveOrRollback]);
    
    conversation1.conversationType = ZMConversationTypeOneOnOne;
    conversation1.connection.status = ZMConnectionStatusAccepted;
    conversation2.conversationType = ZMConversationTypeOneOnOne;
    conversation2.connection.status = ZMConnectionStatusAccepted;
    XCTAssert([self.uiMOC saveOrRollback]);
    
    // then
    XCTAssertEqual(normalList.count, 2u);
    XCTAssertEqualObjects(normalList, conversations);
    XCTAssertEqual(pendingList.count, 0u);
    XCTAssertEqualObjects(pendingList, @[]);
    [normalObserver tearDown];
    [pendingObserver tearDown];
}


- (void)testThatItUpdatesWhenNewAConversationIsArchived;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.conversationType = ZMConversationTypeConnection;
    conversation.lastModifiedDate = [NSDate date];
    conversation.connection = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.connection.status = ZMConnectionStatusAccepted;
    conversation.connection.to = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    ZMConversationList *normalList = [ZMConversation conversationsExcludingArchivedAndCallingInContext:self.uiMOC];
    ZMConversationList *archivedList = [ZMConversation archivedConversationsInContext:self.uiMOC];
    XCTAssertEqual(normalList.count, 1u);
    XCTAssertEqualObjects(normalList, @[conversation]);
    XCTAssertEqual(archivedList.count, 0u);
    XCTAssertEqualObjects(archivedList, @[]);
    
    ConversationListChangeObserver *normalObserver = [[ConversationListChangeObserver alloc] initWithConversationList:normalList];
    ConversationListChangeObserver *archivedObserver =[[ConversationListChangeObserver alloc] initWithConversationList:archivedList];

    // when
    XCTAssert([self.uiMOC saveOrRollback]);
    conversation.isArchived = YES;
    XCTAssert([self.uiMOC saveOrRollback]);
    
    // then
    XCTAssertTrue(conversation.isArchived);
    XCTAssertEqual(normalList.count, 0u);
    XCTAssertEqualObjects(normalList, @[]);
    XCTAssertEqual(archivedList.count, 1u);
    XCTAssertEqualObjects(archivedList, @[conversation]);
    [normalObserver tearDown];
    [archivedObserver tearDown];
}


- (void)testThatAConversationWithActiveVoicecallisAlwaysOnTop
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeOneOnOne;
    c1.lastModifiedDate = [NSDate date];
    XCTAssertFalse(c1.callDeviceIsActive);
    
    ZMConversation *c2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c2.conversationType = ZMConversationTypeOneOnOne;
    c2.lastModifiedDate = [NSDate date];
    
    ZMConversation *c3 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c3.conversationType = ZMConversationTypeOneOnOne;
    c3.lastModifiedDate = [NSDate date];
    
    XCTAssert([self.uiMOC saveOrRollback]);

    
    NSArray *expectedList1 = @[c3, c2, c1];
    ZMConversationList *list = [ZMConversation conversationsIncludingArchivedInContext:self.uiMOC];
    XCTAssertEqualObjects(list, expectedList1);
    
    ConversationListChangeObserver *observer = [[ConversationListChangeObserver alloc] initWithConversationList:list];

    // when
    c1.callDeviceIsActive = YES;
    
    // then the active call moves to top
    XCTAssertTrue(c1.callDeviceIsActive);
    XCTAssert([self.uiMOC saveOrRollback]);
    [self.uiMOC.globalManagedObjectContextObserver notifyUpdatedCallState:[NSSet setWithObject:c1] notifyDirectly:YES];
    
    NSArray *expectedList2 = @[c1, c3, c2];
    XCTAssertEqualObjects(list, expectedList2);
    
    // when we insert a message into one of the other conversations
    [c2 appendMessageWithText:@"hello"];
    XCTAssert([self.uiMOC saveOrRollback]);
    
    // then the active call stays on top
    NSArray *expectedList3 = @[c1, c2, c3];
    XCTAssertEqualObjects(list, expectedList3);
    
    WaitForAllGroupsToBeEmpty(0.5);
    [observer tearDown];
}

- (void)testThatClearingConversationMovesItToClearedList
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeOneOnOne;
    c1.lastModifiedDate = [NSDate date];
    ZMMessage *message = [c1 appendMessageWithText:@"message"];
    message.eventID = self.createEventID;
    message.serverTimestamp = [NSDate date];
    
    c1.lastEventID = message.eventID;
    c1.lastServerTimeStamp = message.serverTimestamp;
    
    ZMConversationList *activeList = [ZMConversation conversationsExcludingArchivedAndCallingInContext:self.uiMOC];
    ZMConversationList *archivedList = [ZMConversation archivedConversationsInContext:self.uiMOC];
    ZMConversationList *clearedList = [ZMConversation clearedConversationsInContext:self.uiMOC];
    
    XCTAssertEqual(activeList.count, 1u);
    XCTAssertEqualObjects(activeList.firstObject, c1);
    XCTAssertEqual(archivedList.count, 0u);
    XCTAssertEqual(clearedList.count, 0u);

    XCTAssertTrue([self.uiMOC saveOrRollback]);

    // when
    [c1 clearMessageHistory];

    XCTAssertTrue([self.uiMOC saveOrRollback]);
    
    
    // then
    XCTAssertEqual(activeList.count, 0u);
    XCTAssertEqual(archivedList.count, 0u);
    XCTAssertEqual(clearedList.count, 1u);
    XCTAssertEqualObjects(clearedList.firstObject, c1);
}

- (void)testThatAddingMessageToClearedConversationMovesItToActiveConversationsList
{
    // given
    ZMConversation *c1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    c1.conversationType = ZMConversationTypeOneOnOne;
    c1.lastModifiedDate = [NSDate date];
    ZMMessage *message = [c1 appendMessageWithText:@"message"];
    message.eventID = self.createEventID;
    message.serverTimestamp = [NSDate date];
    
    c1.lastEventID = message.eventID;
    c1.lastServerTimeStamp = message.serverTimestamp;
    
    [c1 clearMessageHistory];

    ZMConversationList *activeList = [ZMConversation conversationsExcludingArchivedAndCallingInContext:self.uiMOC];
    ZMConversationList *archivedList = [ZMConversation archivedConversationsInContext:self.uiMOC];
    ZMConversationList *clearedList = [ZMConversation clearedConversationsInContext:self.uiMOC];
    
    XCTAssertEqual(activeList.count, 0u);
    XCTAssertEqual(archivedList.count, 0u);
    XCTAssertEqual(clearedList.count, 1u);
    XCTAssertEqualObjects(clearedList.firstObject, c1);

    XCTAssertTrue([self.uiMOC saveOrRollback]);

    // when
    //UI should call this when opening cleared conversation first time
    [c1 revealClearedConversation];

    // then
    XCTAssertTrue([self.uiMOC saveOrRollback]);

    XCTAssertEqual(activeList.count, 1u);
    XCTAssertEqualObjects(activeList.firstObject, c1);
    XCTAssertEqual(archivedList.count, 0u);
    XCTAssertEqual(clearedList.count, 0u);
}

@end



@implementation ZMConversationListTests (ZMChanges)

- (void)testThatTheSortedIsAffected;
{
    // given
    ZMConversationList *list = [self.uiMOC.conversationListDirectory conversationsIncludingArchived];
    
    // then
    XCTAssertTrue([list sortingIsAffectedByConversationKeys:[NSSet setWithObject:ZMConversationListIndicatorKey]]);
    XCTAssertTrue([list sortingIsAffectedByConversationKeys:[NSSet setWithObject:ZMConversationIsArchivedKey]]);
    XCTAssertTrue([list sortingIsAffectedByConversationKeys:[NSSet setWithObject:@"lastModifiedDate"]]);
    XCTAssertTrue([list sortingIsAffectedByConversationKeys:[NSSet setWithObject:@"remoteIdentifier_data"]]);
}

- (void)testThatTheSortedIsNotAffected;
{
    // given
    ZMConversationList *list = [self.uiMOC.conversationListDirectory conversationsIncludingArchived];
    
    NSEntityDescription *conversationEntity = self.uiMOC.persistentStoreCoordinator.managedObjectModel.entitiesByName[ZMConversation.entityName];
    
    NSMutableSet *conversationKeys = [NSMutableSet setWithArray:conversationEntity.propertiesByName.allKeys];

    [conversationKeys removeObject:ZMConversationIsArchivedKey];
    [conversationKeys removeObject:@"lastModifiedDate"];
    [conversationKeys removeObject:@"remoteIdentifier_data"];
    
    // then
    XCTAssertFalse([list sortingIsAffectedByConversationKeys:conversationKeys]);
}

@end
