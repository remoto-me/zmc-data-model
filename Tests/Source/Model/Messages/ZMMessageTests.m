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


@import ZMCDataModel;
@import CoreGraphics;
@import Foundation;
@import MobileCoreServices;
@import zimages;

#import "ModelObjectsTests.h"
#import "ZMClientMessage.h"
#import "ZMMessage+Internal.h"
#import "ZMUser+Internal.h"
#import "NSManagedObjectContext+zmessaging.h"
#import "ZMAssetClientMessage.h"
#import "ZMMessageTests.h"
#import "MessagingTest+EventFactory.h"
#import <OCMock/OCMock.h>
#import "ZMConversation+Transport.h"
#import "ZMUpdateEvent+ZMCDataModel.h"
#import "NSString+RandomString.h"

NSString * const IsExpiredKey = @"isExpired";

@implementation BaseZMMessageTests : ModelObjectsTests
@end

@interface ZMMessageTests : BaseZMMessageTests
@end

@implementation ZMMessageTests

- (void)setUp
{
    [super setUp];
    [self setUpCaches];
}

- (void)testThatItIgnoresNanosecondSettingServerTimestampOnInsert
{
    // given
    ZMMessage *message = [ZMMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    double millisecondsSince1970 = [message.serverTimestamp timeIntervalSince1970]*1000;
    
    // then
    XCTAssertEqual(millisecondsSince1970, floor(millisecondsSince1970));
}

- (void)testThatItHasLocallyModifiedDataFields
{
    XCTAssertTrue([ZMImageMessage hasLocallyModifiedDataFields]);
    NSEntityDescription *entity = self.uiMOC.persistentStoreCoordinator.managedObjectModel.entitiesByName[ZMImageMessage.entityName];
    XCTAssertNotNil(entity.attributesByName[@"modifiedDataFields"]);
}

- (void)testThatWeCanSetAttributesOnTextMessage
{
    Class aClass = [ZMTextMessage class];
    [self checkBaseMessageAttributeForClass:aClass];
    [self checkAttributeForClass:aClass key:@"text" value:@"Foo Bar"];
}

- (void)testThatWeCanSetAttributesOnKnockMessage
{
    Class aClass = [ZMKnockMessage class];
    [self checkBaseMessageAttributeForClass:aClass];
}

- (void)testThatWeCanSetAttributesOnImageMessage
{
    Class aClass = [ZMImageMessage class];
    [self checkBaseMessageAttributeForClass:aClass];
    [self checkAttributeForClass:aClass key:@"mediumRemoteIdentifier" value:[NSUUID createUUID] ];
    
    NSData *imageData = [self dataForResource:@"tiny" extension:@"jpg"];
    XCTAssertNotNil(imageData);
    [self checkAttributeForClass:aClass key:@"mediumData" value:imageData];
    
    imageData = [self dataForResource:@"medium" extension:@"jpg"];
    XCTAssertNotNil(imageData);
    [self checkAttributeForClass:aClass key:@"previewData" value:imageData];
    
    CGSize size = {12, 34};
    NSValue *sizeValue = [NSValue valueWithBytes:&size objCType:@encode(CGSize)];
    [self checkAttributeForClass:aClass key:@"originalSize" value:sizeValue];
}

- (void)testThatItCanSetData;
{
    // given
    ZMImageMessage *sut = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    sut.originalSize = CGSizeMake(123.45f,125);
    
    // then
    XCTAssertEqualWithAccuracy(sut.originalSize.width, 123.45, 0.001);
    XCTAssertEqualWithAccuracy(sut.originalSize.height, 125, 0.001);
}

- (void)testThatWeCanSetAttributesOnSystemMessage
{
    Class aClass = [ZMSystemMessage class];
    [self checkBaseMessageAttributeForClass:aClass];
    [self checkAttributeForClass:aClass key:@"systemMessageType" value:@(ZMSystemMessageTypeConversationNameChanged)];
    
    // generate a few users and save their objectIDs for later comparison
    NSMutableSet * userObjectIDs = [NSMutableSet set];
    NSMutableSet * users = [NSMutableSet set];
    
    for(int i = 0; i < 4; ++i)
    {
        ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
        NSError *error;
        XCTAssertTrue([self.uiMOC save:&error], @"Save failed: %@", error);
        XCTAssertNotNil(user.objectID);
        XCTAssertFalse(user.objectID.isTemporaryID);
        
        [users addObject:user];
        [userObjectIDs addObject:user.objectID];
        
        
    }
    
    // load a message from the second context and check that the objectIDs for users are as expected
    ZMSystemMessage *message = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    XCTAssertNotNil(message);
    message.users = users;
    XCTAssertEqualObjects([message users], users);

    
    NSError *error;
    XCTAssertTrue([self.uiMOC save:&error], @"Save failed: %@", error);
    
    ZMSystemMessage *message2 = (id) [self.syncMOC existingObjectWithID:message.objectID error:&error];
    XCTAssertNotNil(message2, @"Failed to load into other context: %@", error);
    NSSet *loadedUsers = message2.users;
    XCTAssertNotNil(loadedUsers);
    
    NSMutableSet *loadedUserIDs = [NSMutableSet set];
    for(ZMUser * u in loadedUsers) {
        [loadedUserIDs addObject:u.objectID];
    }
    
    XCTAssertEqualObjects(userObjectIDs, loadedUserIDs);
}


- (void)testThatTheServerTimeStampIsNilWhenTheServerTimestampIsNil;
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    message.serverTimestamp = nil;
    
    // then
    XCTAssertNil(message.serverTimestamp);
}

- (void)testThatTheServerTimeStampIsUpdatedWhenTheServerTimestampIsUpdated;
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    message.serverTimestamp = [NSDate dateWithTimeIntervalSince1970:12346789];
    NSDate *timestamp1 = message.serverTimestamp;
    message.serverTimestamp = [message.serverTimestamp dateByAddingTimeInterval:3000];
    NSDate *timestamp2 = message.serverTimestamp;
    
    // then
    XCTAssertEqualWithAccuracy([timestamp2 timeIntervalSinceDate:timestamp1], 3000, 0.01);
}

- (void)testThatTheServerTimeStampIsOffsetFromServerTimestampByTheLocalTimeZone
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    NSDate *gmtTimestamp = [NSDate date];
    message.serverTimestamp = gmtTimestamp;
    
    // then
    XCTAssertEqualWithAccuracy([message.serverTimestamp timeIntervalSinceDate:message.serverTimestamp],
                               0,
                               0.01);
}

- (void)testThatItSetsTheServerTimestampToTheLatestOfTheTwoWhenUpdatingAMessageWithLaterTimestamp;
{
    // This is not true for image messages, see -testThatImageMessageIsUpdatedCorrectlyWhenItGetsPreviewBeforeMedium

    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        NSDate *oldTimeStamp = [NSDate dateWithTimeIntervalSinceReferenceDate:400000000];
        NSDate *newTimeStamp = [NSDate dateWithTimeIntervalSinceReferenceDate:450000000];


        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.remoteIdentifier = [NSUUID createUUID];
        ZMTextMessage *msg = [ZMTextMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        msg.visibleInConversation = conversation;
        msg.eventID = self.createEventID;
        msg.nonce = NSUUID.createUUID;
        msg.serverTimestamp = oldTimeStamp;
        
        NSDictionary *data = @{@"content" : self.name,
                               @"nonce" : msg.nonce.transportString};
        NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data time:newTimeStamp];
        ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
        XCTAssertNotNil(event);
        
        // when
        id msg2 = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.syncMOC prefetchResult:nil];
        XCTAssertEqual(msg2, msg);
        
        // then
        XCTAssertEqualWithAccuracy(msg.serverTimestamp.timeIntervalSinceReferenceDate, newTimeStamp.timeIntervalSinceReferenceDate, 0.1);
    }];
}

- (void)testThatItSetsTheServerTimestampToTheLatestOfTheTwoWhenUpdatingAMessageEarlierTimestamp;
{
    // This is not true for image messages, see -testThatImageMessageIsUpdatedCorrectlyWhenItGetsPreviewBeforeMedium
    
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        NSDate *oldTimeStamp = [NSDate dateWithTimeIntervalSinceReferenceDate:450000000];
        NSDate *newTimeStamp = [NSDate dateWithTimeIntervalSinceReferenceDate:400000000];

        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.remoteIdentifier = [NSUUID createUUID];
        ZMTextMessage *msg = [ZMTextMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        msg.visibleInConversation = conversation;
        msg.eventID = self.createEventID;
        msg.nonce = NSUUID.createUUID;
        msg.serverTimestamp = oldTimeStamp;
        
        NSDictionary *data = @{@"content" : self.name,
                               @"nonce" : msg.nonce.transportString};
        NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data time:newTimeStamp];
        ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
        XCTAssertNotNil(event);
        
        // when
        id msg2 = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.syncMOC prefetchResult:nil];
        XCTAssertEqual(msg2, msg);
        
        // then
        XCTAssertEqualWithAccuracy(msg.serverTimestamp.timeIntervalSinceReferenceDate, oldTimeStamp.timeIntervalSinceReferenceDate, 1);
    }];
}

- (void)testThatItSetsTheServerTimestampFromEventDataWhenItHasNoEventIDEvenIfItAlreadyHasADate;
{
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.remoteIdentifier = [NSUUID createUUID];
        ZMTextMessage *msg = [ZMTextMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        msg.visibleInConversation = conversation;
        msg.nonce = NSUUID.createUUID;
        msg.serverTimestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:400000000];
        NSDictionary *data = @{@"content" : self.name,
                               @"nonce" : msg.nonce.transportString};
        NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data time:[NSDate dateWithTimeIntervalSinceReferenceDate:450000000]];
        ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
        XCTAssertNotNil(event);
        
        // when
        id msg2 = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.syncMOC prefetchResult:nil];
        XCTAssertEqual(msg2, msg);
        
        // then
        XCTAssertEqualWithAccuracy(msg.serverTimestamp.timeIntervalSinceReferenceDate, 450000000, 1);
    }];
}

- (void)testThatItReturnsZMDeliveryStateDeliveredWhenItHasAnEventID
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    message.eventID = [ZMEventID eventIDWithMajor:10 minor:10];
    
    // then
    XCTAssertEqual(message.deliveryState, ZMDeliveryStateDelivered);
}

- (void)testThatItReturnsZMDeliveryStateDeliveredWhenItHasAnEventIDAndTheExpiredFlagIsSet
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    message.eventID = [ZMEventID eventIDWithMajor:10 minor:10];
    [message expire];
    
    // then
    XCTAssertEqual(message.deliveryState, ZMDeliveryStateDelivered);
}


- (void)testThatDeliveryStateIsCouldNotSendIfTheExpiredFlagIsSet
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    [message expire];
    
    // then
    XCTAssertEqual(message.deliveryState, ZMDeliveryStateFailedToSend);
}

- (void)testThatItResetsTheExpirationDateWhenResending
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    [message expire];
    
    NSDate *expectedDate = [NSDate dateWithTimeIntervalSinceNow:ZMTransportRequestDefaultExpirationInterval];
    
    // when
    [message resend];
    
    // then
    XCTAssertNotNil(message.expirationDate);
    XCTAssertEqualWithAccuracy([message.expirationDate timeIntervalSinceNow], [expectedDate timeIntervalSinceNow], 0.001);
}


- (void)testThatItResetsTheExpiredStateWhenResending
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    [message expire];
    
    // when
    [message resend];
    
    // then
    XCTAssertFalse(message.isExpired);
}


- (void)testThatItReturnsZMDeliveryStatePendingWhenItDoesNotHaveAnEventID
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    message.eventID = nil;
    
    // then
    XCTAssertEqual(message.deliveryState, ZMDeliveryStatePending);
}

- (void)checkBaseMessageAttributeForClass:(Class)aClass;
{
    [self checkAttributeForClass:aClass key:@"eventID" value:[self createEventID]];
    [self checkAttributeForClass:aClass key:@"nonce" value:[NSUUID createUUID]];
    [self checkAttributeForClass:aClass key:@"serverTimestamp" value:[NSDate dateWithTimeIntervalSince1970:1234567] ];
    [self checkSenderForClass:aClass];
}

- (void)checkSenderForClass:(Class)aClass;
{
    ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    NSError *error;
    XCTAssertTrue([self.uiMOC save:&error], @"Save failed: %@", error);
    XCTAssertNotNil(user.objectID);
    XCTAssertFalse(user.objectID.isTemporaryID);
    
    ZMMessage *message = [aClass insertNewObjectInManagedObjectContext:self.uiMOC];
    XCTAssertNotNil(message);
    message.sender = user;
    XCTAssertEqual(message.sender, user);
    
    XCTAssertTrue([self.uiMOC save:&error], @"Save failed: %@", error);
    
    ZMMessage *message2 = (id) [self.syncMOC existingObjectWithID:message.objectID error:&error];
    XCTAssertNotNil(message2, @"Failed to load into other context: %@", error);
    ZMUser *user2 = message2.sender;
    XCTAssertNotNil(user2);
    
    XCTAssertEqualObjects(user2.objectID, user.objectID);
}

- (void)testThatItDoesNotUseTemporaryIDsForSender;
{
    // given
    ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.sender = user;
    
    // when
    XCTAssertTrue([self.uiMOC saveOrRollback]);
    [self.uiMOC refreshObject:user mergeChanges:NO];
    [self.uiMOC refreshObject:message mergeChanges:NO];
    
    // then
    XCTAssertEqual(message.sender, user);
}

- (void)testThatItMatchesObjectsThatNeedToBeInsertedUpstream
{
    // given
    ZMMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    NSPredicate *sut = [ZMTextMessage predicateForObjectsThatNeedToBeInsertedUpstream];
    
    // when
    message.eventID = nil;
    // then
    XCTAssertTrue([sut evaluateWithObject:message]);
    
    // when
    message.eventID = [self createEventID];
    // then
    XCTAssertFalse([sut evaluateWithObject:message]);
}


- (void)testThatItDoesNotMatchExpiredObjectsForInsertingUpstream
{
    // given
    ZMMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    NSPredicate *sut = [ZMTextMessage predicateForObjectsThatNeedToBeInsertedUpstream];

    XCTAssertFalse(message.isExpired);
    
    // then
    XCTAssertTrue([sut evaluateWithObject:message]);

    
    // when
    [message expire];
    // then
    XCTAssertFalse([sut evaluateWithObject:message]);
}



- (void)testThatExpiringAMessageSetsTheExpirationDateToNil
{
    // given
    ZMMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    [ZMMessage setDefaultExpirationTime:12345];
    [message setExpirationDate];
    XCTAssertFalse(message.isExpired);
    
    // when
    [message expire];

    // then
    XCTAssertTrue(message.isExpired);
    XCTAssertNil(message.expirationDate);
    
    // finally
    [ZMMessage resetDefaultExpirationTime];
}

- (void)testThatSpecialKeysAreNotPartOfTheLocallyModifiedKeysForTextMessages
{
    //given
    NSArray *expected = @[IsExpiredKey];

    // when
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertEqualObjects(message.keysTrackedForLocalModifications, expected);
}

- (void)testThatSpecialKeysAreNotPartOfTheLocallyModifiedKeysForSystemMessages
{
    //given
    NSArray *expected = @[IsExpiredKey];
    
    // when
    ZMSystemMessage *message = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertEqualObjects(message.keysTrackedForLocalModifications, expected);
}


- (void)testThatSpecialKeysAreNotPartOfTheLocallyModifiedKeysForImageMessages
{
    // given
    NSSet *expected = [NSSet setWithObjects:IsExpiredKey, nil];
    
    // when
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertEqualObjects([NSSet setWithArray:message.keysTrackedForLocalModifications], expected);
}

- (void)testThatSpecialKeysAreNotPartOfTheLocallyModifiedKeysForClientMessages
{
    // when
    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    NSArray *keysThatShouldBeTracked = @[@"dataSet", @"linkPreviewState"];
    AssertArraysContainsSameObjects(message.keysTrackedForLocalModifications, keysThatShouldBeTracked);
}

- (void)testThat_doesEventGenerateMessage_returnsTrueForAllKnownTypes
{
    NSArray *validTypes = @[
                            @(ZMUpdateEventConversationMemberJoin),
                            @(ZMUpdateEventConversationMemberLeave),
                            @(ZMUpdateEventConversationRename),
                            @(ZMUpdateEventConversationConnectRequest),
                            @(ZMUpdateEventConversationMessageAdd),
                            @(ZMUpdateEventConversationClientMessageAdd),
                            @(ZMUpdateEventConversationOtrMessageAdd),
                            @(ZMUpdateEventConversationOtrAssetAdd),
                            @(ZMUpdateEventConversationAssetAdd),
                            @(ZMUpdateEventConversationVoiceChannelDeactivate),
                            @(ZMUpdateEventConversationKnock),
                            ];
    for(NSUInteger evt = 0; evt < ZMUpdateEvent_LAST; ++evt) {
        XCTAssertEqual([ZMMessage doesEventTypeGenerateMessage:evt], [validTypes containsObject:@(evt)]);
    }
}

- (void)testThatTheTextIsCopied
{
    // given
    NSString *originalValue = @"will@foo.co";
    NSMutableString *mutableValue = [originalValue mutableCopy];
    ZMTextMessage *msg = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    msg.text = mutableValue;
    [mutableValue appendString:@".uk"];
    
    // then
    XCTAssertEqualObjects(msg.text, originalValue);
}

- (void)testThatItFetchesTheLatestPotentialGapSystemMessage
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    NSDate *olderDate = [NSDate dateWithTimeIntervalSinceNow:-1000];
    NSDate *newerDate = [NSDate date];
    [conversation appendNewPotentialGapSystemMessageWithUsers:nil timestamp:olderDate];
    [conversation appendNewPotentialGapSystemMessageWithUsers:nil timestamp:newerDate];
    
    // when
    ZMSystemMessage *fetchedMessage = [ZMSystemMessage fetchLatestPotentialGapSystemMessageInConversation:conversation];
    
    // then
    XCTAssertNotNil(fetchedMessage);
    XCTAssertTrue(fetchedMessage.needsUpdatingUsers);
    XCTAssertEqualObjects(newerDate, fetchedMessage.serverTimestamp);
}

- (void)testThatItOnlyFetchesSystemMesssagesInTheCorrectConversation
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMConversation *otherConversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    NSDate *olderDate = [NSDate dateWithTimeIntervalSinceNow:-1000];
    NSDate *newerDate = [NSDate date];
    
    [conversation appendNewPotentialGapSystemMessageWithUsers:nil timestamp:olderDate];
    [conversation appendMessageWithText:@"Awesome Text"];
    [otherConversation appendNewPotentialGapSystemMessageWithUsers:nil timestamp:newerDate];
    
    // when
    ZMSystemMessage *fetchedMessage = [ZMSystemMessage fetchLatestPotentialGapSystemMessageInConversation:conversation];
    
    // then
    XCTAssertNotNil(fetchedMessage);
    XCTAssertTrue(fetchedMessage.needsUpdatingUsers);
    XCTAssertEqualObjects(olderDate, fetchedMessage.serverTimestamp);
    XCTAssertEqual(conversation.messages.count, 2lu);
}

- (void)testThatItUpdatedNeedsUpdatingUsersOnPotentialGapSystemMessageCorrectlyIfUserNameIsNil
{
    // given
    ZMUser *firstUser = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMUser *secondUser = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    NSSet <ZMUser *>*users = [NSSet setWithObjects:firstUser, secondUser, nil];
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    [conversation appendNewPotentialGapSystemMessageWithUsers:nil timestamp:NSDate.date];
    
    ZMSystemMessage *systemMessage = [ZMSystemMessage fetchLatestPotentialGapSystemMessageInConversation:conversation];
    XCTAssertEqual(systemMessage.systemMessageType, ZMSystemMessageTypePotentialGap);
    XCTAssertEqual(conversation.messages.count, 1lu);
    XCTAssertTrue(systemMessage.needsUpdatingUsers);
    
    // when
    [conversation updatePotentialGapSystemMessagesIfNeededWithUsers:users];
    [systemMessage updateNeedsUpdatingUsersIfNeeded];
    
    // then
    XCTAssertTrue(systemMessage.needsUpdatingUsers);
    XCTAssertEqualObjects(systemMessage.addedUsers, users);
    
    // when
    firstUser.name = @"Annette";
    [systemMessage updateNeedsUpdatingUsersIfNeeded];
    
    // then
    XCTAssertTrue(systemMessage.needsUpdatingUsers);
    
    // when
    secondUser.name = @"Heiner";
    [systemMessage updateNeedsUpdatingUsersIfNeeded];
    
    // then
    XCTAssertFalse(systemMessage.needsUpdatingUsers);
}

@end



@implementation ZMMessageTests (TextMessage)


- (void)testThatATextMessageHasTextMessageData
{
    // given
    ZMTextMessage *message = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.text = @"Foo";
    // then
    XCTAssertEqualObjects(message.text, @"Foo");
    XCTAssertNil(message.systemMessageData);
    XCTAssertNil(message.imageMessageData);
    XCTAssertNil(message.knockMessageData);
}

@end



@implementation ZMMessageTests (ImageMessages)

- (void)testThatSettingTheOriginalDataRecognizesAGif
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.originalImageData = [self dataForResource:@"animated" extension:@"gif"];
    
    // then
    XCTAssertTrue(message.isAnimatedGIF);
}


- (void)testThatSettingTheOriginalDataRecognizesAStaticImageAsNotGif
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.originalImageData = [self dataForResource:@"tiny" extension:@"jpg"];
    
    // then
    XCTAssertFalse(message.isAnimatedGIF);
}

- (void)testThatAnEmptyImageMessageIsNotAnAnimatedGIF
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertFalse(message.isAnimatedGIF);
}

- (void)testThatAMediumJPEGIsNotAnAnimatedGIF
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.mediumData = [self dataForResource:@"tiny" extension:@"jpg"];
    XCTAssertNotNil(message.mediumData);
    
    // then
    XCTAssertFalse(message.isAnimatedGIF);
}

- (void)testThatAGIFWithOnlyOneFrameIsNotAnAnimatedGIF
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.mediumData = [self dataForResource:@"not_animated" extension:@"gif"];
    XCTAssertNotNil(message.mediumData);
    
    // then
    XCTAssertFalse(message.isAnimatedGIF);
}


- (void)testThatAGIFWithMoreThanOneFrameIsRecognizedAsAnimatedGIF
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.mediumData = [self dataForResource:@"animated" extension:@"gif"];
    XCTAssertNotNil(message.mediumData);
    
    // then
    XCTAssertTrue(message.isAnimatedGIF);
}

- (void)testThatAnEmptyImageMessageHasNoType
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertNil(message.imageType);
}

- (void)testThatAMediumJPEGIsHasJPGType
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.mediumData = [self dataForResource:@"tiny" extension:@"jpg"];
    XCTAssertNotNil(message.mediumData);
    
    // then
    NSString *expected = (__bridge NSString *) kUTTypeJPEG;
    XCTAssertEqualObjects(message.imageType, expected);
}

- (void)testThatAOneFrameMediumGIFHasGIFType
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.mediumData = [self dataForResource:@"not_animated" extension:@"gif"];
    XCTAssertNotNil(message.mediumData);
    
    // then
    NSString *expected = (__bridge NSString *) kUTTypeGIF;
    XCTAssertEqualObjects(message.imageType, expected);
}

- (void)testThatAnAnimatedMediumGIFHasGIFType
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.mediumData = [self dataForResource:@"animated" extension:@"gif"];
    XCTAssertNotNil(message.mediumData);
    
    // then
    NSString *expected = (__bridge NSString *) kUTTypeGIF;
    XCTAssertEqualObjects(message.imageType, expected);
}

- (void)testThatAnImageMessageHasImageMessageData
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertNil(message.textMessageData.messageText);
    XCTAssertNil(message.systemMessageData);
    XCTAssertNotNil(message.imageMessageData);
    XCTAssertNil(message.knockMessageData);
}

- (void)testThatItUpdatesTheServerTimestampAfterPreviewWasUploaded
{
    // given
    NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970:123456];
    NSDate *updatedDate = [NSDate dateWithTimeIntervalSince1970:127476];
    
    ZMAssetClientMessage *message = [ZMAssetClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.serverTimestamp = referenceDate;
    message.uploadState = ZMAssetUploadStateUploadingPlaceholder;
    
    NSSet *updatedKeys = [NSSet setWithObject:ZMAssetClientMessageUploadedStateKey];

    
    // when
    [message updateWithPostPayload:@{@"time" : updatedDate.transportString } updatedKeys:updatedKeys];
    
    // then
    XCTAssertEqualObjects(message.serverTimestamp, updatedDate);
}

- (void)testThatItDoesNotUpdateTheServerTimestampAfterMediumWasUploaded
{
    // given
    NSDate *referenceDate = [NSDate dateWithTimeIntervalSince1970:123456];
    NSDate *updatedDate = [NSDate dateWithTimeIntervalSince1970:127476];
    
    ZMAssetClientMessage *message = [ZMAssetClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.serverTimestamp = referenceDate;
    message.uploadState = ZMAssetUploadStateUploadingFullAsset;
    
    NSSet *updatedKeys = [NSSet setWithObject:ZMAssetClientMessageUploadedStateKey];
    
    // when
    [message updateWithPostPayload:@{@"time" : updatedDate.transportString } updatedKeys:updatedKeys];
    
    // then
    XCTAssertEqualObjects(message.serverTimestamp, referenceDate);
}

@end



@implementation ZMMessageTests (ImageIdentifiersForCaching)

- (void)testThatItDoesNotReturnAnIdentifierWhenTheImageDataIsNil
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.originalImageData = nil;
    message.mediumData = nil;
    message.mediumRemoteIdentifier = nil;

    // when
    NSString *identifier = message.imageDataIdentifier;
    
    // then
    XCTAssertNil(identifier);
}

- (void)testThatItReturnsATemporaryIdentifierForTheOriginalImageData;
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.originalImageData = self.verySmallJPEGData;
    
    // when
    NSString *identifierA = message.imageDataIdentifier;
    message.mediumRemoteIdentifier = NSUUID.createUUID;
    NSString *identifierB = message.imageDataIdentifier;
    
    // then
    XCTAssertNotNil(identifierA);
    XCTAssertNotNil(identifierB);
    XCTAssertNotEqualObjects(identifierA, identifierB);
}

- (void)testThatItReturnsAnIdentifierForTheImageData;
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.mediumRemoteIdentifier = NSUUID.createUUID;
    
    // when
    NSString *identifierA = message.imageDataIdentifier;
    message.mediumRemoteIdentifier = NSUUID.createUUID;
    NSString *identifierB = message.imageDataIdentifier;
    
    // then
    XCTAssertNotNil(identifierA);
    XCTAssertNotNil(identifierB);
    XCTAssertNotEqualObjects(identifierA, identifierB);
}

- (void)testThatItReturnsAnIdentifierForTheImagePreviewData;
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.previewData = self.verySmallJPEGData;
    
    // when
    NSString *identifier = message.imagePreviewDataIdentifier;
    
    // then
    XCTAssertNotNil(identifier);
    XCTAssertGreaterThan(identifier.length, 0u);
}

- (void)testThatItDoesNotReturnAnIdentifierWhenTheImagePreviewDataIsNil
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    message.previewData = nil;
    
    // when
    NSString *identifier = message.imagePreviewDataIdentifier;
    
    // then
    XCTAssertNil(identifier);
}

@end



@implementation ZMMessageTests (ImageMessageUploadAttributes)

- (void)testThatItRequiresPreviewAndMediumData
{
    // given
    ZMImageMessage *message = [ZMImageMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    NSOrderedSet *expectedFormats = [NSOrderedSet orderedSetWithObjects:@(ZMImageFormatPreview), @(ZMImageFormatMedium), nil];
    
    //then
    XCTAssertEqualObjects(message.requiredImageFormats,  expectedFormats);
}

@end




@implementation ZMMessageTests (CreateSystemMessageFromUpdateEvent)

- (void)testThat_isEventTypeGeneratingSystemMessage_returnsNo
{
    // invalid types
    NSArray *validTypes = @[
        @(ZMUpdateEventConversationMemberJoin),
        @(ZMUpdateEventConversationMemberLeave),
        @(ZMUpdateEventConversationRename),
        @(ZMUpdateEventConversationConnectRequest),
        @(ZMUpdateEventConversationVoiceChannelDeactivate)
    ];
    
    for(NSUInteger evt = 0; evt < ZMUpdateEvent_LAST; ++evt) {
        XCTAssertEqual([ZMSystemMessage doesEventTypeGenerateSystemMessage:evt], [validTypes containsObject:@(evt)]);
    }
}

- (id)mockEventOfType:(ZMUpdateEventType)type forConversation:(ZMConversation *)conversation sender:(NSUUID *)senderID data:(NSDictionary *)data
{
    ZMUpdateEvent *updateEvent = [OCMockObject mockForClass:ZMUpdateEvent.class];
    (void)[(ZMUpdateEvent *)[[(id)updateEvent stub] andReturnValue:OCMOCK_VALUE(type)] type];
    NSDate *serverTimeStamp = conversation.lastServerTimeStamp ? [conversation.lastServerTimeStamp dateByAddingTimeInterval:5] : [NSDate date];
    ZMEventID *eventID = [self createEventID];
    NSUUID *from = senderID ?: NSUUID.createUUID;
    NSDictionary *payload = @{
                              @"conversation" : conversation.remoteIdentifier.transportString,
                              @"id" : eventID,
                              @"time" : serverTimeStamp.transportString,
                              @"from" : from.transportString,
                              @"data" : data
                              };
    (void)[(ZMUpdateEvent *)[[(id)updateEvent stub] andReturn:payload] payload];
    
    NSUUID *nonce = [NSUUID UUID];
    (void)[(ZMUpdateEvent *)[[(id)updateEvent stub] andReturn:nonce] messageNonce];
    (void)[(ZMUpdateEvent *)[[(id)updateEvent stub] andReturn:serverTimeStamp] timeStamp];
    (void)[(ZMUpdateEvent *)[[(id)updateEvent stub] andReturn:conversation.remoteIdentifier] conversationUUID];
    (void)[(ZMUpdateEvent *)[[(id)updateEvent stub] andReturn:eventID] eventID];
    (void)[(ZMUpdateEvent *)[[(id)updateEvent stub] andReturn:from] senderUUID];
    return updateEvent;
}

- (ZMSystemMessage *)createSystemMessageFromType:(ZMUpdateEventType)updateEventType inConversation:(ZMConversation *)conversation withUsersIDs:(NSArray *)userIDs senderID:(NSUUID *)senderID
{
    NSDictionary *data =@{
                          @"user_ids" : [userIDs mapWithBlock:^id(id obj) {
                              return [obj transportString];
                          }],
                          @"reason" : @"missed"
                          };
    ZMUpdateEvent *updateEvent = [self mockEventOfType:updateEventType forConversation:conversation sender:senderID data:data];
    ZMSystemMessage *systemMessage = [ZMSystemMessage createOrUpdateMessageFromUpdateEvent:updateEvent inManagedObjectContext:self.uiMOC prefetchResult:nil];
    return systemMessage;
}

- (ZMSystemMessage *)createConversationNameChangeSystemMessageInConversation:(ZMConversation *)conversation inManagedObjectContext:(NSManagedObjectContext *)moc
{
    NSDictionary *data = @{@"name" : conversation.displayName};
    ZMUpdateEvent *updateEvent = [self mockEventOfType:ZMUpdateEventConversationRename forConversation:conversation sender:nil data:data];

    ZMSystemMessage *systemMessage = [ZMSystemMessage createOrUpdateMessageFromUpdateEvent:updateEvent inManagedObjectContext:moc prefetchResult:nil];
    return systemMessage;
}

- (ZMSystemMessage *)createConversationConnectRequestSystemMessageInConversation:(ZMConversation *)conversation inManagedObjectContext:(NSManagedObjectContext *)moc
{
    NSDictionary *data = @{
                           @"message" : @"This is a very important message"
                           };
    ZMUpdateEvent *updateEvent = [self mockEventOfType:ZMUpdateEventConversationConnectRequest forConversation:conversation sender:nil data:data];
    ZMSystemMessage *systemMessage = [ZMSystemMessage createOrUpdateMessageFromUpdateEvent:updateEvent inManagedObjectContext:moc prefetchResult:nil];
    return systemMessage;
}

- (void)checkThatUpdateEventType:(ZMUpdateEventType)updateEventType generatesSystemMessageType:(ZMSystemMessageType)systemMessageType failureRecorder:(ZMTFailureRecorder *)fr;
{
    
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    if (updateEventType != ZMUpdateEventConversationConnectRequest) {
        conversation.conversationType = ZMConversationTypeGroup;
    }
    else {
        conversation.conversationType = ZMConversationTypeConnection;
    }
    
    conversation.remoteIdentifier = [NSUUID createUUID];
    NSUUID *userID1 = [NSUUID createUUID];
    NSUUID *userID2 = [NSUUID createUUID];
    
    // when
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:updateEventType inConversation:conversation withUsersIDs:@[userID1, userID2] senderID:nil];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    FHAssertNotNil(fr, message);
    FHAssertEqual(fr, message.systemMessageType, systemMessageType);
    FHAssertEqual(fr, message.users.count, 2u);
    ZMUser *user1 = (ZMUser *) [message.users objectsPassingTest:^BOOL(ZMUser* obj, BOOL *stop ZM_UNUSED) {
        return [obj.remoteIdentifier isEqual:userID1];
    }];
    ZMUser *user2 = (ZMUser *) [message.users objectsPassingTest:^BOOL(ZMUser* obj, BOOL *stop ZM_UNUSED) {
        return [obj.remoteIdentifier isEqual:userID2];
    }];
    
    FHAssertNotNil(fr, user1);
    FHAssertNotNil(fr, user2);
    FHAssertEqual(fr, conversation.messages.count, 1u);
    FHAssertEqual(fr, message, conversation.messages.firstObject);
    FHAssertFalse(fr, message.isEncrypted);
    FHAssertTrue(fr, message.isPlainText);
}

- (void)checkThatUpdateEventTypeDoesNotGenerateMessage:(ZMUpdateEventType)updateEventType {
    
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    // when
    ZMSystemMessage *message = [self createSystemMessageFromType:updateEventType inConversation:conversation withUsersIDs:@[] senderID:nil];
    
    // then
    XCTAssertNil(message);
}

- (void)testThatItGeneratesTheCorrectSystemMessageTypesFromUpdateEvents
{
    // expect a message
    [self checkThatUpdateEventType:ZMUpdateEventConversationMemberJoin generatesSystemMessageType:ZMSystemMessageTypeParticipantsAdded failureRecorder:NewFailureRecorder()];

    [self checkThatUpdateEventType:ZMUpdateEventConversationMemberLeave generatesSystemMessageType:ZMSystemMessageTypeParticipantsRemoved failureRecorder:NewFailureRecorder()];

    [self checkThatUpdateEventType:ZMUpdateEventConversationRename generatesSystemMessageType:ZMSystemMessageTypeConversationNameChanged failureRecorder:NewFailureRecorder()];
    
    [self checkThatUpdateEventType:ZMUpdateEventConversationConnectRequest generatesSystemMessageType:ZMSystemMessageTypeConnectionRequest failureRecorder:NewFailureRecorder()];
    
    [self checkThatUpdateEventType:ZMUpdateEventConversationVoiceChannelDeactivate generatesSystemMessageType:ZMSystemMessageTypeMissedCall failureRecorder:NewFailureRecorder()];
}

- (void)testThatItDoesNotGenerateSystemMessagesFromUpdateEventsOfTheWrongType
{
    for(NSUInteger evt = 0; evt < ZMUpdateEvent_LAST; ++evt)
    {
        if( ! [ZMSystemMessage doesEventTypeGenerateSystemMessage:evt] ) {
            [self checkThatUpdateEventTypeDoesNotGenerateMessage:evt];
        }
    }
}

- (void)testThatItStoresPermanentManagedObjectIdentifiersInTheUserField
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMUser *user1 = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        ZMUser *user2 = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        
        ZMSystemMessage *message = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        message.users = [NSSet setWithObjects:user1, user2, nil];
    }];
    [self.syncMOC saveOrRollback];
    
    // when
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *result = [self.uiMOC executeFetchRequestOrAssert:request];

    // then
    XCTAssertNotNil(result);
    XCTAssertEqual(result.count, 1u);
    ZMSystemMessage *message = result[0];
    XCTAssertNotNil(message);
    NSSet *users = message.users;
    
    XCTAssertEqual(users.count, 2u);
}

- (void)testThatItSavesTheConversationTitleInConversationNameChangeSystemMessage
{
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.userDefinedName = @"Conversation Name1";
        conversation.remoteIdentifier = [NSUUID createUUID];
        conversation.conversationType = ZMConversationTypeGroup;
        XCTAssertNotNil(conversation);
        XCTAssertEqualObjects(conversation.displayName, conversation.userDefinedName);
        
        // load a message from the second context and check that the objectIDs for users are as expected
        ZMSystemMessage *message = [self createConversationNameChangeSystemMessageInConversation:conversation inManagedObjectContext:self.syncMOC];
        XCTAssertNotNil(message);
    }];
    [self.syncMOC saveOrRollback];
    
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.userDefinedName = @"Conversation Name2";
        conversation.remoteIdentifier = [NSUUID createUUID];
        conversation.conversationType = ZMConversationTypeGroup;

        XCTAssertNotNil(conversation);
        XCTAssertEqualObjects(conversation.displayName, conversation.userDefinedName);
        
        // load a message from the second context and check that the objectIDs for users are as expected
       ZMSystemMessage *message = [self createConversationNameChangeSystemMessageInConversation:conversation inManagedObjectContext:self.syncMOC];
        XCTAssertNotNil(message);
    }];
    [self.syncMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertNotNil(messages);
    XCTAssertEqual(messages.count, 2u);

    XCTAssertNotNil(messages[0]);
    NSString *text1 = [(ZMTextMessage *)messages[0] text];
    XCTAssertNotNil(text1);
    XCTAssertEqualObjects(text1, @"Conversation Name1");

    XCTAssertNotNil(messages[1]);
    NSString *text2 = [(ZMTextMessage *)messages[1] text];
    XCTAssertNotNil(text2);
    XCTAssertEqualObjects(text2, @"Conversation Name2");
}

- (void)testThatItSavesMessageTextFromConnectionRequestsInSystemMessage
{
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conversation.remoteIdentifier = [NSUUID createUUID];
        XCTAssertNotNil(conversation);
        
        // load a message from the second context and check that the objectIDs for users are as expected
        ZMSystemMessage *message = [self createConversationConnectRequestSystemMessageInConversation:conversation  inManagedObjectContext:self.syncMOC];
        XCTAssertNotNil(message);
    }];
    [self.syncMOC saveOrRollback];
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertNotNil(messages);
    XCTAssertEqual(messages.count, 1u);
    
    XCTAssertNotNil(messages[0]);
    NSString *text = [(ZMTextMessage *)messages[0] text];
    XCTAssertNotNil(text);
    XCTAssertEqualObjects(text, @"This is a very important message");

}

- (void)testThatItReturnsSenderIFItsTheOnlyUserContainedInUserIDs
{
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.conversationType = ZMConversationTypeGroup;
    XCTAssertNotNil(conversation);
    XCTAssertEqual(conversation.conversationType, ZMConversationTypeGroup);
    
    ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    sender.remoteIdentifier = [NSUUID createUUID];
    [self.uiMOC saveOrRollback];
    
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationMemberJoin inConversation:conversation withUsersIDs:@[sender.remoteIdentifier] senderID:sender.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertNotNil(messages);
    XCTAssertEqual(messages.count, 1u);
    
    XCTAssertNotNil(messages.firstObject);
    XCTAssertEqualObjects(messages.firstObject, message);
    
    NSSet *userSet = message.users;
    XCTAssertNotNil(userSet);
    XCTAssertEqual(userSet.count, 1u);
    XCTAssertEqualObjects(userSet, [NSSet setWithObject:message.sender]);
}

- (void)testThatItReturnsOnlyOtherUsersIfTheSenderIsNotTheOnlyUserContainedInUserIDs
{
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.conversationType = ZMConversationTypeGroup;
    XCTAssertNotNil(conversation);
    XCTAssertEqual(conversation.conversationType, ZMConversationTypeGroup);
    
    ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    sender.remoteIdentifier = [NSUUID createUUID];
    [self.uiMOC saveOrRollback];
    
    ZMUser *otherUser = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    otherUser.remoteIdentifier = [NSUUID createUUID];
    [self.uiMOC saveOrRollback];
    
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationMemberJoin inConversation:conversation withUsersIDs:@[sender.remoteIdentifier, otherUser.remoteIdentifier] senderID:sender.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertNotNil(messages);
    XCTAssertEqual(messages.count, 1u);
    
    XCTAssertNotNil(messages.firstObject);
    XCTAssertEqualObjects(messages.firstObject, message);
    
    NSSet *userSet = message.users;
    XCTAssertNotNil(userSet);
    XCTAssertEqual(userSet.count, 1u);
    XCTAssertEqualObjects(userSet, [NSSet setWithObject:otherUser]);
}

- (void)testThatItCreatesASystemMessageForAddingTheSelfUserToAGroupConversation
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.conversationType = ZMConversationTypeGroup;
    XCTAssertNotNil(conversation);
    
    ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    sender.remoteIdentifier = [NSUUID createUUID];
    
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = [NSUUID createUUID];
    [self.uiMOC saveOrRollback];

    // add selfUser to the conversation
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationMemberJoin inConversation:conversation withUsersIDs:@[sender.remoteIdentifier, selfUser.remoteIdentifier] senderID:sender.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertNotNil(messages);
    XCTAssertEqual(messages.count, 1u);
    
    XCTAssertNotNil(messages.firstObject);
    XCTAssertEqualObjects(messages.firstObject, message);
    
    NSSet *userSet = message.users;
    XCTAssertNotNil(userSet);
    XCTAssertEqual(userSet.count, 1u);
    XCTAssertEqualObjects(userSet, [NSSet setWithObject:selfUser]);
}


- (void)testThatItDoesNotCreateASystemMessageForAddingTheSelfuserToAConnectionConversation
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.conversationType = ZMConversationTypeConnection;
    XCTAssertNotNil(conversation);
    
    ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    sender.remoteIdentifier = [NSUUID createUUID];
    
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    selfUser.remoteIdentifier = [NSUUID createUUID];
    [self.uiMOC saveOrRollback];
    
    // add selfUser to the conversation
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationMemberJoin inConversation:conversation withUsersIDs:@[sender.remoteIdentifier, selfUser.remoteIdentifier] senderID:sender.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertEqual(messages.count, 0u);
}

- (void)testThatItSetsLastReadEventIDForVoiceChannelDeactiveEventFromSelfUser
{
    // given
    NSDate *oldDate = [NSDate date];

    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.lastServerTimeStamp = oldDate;
    conversation.lastReadServerTimeStamp = oldDate;
    XCTAssertNotNil(conversation);
    
    [self.uiMOC saveOrRollback];
    
    // add selfUser to the conversation
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationVoiceChannelDeactivate inConversation:conversation withUsersIDs:@[] senderID:self.selfUser.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertEqual(messages.count, 1u);

    XCTAssertNotEqualWithAccuracy([conversation.lastReadServerTimeStamp timeIntervalSince1970], [oldDate timeIntervalSince1970], 0.5);
    XCTAssertEqualWithAccuracy([conversation.lastReadServerTimeStamp timeIntervalSince1970], [[(ZMMessage *)messages.lastObject serverTimestamp] timeIntervalSince1970], 0.5);
}

- (void)testThatItSetsLastReadServerTimeStampForVoiceChannelDeactiveEventFromSelfUser
{
    // given
    NSDate *oldServerTimeStamp = [NSDate date];
    
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.lastReadServerTimeStamp = oldServerTimeStamp;
    conversation.lastServerTimeStamp = oldServerTimeStamp;
    XCTAssertNotNil(conversation);
    
    [self.uiMOC saveOrRollback];
    
    // add selfUser to the conversation
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationVoiceChannelDeactivate inConversation:conversation withUsersIDs:@[] senderID:self.selfUser.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertEqual(messages.count, 1u);
    
    XCTAssertNotEqualObjects(conversation.lastReadServerTimeStamp, oldServerTimeStamp);
    XCTAssertEqualObjects(conversation.lastServerTimeStamp, [(ZMMessage *)messages.lastObject serverTimestamp]);
}


- (void)testThatItIncreasesUnreadCountForVoiceChannelDeactiveEventFromOtherUser
{
    // given
    ZMEventID *oldEventID = self.createEventID;
    
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.conversationType = ZMConversationTypeOneOnOne;
    conversation.lastReadEventID = oldEventID;

    XCTAssertNotNil(conversation);
    
    ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    sender.remoteIdentifier = [NSUUID createUUID];
    
    [self.uiMOC saveOrRollback];
    
    // add selfUser to the conversation
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationVoiceChannelDeactivate inConversation:conversation withUsersIDs:@[] senderID:sender.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    NSFetchRequest *request = [ZMSystemMessage sortedFetchRequest];
    NSArray *messages = [self.uiMOC executeFetchRequestOrAssert:request];
    
    // then
    XCTAssertEqual(messages.count, 1u);
    XCTAssertEqualObjects(conversation.lastReadEventID, oldEventID);
    XCTAssertNotEqualObjects(conversation.lastReadEventID, [(ZMMessage *)messages.lastObject eventID]);

}

- (void)testThatItMarksSentConnectionRequestMessageAsReadOnUpdateEvent
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    ZMMessage *oldMessage = [conversation appendMessageWithText:@"Hi!"];
    oldMessage.serverTimestamp = [NSDate dateWithTimeIntervalSince1970:1234567];
    conversation.lastServerTimeStamp = oldMessage.serverTimestamp;
    conversation.lastReadServerTimeStamp = oldMessage.serverTimestamp;
    
    // when
    __block ZMSystemMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [self createSystemMessageFromType:ZMUpdateEventConversationConnectRequest inConversation:conversation withUsersIDs:@[] senderID:self.selfUser.remoteIdentifier];
    }];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertEqual(conversation.lastReadServerTimeStamp, message.serverTimestamp);
    XCTAssertTrue([[conversation keysThatHaveLocalModifications] containsObject:ZMConversationLastReadServerTimeStampKey]);
}

- (void)testThatASystemMessageHasSystemMessageData
{
    // given
    ZMSystemMessage *message = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertNil(message.textMessageData.messageText);
    XCTAssertNotNil(message.systemMessageData);
    XCTAssertNil(message.imageMessageData);
    XCTAssertNil(message.knockMessageData);
}

- (void)testThatItReturnsTheOriginalImageDataWhenTheMediumDataIsNotAvailable;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    NSData *jpegData = self.verySmallJPEGData;
    id<ZMConversationMessage> temporaryMessage = [conversation appendMessageWithImageData:jpegData];
    
    // when
    NSData *imageData = [temporaryMessage imageMessageData].imageData;
    
    // then
    XCTAssertNotNil(imageData);
    AssertEqualData(imageData, jpegData);
}

@end




@implementation ZMMessageTests (CreateMessageFromUpdateEvent)

- (void)testThatItCreatesTextMessagesFromUpdateEvent
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *data = @{
                           @"content" : self.name,
                           @"nonce" : nonce.transportString
                           };
    
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];

    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMTextMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertNotNil(sut);
    XCTAssertEqualObjects(sut.eventID, [ZMEventID eventIDWithString:payload[@"id"]]);
    XCTAssertEqualObjects(sut.conversation, conversation);
    XCTAssertEqualObjects(sut.sender.remoteIdentifier.transportString, payload[@"from"]);
    XCTAssertEqualObjects(sut.serverTimestamp.transportString, payload[@"time"]);
    XCTAssertFalse(sut.isEncrypted);
    XCTAssertTrue(sut.isPlainText);
    XCTAssertEqualObjects(sut.nonce, nonce);
    XCTAssertEqualObjects(sut.text, self.name);
}

- (void)testThatItDoesNotCreateTextMessagesFromUpdateEventIfThereIsAlreadyAClientMessageWithTheSameNonce
{
    // given
    NSUUID *nonce = [NSUUID createUUID];

    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    ZMClientMessage *clientMessage = [ZMClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    clientMessage.visibleInConversation = conversation;
    clientMessage.nonce = nonce;
    
    NSDictionary *data = @{
                           @"content" : self.name,
                           @"nonce" : nonce.transportString
                           };
    
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMTextMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertNil(sut);
    XCTAssertEqual(conversation.messages.count, 1u);
    XCTAssertEqual(conversation.messages.firstObject, clientMessage);
}

- (void)testThatItUpdatesIsPlainTextOnAlreadyExistingClientMessageWithTheSameNonceWhenReceivingATextMessageFromUpdateEvent
{
    // given
    NSUUID *nonce = [NSUUID createUUID];
    
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    ZMClientMessage *clientMessage = [ZMClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    clientMessage.visibleInConversation = conversation;
    clientMessage.nonce = nonce;
    XCTAssertFalse(clientMessage.isPlainText);
    
    NSDictionary *data = @{
                           @"content" : self.name,
                           @"nonce" : nonce.transportString
                           };
    
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    [self performPretendingUiMocIsSyncMoc:^{
        [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertTrue(clientMessage.isPlainText);
}

- (void)testThatItUsesPrefetchedMessageInsteadOfPerformingAFetchRequestWhenUpdatingAClientMessageMessageFromTextMessageUpdateEvent
{
    [self checkThatItDoesExecuteAFetchRequestForExistingMessagesWhenReceivingUpdateEvent:NO];
}

- (void)testThatItFetchesMessageWhenThereAreNoPrefetchedMessagesWhenUpdatingAClientMessageMessageFromTextMessageUpdateEvent
{
    [self checkThatItDoesExecuteAFetchRequestForExistingMessagesWhenReceivingUpdateEvent:YES];
}

- (void)checkThatItDoesExecuteAFetchRequestForExistingMessagesWhenReceivingUpdateEvent:(BOOL)shouldExecuteFetchRequest
{
    // given
    NSUUID *nonce = [NSUUID createUUID];
    
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    ZMClientMessage *clientMessage = [ZMClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    clientMessage.visibleInConversation = conversation;
    clientMessage.nonce = nonce;
    XCTAssertFalse(clientMessage.isPlainText);
    XCTAssertTrue([self.uiMOC saveOrRollback]);
    
    NSDictionary *data = @{ @"content" : @"Super updated mega content", @"nonce" : nonce.transportString };
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // expect
    id mockContext = [OCMockObject partialMockForObject:self.uiMOC];
    __block BOOL didPerformRequest = NO;
    
    [[[[mockContext stub] andDo:^(NSInvocation *invocation) {
        __unsafe_unretained NSFetchRequest *firstArgument;
        [invocation getArgument:&firstArgument atIndex:2];
        
        if([firstArgument.entityName isEqualToString:ZMClientMessage.entityName]) {
            didPerformRequest = YES;
        }
    }] andForwardToRealObject] executeFetchRequestOrAssert:OCMOCK_ANY];
    
    NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
    mapping[nonce] = [NSMutableSet setWithObject:clientMessage];
    
    ZMFetchRequestBatchResult *prefetchResult = [[ZMFetchRequestBatchResult alloc] init];
    id mockResult = [OCMockObject partialMockForObject:prefetchResult];
    [[[mockResult stub] andReturn:mapping] messagesByNonce];
    
    // We need to turn the message into a fault
    [self.uiMOC refreshObject:clientMessage mergeChanges:NO];
    XCTAssertTrue(clientMessage.isFault);
    
    // when
    [self performPretendingUiMocIsSyncMoc:^{
        [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event
                                     inManagedObjectContext:mockContext
                                             prefetchResult:shouldExecuteFetchRequest ? nil : prefetchResult];
    }];
    
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertTrue(clientMessage.isPlainText);
    XCTAssertEqual(didPerformRequest, shouldExecuteFetchRequest);
    
    // after
    [mockContext stopMocking];
    [mockResult stopMocking];
}

- (void)testThatItUpdatesAMessageWithTheSameNonceIfItsAlreadyPresentFromUpdateEvent
{
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];

    
    ZMTextMessage *textMessage = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    textMessage.visibleInConversation = conversation;
    
    NSUUID *nonce = [NSUUID createUUID];
    textMessage.nonce = nonce;
    
    NSDictionary *data = @{
                           @"content" : self.name,
                           @"nonce" : nonce.transportString
                           };
    
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMTextMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertEqualObjects(sut, textMessage);
    
    __block NSInteger count = 0;
    [ZMTextMessage enumerateObjectsInContext:self.uiMOC withBlock:^(ZMManagedObject *obj, BOOL *stop) {
        NOT_USED(obj);
        NOT_USED(stop);
        ++count;
    }];
    
    XCTAssertEqual(count, 1);
}

- (void)testThatTheServerTimestampForAnExistingMessageIsUpdatedFromUpdatedEvent
{
    
    NSDate *originalDate = [NSDate dateWithTimeIntervalSinceNow:-10000];
    NSDate *middleDate = [NSDate dateWithTimeIntervalSinceNow:10];
    NSDate *finalDate = [NSDate dateWithTimeIntervalSinceNow:100];
    
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    ZMTextMessage *textMessage = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    textMessage.visibleInConversation = conversation;
    textMessage.serverTimestamp = originalDate;
    
    NSUUID *nonce = [NSUUID createUUID];
    textMessage.nonce = nonce;
    
    NSDictionary *data = @{
                           @"content" : self.name,
                           @"nonce" : nonce.transportString
                           };
    
    NSMutableDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    payload[@"time"] = middleDate.transportString;
    
    // when
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    __block ZMTextMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertEqual(sut, textMessage);
    XCTAssertEqualWithAccuracy(sut.serverTimestamp.timeIntervalSinceReferenceDate, middleDate.timeIntervalSinceReferenceDate, 0.1);
    
    // when
    payload[@"time"] = finalDate.transportString;
    event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertEqualWithAccuracy(sut.serverTimestamp.timeIntervalSinceReferenceDate, finalDate.timeIntervalSinceReferenceDate, 0.01);
}


- (void)testThatTheEventIDForAnExistingMessageIsUpdatedFromUpdatedEvent
{
    ZMEventID *originalEventID = [ZMEventID eventIDWithMajor:10 minor:2000];
    ZMEventID *newEventID = [ZMEventID eventIDWithMajor:20 minor:1000];
    ZMEventID *finalEventID = [ZMEventID eventIDWithMajor:30 minor:1000];
    
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    ZMTextMessage *textMessage = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    textMessage.visibleInConversation = conversation;
    textMessage.eventID = originalEventID;
    
    NSUUID *nonce = [NSUUID createUUID];
    textMessage.nonce = nonce;
    
    NSDictionary *data = @{
                           @"content" : self.name,
                           @"nonce" : nonce.transportString
                           };
    
    NSMutableDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    payload[@"id"] = newEventID.transportString;
    
    // when
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    
    __block ZMTextMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertEqualObjects(sut.eventID, newEventID);
    
    // when
    payload[@"id"] = finalEventID.transportString;
    event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertEqualObjects(sut.eventID, finalEventID);
}


- (void)testThatItReturnsNilIfTheNonceIsMissing
{

    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSDictionary *data = @{
                           @"content" : self.name,
                           };
    
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMTextMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        [self performIgnoringZMLogError:^{
            sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
        }];
    }];
    
    // then
    XCTAssertNil(sut);

}

- (void)testThatItReturnsNilIfTheConversationIsMissing
{
    
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSDictionary *data = @{
                           @"content" : self.name,
                           @"nonce" : [NSUUID createUUID].transportString
                           };
    
    NSMutableDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAdd data:data];
    [payload removeObjectForKey:@"conversation"];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMTextMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        [self performIgnoringZMLogError:^{
            sut = [ZMTextMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
        }];
    }];

    // then
    XCTAssertNil(sut);
    
}

@end



@implementation ZMMessageTests (CreateImageMessageFromUpdateEvent)

- (NSMutableDictionary *)previewImageDataWithCorrelationID:(NSUUID *)correlationID
{
    NSMutableDictionary *imageData = [@{
                                        @"content_length" : @795,
                                        @"content_type" : @"image/jpeg",
                                        @"data" : @"/9j/4AAQSkZJRgABAQAAAQABAAD/4QBARXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAAqACAAQAAAABAAAAJqADAAQAAAABAAAAHQAAAAD/2wBDACAWGBwYFCAcGhwkIiAmMFA0MCwsMGJGSjpQdGZ6eHJmcG6AkLicgIiuim5woNqirr7EztDOfJri8uDI8LjKzsb/2wBDASIkJDAqMF40NF7GhHCExsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsbGxsb/wgARCAAdACYDASIAAhEBAxEB/8QAGAAAAwEBAAAAAAAAAAAAAAAAAAEDAgT/xAAXAQEBAQEAAAAAAAAAAAAAAAABAAID/9oADAMBAAIQAxAAAAG5Q3iGuStWGJZZXPfE7MqkxP/EAB0QAAICAwADAAAAAAAAAAAAAAABAhEDEBITICL/2gAIAQEAAQUC0nZRRWr4yLIn6Tg/JDEmJUujol9CdLtn/8QAFhEBAQEAAAAAAAAAAAAAAAAAEQAQ/9oACAEDAQE/ASMML//EABgRAAMBAQAAAAAAAAAAAAAAAAABEhEQ/9oACAECAQE/AdN5SKRZ/8QAGhAAAgIDAAAAAAAAAAAAAAAAECABAhEhUf/aAAgBAQAGPwIaWyzheH//xAAdEAACAgMAAwAAAAAAAAAAAAAAAREhMUFhECBx/9oACAEBAAE/IYIEO01rPoIQ3aV2PYdN+YHkbWIW5eikmT5HybsuD4sj4H//2gAMAwEAAgADAAAAEIvvgPQf/8QAFhEBAQEAAAAAAAAAAAAAAAAAABEB/9oACAEDAQE/EDWYpNi3/8QAGBEAAgMAAAAAAAAAAAAAAAAAABEBEFH/2gAIAQIBAT8QEbHYIf/EACAQAQADAAIBBQEAAAAAAAAAAAEAESExQVFhcYGRwdH/2gAIAQEAAT8Qhi6QtDxPVKQ8oyE6mE89wRrKOyVRTNjZi85kLW0/xlTPEKVS6youp29zp+4o4fuC4FDLXPufLGFBXqnOVDcEf//Z",
                                        @"id" : @"420936ed-e795-51e3-8829-9e07c4c0a23e",
                                        @"info" : [@{
                                                     @"correlation_id" : correlationID.transportString,
                                                     @"height" : @29,
                                                     @"nonce" : [NSUUID createUUID].transportString,
                                                     @"original_height" : @768,
                                                     @"original_width" : @1024,
                                                     @"public" : @NO,
                                                     @"tag" : @"preview",
                                                     @"width" : @38
                                                     } mutableCopy]
                                        } mutableCopy];
    return imageData;
}

- (NSMutableDictionary *)payloadForPreviewImageMessageInConversation:conversation correlationID:(NSUUID *)correlationID time:(NSDate *)time
{
    return [self payloadForMessageInConversation:conversation
                                            type:EventConversationAddAsset
                                            data:[self previewImageDataWithCorrelationID:correlationID]
                                            time:time];
}

- (NSMutableDictionary *)payloadForPreviewImageMessageInConversation:conversation correlationID:(NSUUID *)correlationID
{
    return [self payloadForPreviewImageMessageInConversation:conversation correlationID:correlationID time:nil];
}

- (NSMutableDictionary *)mediumImageDataWithCorrelationId:(NSUUID *)correlationID
{
    NSMutableDictionary *imageData = [@{
                                        @"content_length" : @795,
                                        @"content_type" : @"image/jpeg",
                                        @"id" : @"420936ed-e795-51e3-8829-9e07c4c0a23e",
                                        @"info" : [@{
                                                     @"correlation_id" : correlationID.transportString,
                                                     @"height" : @29,
                                                     @"nonce" : @"49faac5e-7bd4-a209-eaa1-f386b6df96aa",
                                                     @"original_height" : @768,
                                                     @"original_width" : @1024,
                                                     @"public" : @NO,
                                                     @"tag" : @"medium",
                                                     @"width" : @38
                                                     } mutableCopy]
                                        } mutableCopy];
    return imageData;
}

- (NSMutableDictionary *)payloadForMediumImageMessageInConversation:conversation correlationID:(NSUUID *)correlationID time:(NSDate *)time
{
    return [self payloadForMessageInConversation:conversation
                                            type:EventConversationAddAsset
                                            data:[self mediumImageDataWithCorrelationId:correlationID]
                                            time:time];
}

- (NSMutableDictionary *)payloadForMediumImageMessageInConversation:conversation correlationID:(NSUUID *)correlationID
{
    return [self payloadForMediumImageMessageInConversation:conversation correlationID:correlationID time:nil];
}

- (void)testThatItCreatesPreviewImageMessagesFromUpdateEvent
{
    
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *correlationID = [NSUUID createUUID];
    NSDictionary *payload = [self payloadForPreviewImageMessageInConversation:conversation correlationID:correlationID];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMImageMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
        
    // then
    XCTAssertNotNil(sut);
    XCTAssertEqualObjects(sut.eventID, [ZMEventID eventIDWithString:payload[@"id"]]);
    XCTAssertEqualObjects(sut.conversation, conversation);
    XCTAssertEqualObjects(sut.sender.remoteIdentifier.transportString, payload[@"from"]);
    XCTAssertEqualObjects(sut.serverTimestamp.transportString, payload[@"time"]);
    
    XCTAssertEqualObjects(sut.nonce, correlationID);
    XCTAssertEqualObjects(sut.previewData, [[NSData alloc] initWithBase64EncodedString:payload[@"data"][@"data"] options:0]);
    XCTAssertNil(sut.mediumData);
    XCTAssertNil(sut.mediumRemoteIdentifier);
    XCTAssertEqualObjects(@(sut.originalSize.width), payload[@"data"][@"info"][@"original_width"]);
    XCTAssertEqualObjects(@(sut.originalSize.height), payload[@"data"][@"info"][@"original_height"]);
    XCTAssertTrue(sut.isPlainText);
    XCTAssertFalse(sut.isEncrypted);
}

- (void)testThatItDoesNotCrashWhenThePreviewImageIsMissingInAnUpdateEvent
{
    
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *correlationID = [NSUUID createUUID];
    NSMutableDictionary *payload = [[self payloadForPreviewImageMessageInConversation:conversation correlationID:correlationID] mutableCopy];
    NSMutableDictionary *data = [payload[@"data"] mutableCopy];
    payload[@"data"] = data;
    [data removeObjectForKey:@"data"];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMImageMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        [self performIgnoringZMLogError:^{
            sut = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
        }];
    }];
    
    // then
    XCTAssertNotNil(sut);
    XCTAssertEqualObjects(sut.eventID, [ZMEventID eventIDWithString:payload[@"id"]]);
    XCTAssertEqualObjects(sut.conversation, conversation);
    XCTAssertEqualObjects(sut.sender.remoteIdentifier.transportString, payload[@"from"]);
    XCTAssertEqualObjects(sut.serverTimestamp.transportString, payload[@"time"]);
    
    XCTAssertEqualObjects(sut.nonce, correlationID);
    XCTAssertNil(sut.previewData);
    XCTAssertNil(sut.mediumData);
    XCTAssertNil(sut.mediumRemoteIdentifier);
    XCTAssertEqualObjects(@(sut.originalSize.width), payload[@"data"][@"info"][@"original_width"]);
    XCTAssertEqualObjects(@(sut.originalSize.height), payload[@"data"][@"info"][@"original_height"]);
}

- (void)testThatItCreatesMediumImageMessagesFromUpdateEvent
{
    
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *correlationID = [NSUUID createUUID];
    NSDictionary *payload = [self payloadForMediumImageMessageInConversation:conversation correlationID:correlationID];
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    __block ZMImageMessage *sut;
    [self performPretendingUiMocIsSyncMoc:^{
        sut = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertNotNil(sut);
    XCTAssertEqualObjects(sut.eventID, [ZMEventID eventIDWithString:payload[@"id"]]);
    XCTAssertEqualObjects(sut.conversation, conversation);
    XCTAssertEqualObjects(sut.sender.remoteIdentifier.transportString, payload[@"from"]);
    XCTAssertEqualObjects(sut.serverTimestamp.transportString, payload[@"time"]);
    
    XCTAssertEqualObjects(sut.nonce, correlationID);
    XCTAssertNil(sut.previewData);
    XCTAssertNil(sut.mediumData);
    XCTAssertEqualObjects(sut.mediumRemoteIdentifier.transportString, payload[@"data"][@"id"]);
    XCTAssertEqualObjects(@(sut.originalSize.width), payload[@"data"][@"info"][@"original_width"]);
    XCTAssertEqualObjects(@(sut.originalSize.height), payload[@"data"][@"info"][@"original_height"]);
    XCTAssertFalse(sut.isEncrypted);
    XCTAssertTrue(sut.isPlainText);
}

- (void)testThatImageMessageIsUpdatedCorrectlyWhenItGetsPreviewBeforeMedium;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *correlationID = [NSUUID createUUID];
    NSDate *previewTime = [NSDate date];
    NSDate *mediumTime = [NSDate dateWithTimeInterval:100 sinceDate:previewTime];
    NSDictionary *previewPayload = [self payloadForPreviewImageMessageInConversation:conversation correlationID:correlationID time:previewTime];
    NSDictionary *mediumPayload = [self payloadForMediumImageMessageInConversation:conversation correlationID:correlationID time:mediumTime];
    
    ZMUpdateEvent *mediumEvent = [ZMUpdateEvent eventFromEventStreamPayload:mediumPayload uuid:nil];
    ZMUpdateEvent *previewEvent = [ZMUpdateEvent eventFromEventStreamPayload:previewPayload uuid:nil];
    
    // when
    __block ZMImageMessage *mediumMessage;
    __block ZMImageMessage *previewMessage;
    [self performPretendingUiMocIsSyncMoc:^{
        previewMessage = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:previewEvent inManagedObjectContext:self.uiMOC prefetchResult:nil];
        mediumMessage = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:mediumEvent inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertEqual(previewMessage, mediumMessage);

    XCTAssertEqualObjects(previewMessage.nonce, correlationID);
    XCTAssertEqualObjects(previewMessage.previewData, [[NSData alloc] initWithBase64EncodedString:previewPayload[@"data"][@"data"] options:0]);
    XCTAssertEqualObjects(previewMessage.mediumRemoteIdentifier.transportString, mediumPayload[@"data"][@"id"]);
    
    // we always store earliest timestamp for image messages
    XCTAssertEqualObjects(mediumMessage.serverTimestamp.transportString, previewPayload[@"time"]);
}

- (void)testThatImageMessageIsUpdatedCorrectlyWhenItGetsMediumBeforePreview;
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *correlationID = [NSUUID createUUID];
    NSDate *mediumTime = [NSDate date];
    NSDate *previewTime = [NSDate dateWithTimeInterval:100 sinceDate:mediumTime];
    NSDictionary *previewPayload = [self payloadForPreviewImageMessageInConversation:conversation correlationID:correlationID time:previewTime];
    NSDictionary *mediumPayload = [self payloadForMediumImageMessageInConversation:conversation correlationID:correlationID time:mediumTime];
    
    ZMUpdateEvent *mediumEvent = [ZMUpdateEvent eventFromEventStreamPayload:mediumPayload uuid:nil];
    ZMUpdateEvent *previewEvent = [ZMUpdateEvent eventFromEventStreamPayload:previewPayload uuid:nil];
    
    // when
    __block ZMImageMessage *mediumMessage;
    __block ZMImageMessage *previewMessage;
    [self performPretendingUiMocIsSyncMoc:^{
        mediumMessage = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:mediumEvent inManagedObjectContext:self.uiMOC prefetchResult:nil];
        previewMessage = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:previewEvent inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertEqual(previewMessage, mediumMessage);
    
    XCTAssertEqualObjects(previewMessage.nonce, correlationID);
    XCTAssertEqualObjects(previewMessage.previewData, [[NSData alloc] initWithBase64EncodedString:previewPayload[@"data"][@"data"] options:0]);
    XCTAssertEqualObjects(previewMessage.mediumRemoteIdentifier.transportString, mediumPayload[@"data"][@"id"]);
    
    // we always store earliest timestamp for image messages
    XCTAssertEqualObjects(mediumMessage.serverTimestamp.transportString, mediumPayload[@"time"]);
}

- (void)testThatItReturnsNilForUnknownTag
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *correlationID = [NSUUID createUUID];
    NSMutableDictionary *payload = [self payloadForMediumImageMessageInConversation:conversation correlationID:correlationID];
    payload[@"data"][@"info"][@"tag"] = @"Bogus";
    
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    XCTAssertNotNil(event);
    
    // when
    ZMImageMessage *sut = [ZMImageMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    
    // then
    XCTAssertNil(sut);
}

- (void)testThatItSortsPendingAndNonPendingMessages
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMMessage *pendingMessage1 = [conversation appendMessageWithText:@"P1"];
    pendingMessage1.visibleInConversation = conversation;
    
    ZMTextMessage *lastServerMessage = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    lastServerMessage.text = @"A3";
    lastServerMessage.visibleInConversation = conversation;
    lastServerMessage.serverTimestamp = [NSDate dateWithTimeIntervalSince1970:10*1000];
    
    ZMTextMessage *firstServerMessage = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    firstServerMessage.text = @"A1";
    firstServerMessage.visibleInConversation = conversation;
    firstServerMessage.serverTimestamp = [NSDate dateWithTimeIntervalSince1970:1*1000];
    
    ZMTextMessage *middleServerMessage = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    middleServerMessage.text = @"A2";
    middleServerMessage.visibleInConversation = conversation;
    middleServerMessage.serverTimestamp = [NSDate dateWithTimeIntervalSince1970:5*1000];
    
    ZMMessage *pendingMessage2 = [conversation appendMessageWithText:@"P2"];
    pendingMessage2.visibleInConversation = conversation;

    ZMMessage *pendingMessage3 = [conversation appendMessageWithText:@"P3"];
    pendingMessage2.visibleInConversation = conversation;
    
    NSArray *expectedOrder = @[firstServerMessage, middleServerMessage, lastServerMessage, pendingMessage1, pendingMessage2, pendingMessage3];
    
    NSArray *allMessages = @[pendingMessage1, lastServerMessage, firstServerMessage, middleServerMessage, pendingMessage2, pendingMessage3];
    
    // when
    NSArray *sorted = [allMessages sortedArrayUsingDescriptors:[ZMMessage defaultSortDescriptors]];
    
    // then
    XCTAssertEqualObjects(expectedOrder, sorted);
}

- (void)testThatTheServerTimestampIsSetByDefault
{
    // given
    ZMTextMessage *msg = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertNotNil(msg.serverTimestamp);
    AssertDateIsRecent(msg.serverTimestamp);
}

@end



@implementation ZMMessageTests (KnockMessage)

- (void)testThatItCreatesAKnockMessageFromAnUpdateEvent
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *data = @{@"nonce" : nonce.transportString};
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationKnock data:data time:[NSDate dateWithTimeIntervalSinceReferenceDate:450000000]];
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    
    // when
    __block ZMKnockMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [ZMKnockMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertNotNil(message);
    XCTAssertEqualObjects(message.eventID, [ZMEventID eventIDWithString:payload[@"id"]]);
    XCTAssertEqualObjects(message.conversation, conversation);
    XCTAssertEqualObjects(message.sender.remoteIdentifier.transportString, payload[@"from"]);
    XCTAssertEqualObjects(message.serverTimestamp.transportString, payload[@"time"]);
    XCTAssertFalse(message.isEncrypted);
    XCTAssertTrue(message.isPlainText);
    XCTAssertEqualObjects(message.nonce, nonce);
}

- (void)testThatItCreatesOtrKnockMessageFromAnUpdateEvent
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    
    NSString *senderClientID = [NSString createAlphanumericalString];
    NSUUID *nonce = [NSUUID createUUID];
    ZMGenericMessage *knockMessage = [ZMGenericMessage knockWithNonce:nonce.transportString];

    NSDictionary *data = @{ @"sender" : senderClientID, @"text" : knockMessage.data.base64String };
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationAddOTRMessage data:data time:[NSDate dateWithTimeIntervalSinceReferenceDate:450000000]];
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    
    // when
    __block ZMClientMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [ZMClientMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertNotNil(message);
    XCTAssertEqualObjects(message.eventID, [ZMEventID eventIDWithString:payload[@"id"]]);
    XCTAssertEqualObjects(message.conversation, conversation);
    XCTAssertEqualObjects(message.sender.remoteIdentifier.transportString, payload[@"from"]);
    XCTAssertEqualObjects(message.serverTimestamp.transportString, payload[@"time"]);
    XCTAssertEqualObjects(message.senderClientID, senderClientID);
    XCTAssertTrue(message.isEncrypted);
    XCTAssertFalse(message.isPlainText);
    XCTAssertEqualObjects(message.nonce, nonce);
}

- (void)testThatItSetsLastReadServerTimestampOfItsConversationToServerTimestamp_ForSelfUserAsSender
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.lastReadServerTimeStamp = [NSDate date];
    
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *data = @{
                           @"nonce" : nonce.transportString,
                           };
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationKnock data:data time:[conversation.lastReadServerTimeStamp dateByAddingTimeInterval:20] fromUser:[ZMUser selfUserInContext:self.uiMOC]];
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    
    // when
    __block ZMKnockMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [ZMKnockMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertNotNil(message);
    XCTAssertEqualObjects(message.conversation, conversation);
    XCTAssertEqualObjects(conversation.lastReadServerTimeStamp, message.serverTimestamp);
}

- (void)testThatIt_DoesNot_SetLastReadServerTimestampOfItsConversationToServerTimestamp_ForOtherUserAsSender
{
    // given
    NSDate *oldDate = [NSDate date];
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.lastReadServerTimeStamp = oldDate;
    
    NSUUID *nonce = [NSUUID createUUID];
    NSDictionary *data = @{
                           @"nonce" : nonce.transportString,
                           };
    NSDictionary *payload = [self payloadForMessageInConversation:conversation type:EventConversationKnock data:data time:[conversation.lastReadServerTimeStamp dateByAddingTimeInterval:20]];
    ZMUpdateEvent *event = [ZMUpdateEvent eventFromEventStreamPayload:payload uuid:nil];
    
    // when
    __block ZMKnockMessage *message;
    [self performPretendingUiMocIsSyncMoc:^{
        message = [ZMKnockMessage createOrUpdateMessageFromUpdateEvent:event inManagedObjectContext:self.uiMOC prefetchResult:nil];
    }];
    
    // then
    XCTAssertNotNil(message);
    XCTAssertEqualObjects(message.conversation, conversation);
    XCTAssertNotEqualObjects(conversation.lastReadServerTimeStamp, message.serverTimestamp);
    XCTAssertEqualObjects(conversation.lastReadServerTimeStamp, oldDate);
}


- (void)testThatAKnockMessageHasKnockMessageData
{
    // given
    ZMKnockMessage *message = [ZMKnockMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // then
    XCTAssertNil(message.textMessageData.messageText);
    XCTAssertNil(message.systemMessageData);
    XCTAssertNil(message.imageMessageData);
    XCTAssertNotNil(message.knockMessageData);
}

- (void)testThatAClientMessageHasKnockMessageData
{
    // given
    ZMGenericMessage *knock = [ZMGenericMessage knockWithNonce:[NSUUID createUUID].transportString];
    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    [message addData:knock.data];
    
    // then
    XCTAssertNil(message.textMessageData.messageText);
    XCTAssertNil(message.systemMessageData);
    XCTAssertNil(message.imageMessageData);
    XCTAssertNotNil(message.knockMessageData);
}

@end

@implementation ZMMessageTests (Deletion)

/// Returns whether the message was deleted
- (BOOL)checkThatAMessageIsRemoved:(ZMMessage *(^)())messageCreationBlock {
    // given
    ZMEventID *convEventID = [self createEventID];
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.lastReadEventID = convEventID;
    
    NSUUID *nonce = [NSUUID createUUID];
    ZMMessage *testMessage = messageCreationBlock();
    testMessage.nonce = nonce;
    testMessage.visibleInConversation = conversation;
    
    //sanity check
    XCTAssertNotNil(conversation);
    XCTAssertNotNil(testMessage);
    [self.uiMOC saveOrRollback];
    
    //when
    [self performPretendingUiMocIsSyncMoc:^{
        [testMessage removeMessage];
    }];
    [self.uiMOC saveOrRollback];
    
    //then
    ZMMessage *fetchedMessage = [ZMMessage fetchMessageWithNonce:nonce forConversation:conversation inManagedObjectContext:self.uiMOC];
    return fetchedMessage == nil && conversation.messages.count == 0LU;
}

- (void)testThatATextMessageIsRemovedWhenAskForDeletion;
{
    // when
    BOOL removed = [self checkThatAMessageIsRemoved:^ZMMessage *{
        return [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    }];
    
    // then
    XCTAssertTrue(removed);
}

- (void)testThatAClientMessageIsRemovedWhenAskForDeletion;
{
    // when
    BOOL removed = [self checkThatAMessageIsRemoved:^ZMMessage *{
        return [ZMClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    }];
    
    // then
    XCTAssertTrue(removed);
}

- (void)testThatAnAssetClientMessageIsRemovedWhenAskForDeletion;
{
    // when
    BOOL removed = [self checkThatAMessageIsRemoved:^ZMMessage *{
        return [ZMAssetClientMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    }];
    
    // then
    XCTAssertTrue(removed);
}


- (void)testThatAMessageIsRemovedWhenAskForDeletionWithMsgDeleted;
{
    // given
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    ZMEventID *convEventID = [self createEventID];
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    conversation.remoteIdentifier = [NSUUID createUUID];
    conversation.lastReadEventID = convEventID;
    
    NSUUID *nonce = [NSUUID createUUID];
    ZMTextMessage *textMessage = [ZMTextMessage insertNewObjectInManagedObjectContext:self.uiMOC];
    textMessage.nonce = nonce;
    textMessage.visibleInConversation = conversation;
    
    ZMMsgDeletedBuilder *builder = [ZMMsgDeleted builder];
    builder.conversationId = conversation.remoteIdentifier.transportString;
    builder.messageId = nonce.transportString;
    ZMMsgDeleted *msgDeleted = [builder build];
    
    //sanity check
    XCTAssertNotNil(conversation);
    XCTAssertNotNil(textMessage);
    [self.uiMOC saveOrRollback];
    
    //when
    [self performPretendingUiMocIsSyncMoc:^{
        [ZMMessage removeMessageWithRemotelyDeletedMessage:msgDeleted fromUser:selfUser inManagedObjectContext:self.uiMOC];
    }];
    [self.uiMOC saveOrRollback];
    
    //then
    textMessage = (ZMTextMessage *)[ZMMessage fetchMessageWithNonce:nonce forConversation:conversation inManagedObjectContext:self.uiMOC];
    XCTAssertNil(textMessage);
    XCTAssertEqual(conversation.messages.count, 0LU);
}

@end