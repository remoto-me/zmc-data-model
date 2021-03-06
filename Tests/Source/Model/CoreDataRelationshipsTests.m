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


#import "ModelObjectsTests.h"

#import "ZMManagedObject+Internal.h"
#import "ZMConversation+Internal.h"
#import "ZMUser+Internal.h"
#import "ZMConnection+Internal.h"
#import "ZMMessage+Internal.h"



@interface CoreDataRelationshipsTests : ModelObjectsTests
@end



@implementation CoreDataRelationshipsTests

- (void)testModelledRelationships;
{
    // Create objects:
    
    ZMConversation *conversation1 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMConversation *conversation2 = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    
    ZMTextMessage *message1 = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMTextMessage *message2 = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMTextMessage *message3 = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    ZMUser *user1 = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMUser *user2 = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMUser *user3 = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    
    ZMConnection *connection1 = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMConnection *connection2 = [ZMConnection insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // Create relationships:
    
    [conversation1.mutableMessages addObjectsFromArray:@[message1, message2]];
    [conversation2.mutableMessages addObject:message3];
    
    connection1.conversation = conversation1;
    conversation2.connection = connection2;
    
    connection1.to = user1;
    user2.connection = connection2;
    
    conversation1.creator = user1;
    conversation2.creator = user2;
    
    [conversation1.mutableOtherActiveParticipants addObject:user1];
    [conversation1.mutableOtherActiveParticipants addObject:user3];
    [conversation1.mutableOtherInactiveParticipants addObject:user2];
    
    [conversation2.mutableOtherActiveParticipants addObject:user2];
    [conversation2.mutableOtherActiveParticipants addObject:user3];
    [conversation2.mutableOtherInactiveParticipants addObject:user1];
    
    // Check that the inverse have been set:
    [self.uiMOC processPendingChanges];
    
    XCTAssertEqual(message1.conversation, conversation1);
    XCTAssertEqual(message2.conversation, conversation1);
    XCTAssertEqual(message3.conversation, conversation2);
    
    XCTAssertEqual(conversation1.connection, connection1);
    XCTAssertEqual(connection2.conversation, conversation2);
    
    XCTAssertEqual(user1.connection, connection1);
    XCTAssertEqual(connection2.to, user2);
    
    XCTAssertTrue([[user1 valueForKey:@"conversationsCreated"] containsObject:conversation1]);
    XCTAssertTrue([[user2 valueForKey:@"conversationsCreated"] containsObject:conversation2]);
    
    id s1 = [NSOrderedSet orderedSetWithArray:@[user1, user3]];
    XCTAssertEqualObjects(conversation1.otherActiveParticipants, s1);
    XCTAssertEqualObjects(conversation1.otherInactiveParticipants, [NSOrderedSet orderedSetWithObject:user2]);
    id s2 = [NSOrderedSet orderedSetWithArray:@[user2, user3]];
    XCTAssertEqualObjects(conversation2.otherActiveParticipants, s2);
    XCTAssertEqualObjects(conversation2.otherInactiveParticipants, [NSOrderedSet orderedSetWithObject:user1]);
    
    XCTAssertEqualObjects([user1 valueForKey:@"activeConversations"], [NSOrderedSet orderedSetWithObject:conversation1]);
    XCTAssertEqualObjects([user1 valueForKey:@"inactiveConversations"], [NSOrderedSet orderedSetWithObject:conversation2]);
    XCTAssertEqualObjects([user2 valueForKey:@"activeConversations"], [NSOrderedSet orderedSetWithObject:conversation2]);
    XCTAssertEqualObjects([user2 valueForKey:@"inactiveConversations"], [NSOrderedSet orderedSetWithObject:conversation1]);
    id ac = [NSOrderedSet orderedSetWithArray:@[conversation1, conversation2]];
    XCTAssertEqualObjects([user3 valueForKey:@"activeConversations"], ac);
    XCTAssertEqualObjects([user3 valueForKey:@"inactiveConversations"], [NSOrderedSet new]);
    
    NSError *error = nil;
    XCTAssertTrue([self.uiMOC save:&error], @"Save failed: %@", error);
    
    // Save and check that relationships can be traversed in the other context:
    
    ZMConversation *c2Conversation1 = (id) [self.syncMOC existingObjectWithID:conversation1.objectID error:&error];
    XCTAssertEqualObjects(c2Conversation1.objectID, conversation1.objectID, @"Failed to read in 2nd context: %@", error);
    
    ZMConversation *c2Conversation2 = (id) [self.syncMOC existingObjectWithID:conversation2.objectID error:&error];
    XCTAssertEqualObjects(c2Conversation2.objectID, conversation2.objectID, @"Failed to read in 2nd context: %@", error);
    
    NSOrderedSet *c2Messages1 = c2Conversation1.messages;
    XCTAssertEqual(c2Messages1.count, (NSUInteger) 2);
    NSOrderedSet *c2Messages2 = c2Conversation2.messages;
    XCTAssertEqual(c2Messages2.count, (NSUInteger) 1);
    ZMTextMessage *c2Message1 = c2Messages1[0];
    ZMTextMessage *c2Message2 = c2Messages1[1];
    ZMTextMessage *c2Message3 = c2Messages2[0];
    XCTAssertEqualObjects(c2Message1.objectID, message1.objectID);
    XCTAssertEqualObjects(c2Message2.objectID, message2.objectID);
    XCTAssertEqualObjects(c2Message3.objectID, message3.objectID);
    
    XCTAssertEqual(c2Message1.conversation, c2Conversation1);
    XCTAssertEqual(c2Message2.conversation, c2Conversation1);
    XCTAssertEqual(c2Message3.conversation, c2Conversation2);
    
    ZMUser *c2User1 = c2Conversation1.creator;
    XCTAssertEqualObjects(c2User1.objectID, user1.objectID);
    ZMUser *c2User2 = c2Conversation2.creator;
    XCTAssertEqualObjects(c2User2.objectID, user2.objectID);
}

@end
