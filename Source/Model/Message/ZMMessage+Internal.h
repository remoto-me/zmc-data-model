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


@import zimages;
@import ZMProtos;
@import ZMTransport;

#import "ZMMessage.h"
#import "ZMManagedObject+Internal.h"
#import "ZMFetchRequestBatch.h"


@class ZMEventID;
@class ZMUser;
@class ZMConversation;
@class ZMUpdateEvent;

@protocol UserClientType;

extern NSString * const ZMMessageEventIDDataKey;
extern NSString * const ZMMessageIsEncryptedKey;
extern NSString * const ZMMessageIsPlainTextKey;
extern NSString * const ZMMessageIsExpiredKey;
extern NSString * const ZMMessageMissingRecipientsKey;
extern NSString * const ZMMessageImageTypeKey;
extern NSString * const ZMMessageIsAnimatedGifKey;
extern NSString * const ZMMessageMediumRemoteIdentifierDataKey;
extern NSString * const ZMMessageMediumRemoteIdentifierKey;
extern NSString * const ZMMessageOriginalDataProcessedKey;
extern NSString * const ZMMessageOriginalSizeDataKey;
extern NSString * const ZMMessageOriginalSizeKey;
extern NSString * const ZMMessageConversationKey;
extern NSString * const ZMMessageEventIDKey;
extern NSString * const ZMMessageExpirationDateKey;
extern NSString * const ZMMessageNameKey;
extern NSString * const ZMMessageNeedsToBeUpdatedFromBackendKey;
extern NSString * const ZMMessageNonceDataKey;
extern NSString * const ZMMessageSenderKey;
extern NSString * const ZMMessageSystemMessageTypeKey;
extern NSString * const ZMMessageTextKey;
extern NSString * const ZMMessageUserIDsKey;
extern NSString * const ZMMessageUsersKey;
extern NSString * const ZMMessageClientsKey;
extern NSString * const ZMMessageHiddenInConversationKey;

@interface ZMMessage : ZMManagedObject


// Use these for sorting:
+ (NSArray *)defaultSortDescriptors;
- (NSComparisonResult)compare:(ZMMessage *)other;
- (void)updateWithPostPayload:(NSDictionary *)payload updatedKeys:(__unused NSSet *)updatedKeys;
- (void)resend;
- (BOOL)shouldGenerateUnreadCount;

- (void)removeMessage;
+ (void)removeMessageWithRemotelyDeletedMessage:(ZMMsgDeleted *)deletedMessage fromUser:(ZMUser *)user inManagedObjectContext:(NSManagedObjectContext *)moc;
@end



@interface ZMTextMessage : ZMMessage <ZMTextMessageData>

@property (nonatomic, readonly, copy) NSString *text;

@end



@interface ZMImageMessage : ZMMessage <ZMImageMessageData>

@property (nonatomic, readonly) BOOL mediumDataLoaded;
@property (nonatomic, readonly) BOOL originalDataProcessed;
@property (nonatomic, readonly) NSData *mediumData; ///< N.B.: Will go away from public header
@property (nonatomic, readonly) NSData *imageData; ///< This will either returns the mediumData or the original image data. Usefull only for newly inserted messages.
@property (nonatomic, readonly) NSString *imageDataIdentifier; /// This can be used as a cache key for @c -imageData

@property (nonatomic, readonly) NSData *previewData;
@property (nonatomic, readonly) NSString *imagePreviewDataIdentifier; /// This can be used as a cache key for @c -previewData
@property (nonatomic, readonly) BOOL isAnimatedGIF; // If it is GIF and has more than 1 frame
@property (nonatomic, readonly) NSString *imageType; // UTI e.g. kUTTypeGIF

@property (nonatomic, readonly) CGSize originalSize;

@end



@interface ZMKnockMessage : ZMMessage <ZMKnockMessageData>

@end



@interface ZMSystemMessage : ZMMessage <ZMSystemMessageData>

@property (nonatomic) ZMSystemMessageType systemMessageType;
@property (nonatomic) NSSet<ZMUser *> *users;
@property (nonatomic) NSSet <id<UserClientType>>*clients;
@property (nonatomic) NSSet<ZMUser *> *addedUsers; // Only filled for ZMSystemMessageTypePotentialGap
@property (nonatomic) NSSet<ZMUser *> *removedUsers; // Only filled for ZMSystemMessageTypePotentialGap
@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL needsUpdatingUsers;

+ (ZMSystemMessage *)fetchLatestPotentialGapSystemMessageInConversation:(ZMConversation *)conversation;
+ (ZMSystemMessage *)fetchStartedUsingOnThisDeviceMessageForConversation:(ZMConversation *)conversation;
- (void)updateNeedsUpdatingUsersIfNeeded;

@end



@interface ZMMessage ()

@property (nonatomic) NSString *senderClientID;
@property (nonatomic) ZMEventID *eventID;
@property (nonatomic) NSUUID *nonce;

@property (nonatomic, readonly) BOOL isUnreadMessage;

@property (nonatomic, readonly) BOOL isExpired;
@property (nonatomic, readonly) NSDate *expirationDate;
- (void)setExpirationDate;
- (void)removeExpirationDate;
- (void)markAsDelivered;

- (void)expire;

+ (instancetype)fetchMessageWithNonce:(NSUUID *)nonce
                      forConversation:(ZMConversation *)conversation
               inManagedObjectContext:(NSManagedObjectContext *)moc;

+ (instancetype)fetchMessageWithNonce:(NSUUID *)nonce
                      forConversation:(ZMConversation *)conversation
               inManagedObjectContext:(NSManagedObjectContext *)moc
                       prefetchResult:(ZMFetchRequestBatchResult *)prefetchResult;

- (NSString *)shortDebugDescription;

- (void)updateWithPostPayload:(NSDictionary *)payload updatedKeys:(NSSet *)updatedKeys;
+ (BOOL)doesEventTypeGenerateMessage:(ZMUpdateEventType)type;

/// Returns a predicate that matches messages that might expire if they are not sent in time
+ (NSPredicate *)predicateForMessagesThatWillExpire;

/// Adds the event ID of the update event to the list of downloaded event IDs in the conversation
+ (void)addEventToDownloadedEvents:(ZMUpdateEvent *)event inConversation:(ZMConversation *)conversation;

+ (void)setDefaultExpirationTime:(NSTimeInterval)defaultExpiration;
+ (NSTimeInterval)defaultExpirationTime;
+ (void)resetDefaultExpirationTime;

+ (ZMConversation *)conversationForUpdateEvent:(ZMUpdateEvent *)event inContext:(NSManagedObjectContext *)moc prefetchResult:(ZMFetchRequestBatchResult *)prefetchResult;

/// Returns the message represented in this update event
/// @param prefetchResult Contains a mapping from message nonce to message and `remoteIdentifier` to `ZMConversation`,
/// which should be used to avoid premature fetchRequests. If the class needs messages or conversations to be prefetched
/// and passed into this method it should conform to `ZMObjectStrategy` and return them in
/// `-messageNoncesToPrefetchToProcessEvents:` or `-conversationRemoteIdentifiersToPrefetchToProcessEvents`
+ (instancetype)createOrUpdateMessageFromUpdateEvent:(ZMUpdateEvent *)updateEvent
                              inManagedObjectContext:(NSManagedObjectContext *)moc
                                      prefetchResult:(ZMFetchRequestBatchResult *)prefetchResult;

- (void)updateWithUpdateEvent:(ZMUpdateEvent *)updateEvent forConversation:(ZMConversation *)conversation messageWasAlreadyReceived:(BOOL)wasDelivered;

/// Returns whether the data represents animated GIF
+ (BOOL)isDataAnimatedGIF:(NSData *)data;

/// Predicate to select messages that are part of a conversation
+ (NSPredicate *)predicateForMessageInConversation:(ZMConversation *)conversation withNonces:(NSSet <NSUUID *>*)nonces;

@end



@interface ZMTextMessage (Internal)

@property (nonatomic, copy) NSString *text;

+ (instancetype)createOrUpdateMessageFromUpdateEvent:(ZMUpdateEvent *)updateEvent
                               decodedGenericMessage:(ZMGenericMessage *)genericMessage
                              inManagedObjectContext:(NSManagedObjectContext *)moc;

@end



extern NSString * const ZMImageMessagePreviewNeedsToBeUploadedKey;
extern NSString * const ZMImageMessageMediumNeedsToBeUploadedKey;
extern NSString * const ZMMessageServerTimestampKey;

@interface ZMImageMessage (Internal) <ZMImageOwner>

@property (nonatomic) BOOL mediumDataLoaded;
@property (nonatomic) BOOL originalDataProcessed;
@property (nonatomic) NSUUID *mediumRemoteIdentifier;
@property (nonatomic) NSData *mediumData;
@property (nonatomic) NSData *previewData;
@property (nonatomic) CGSize originalSize;
@property (nonatomic) NSData *originalImageData;


@end



@interface ZMKnockMessage (Internal)

@end


@interface ZMSystemMessage (Internal)

+ (BOOL)doesEventTypeGenerateSystemMessage:(ZMUpdateEventType)type;
+ (instancetype)createOrUpdateMessageFromUpdateEvent:(ZMUpdateEvent *)updateEvent inManagedObjectContext:(NSManagedObjectContext *)moc;
+ (NSPredicate *)predicateForSystemMessagesInsertedLocally;

@end

