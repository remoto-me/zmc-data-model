
//
//  ZMConversation.m
//  zmessaging-cocoa
//
//  Created by Daniel Eggert on 08/05/14.
//  Copyright (c) 2014 Zeta Project Gmbh. All rights reserved.
//

@import Foundation;
@import zimages;
@import ZMUtilities;
@import ZMTransport;
@import Cryptobox;
@import MobileCoreServices;

#import "ZMManagedObject+Internal.h"
#import "ZMManagedObjectContextProvider.h"
#import "ZMConversation+Internal.h"
#import "ZMConversation+Timestamps.h"
#import "ZMConversation+UnreadCount.h"
#import "ZMConversation+OTR.h"
#import "ZMVoiceChannel.h"

#import "ZMUser+Internal.h"

#import "ZMMessage+Internal.h"
#import "ZMClientMessage.h"

#import "NSManagedObjectContext+zmessaging.h"
#import "ZMConnection+Internal.h"

#import "ZMConversationList+Internal.h"

#import "ZMConversationListDirectory.h"
#import <ZMCDataModel/ZMCDataModel-Swift.h>
#import "NSPredicate+ZMSearch.h"

NSString *const ZMConversationArchivedEventIDDataKey = @"archivedEventID_data";
NSString *const ZMConversationArchivedEventIDKey = @"archivedEventID";
NSString *const ZMConversationConnectionKey = @"connection";
NSString *const ZMConversationHasUnreadMissedCallKey = @"hasUnreadMissedCall";
NSString *const ZMConversationHasUnreadUnsentMessageKey = @"hasUnreadUnsentMessage";
NSString *const ZMConversationIsArchivedKey = @"internalIsArchived";
NSString *const ZMConversationIsSelfAnActiveMemberKey = @"isSelfAnActiveMember";
NSString *const ZMConversationIsSilencedKey = @"isSilenced";
NSString *const ZMConversationLastReadEventIDDataKey = @"lastReadEventID_data";
NSString *const ZMConversationMessagesKey = @"messages";
NSString *const ZMConversationOtherActiveParticipantsKey = @"otherActiveParticipants";
NSString *const ZMConversationHasUnreadKnock = @"hasUnreadKnock";
NSString *const ZMConversationUnsyncedActiveParticipantsKey = @"unsyncedActiveParticipants";
NSString *const ZMConversationUnsyncedInactiveParticipantsKey = @"unsyncedInactiveParticipants";
NSString *const ZMConversationUserDefinedNameKey = @"userDefinedName";
NSString *const ZMVisibleWindowLowerKey = @"ZMVisibleWindowLowerKey";
NSString *const ZMVisibleWindowUpperKey = @"ZMVisibleWindowUpperKey";
NSString *const ZMConversationCallParticipantsKey = @"callParticipants";
NSString *const ZMIsDimmedKey = @"zmIsDimmed";
NSString *const ZMNormalizedUserDefinedNameKey = @"normalizedUserDefinedName";
NSString *const ZMConversationListIndicatorKey = @"conversationListIndicator";
NSString *const ZMConversationConversationTypeKey = @"conversationType";
NSString *const ZMConversationClearedEventIDDataKey = @"clearedEventID_data";
NSString *const ZMConversationClearedEventIDKey = @"clearedEventID";
NSString *const ZMConversationLastServerTimeStampKey = @"lastServerTimeStamp";
NSString *const ZMConversationLastReadServerTimeStampKey = @"lastReadServerTimeStamp";
NSString *const ZMConversationClearedTimeStampKey = @"clearedTimeStamp";
NSString *const ZMConversationArchivedChangedTimeStampKey = @"archivedChangedTimestamp";
NSString *const ZMConversationSilencedChangedTimeStampKey = @"silencedChangedTimestamp";

NSString *const ZMNotificationConversationKey = @"ZMNotificationConversationKey";

NSString *const ZMConversationCallDeviceIsActiveKey = @"callDeviceIsActive";
NSString *const ZMConversationIsSendingVideoKey = @"isSendingVideo";
NSString *const ZMConversationIsIgnoringCallKey = @"isIgnoringCall";

NSString *const ZMConversationWillStartFetchingMessages = @"ZMConversationWillStartFetchingMessages";
NSString *const ZMConversationDidFinishFetchingMessages = @"ZMConversationDidFinishFetchingMessages";
NSString *const ZMConversationDidChangeVisibleWindowNotification = @"ZMConversationDidChangeVisibileWindow";
NSString *const ZMConversationVoiceChannelJoinFailedNotification = @"ZMConversationVoiceChannelJoinFailedNotification";
NSString *const ZMConversationRequestToLoadConversationEventsNotification = @"ZMConversationRequestToLoadConversationEvents";
NSString *const ZMConversationEstimatedUnreadCountKey = @"estimatedUnreadCount";
NSString *const ZMConversationRemoteIdentifierDataKey = @"remoteIdentifier_data";

NSString *const ZMConversationClearTypingNotificationName = @"ZMConversationClearTypingNotification";
NSString *const ZMConversationIsVerifiedNotificationName = @"ZMConversationIsVerifiedNotificationName";
NSString *const ZMConversationFailedToDecryptMessageNotificationName = @"ZMConversationFailedToDecryptMessageNotificationName";
NSString *const ZMConversationLastReadDidChangeNotificationName = @"ZMConversationLastReadDidChangeNotification";

static NSString *const CallStateNeedsToBeUpdatedFromBackendKey = @"callStateNeedsToBeUpdatedFromBackend";
static NSString *const ConnectedUserKey = @"connectedUser";
static NSString *const ConversationTypeKey = @"conversationType";
static NSString *const CreatorKey = @"creator";
static NSString *const DownloadedMessageIDsDataKey = @"downloadedMessageIDs_data";
static NSString *const DownloadedMessageIDsKey = @"downloadedMessageIDs";
static NSString *const DraftMessageTextKey = @"draftMessageText";
static NSString *const IsPendingConnectionConversationKey = @"isPendingConnectionConversation";
static NSString *const LastModifiedDateKey = @"lastModifiedDate";
static NSString *const LastEventIDDataKey = @"lastEventID_data";
static NSString *const LastEventIDKey = @"lastEventID";
static NSString *const LastReadEventIDKey = @"lastReadEventID";
static NSString *const LastReadMessageKey = @"lastReadMessage";
static NSString *const LastServerSyncedActiveParticipantsKey = @"lastServerSyncedActiveParticipants";
static NSString *const NeedsToBeUpdatedFromBackendKey = @"needsToBeUpdatedFromBackend";
static NSString *const OtherInactiveParticipantsKey = @"otherInactiveParticipants";
static NSString *const RemoteIdentifierKey = @"remoteIdentifier";
static NSString *const VoiceChannelKey = @"voiceChannel";
static NSString *const VoiceChannelStateKey = @"voiceChannelState";
static NSString *const CallDeviceIsActiveKey = @"callDeviceIsActive";
static NSString *const IsFlowActiveKey = @"isFlowActive";
static NSString *const HiddenMessagesKey = @"hiddenMessages";
static NSString *const SecurityLevelKey = @"securityLevel";


NSTimeInterval ZMConversationDefaultLastReadEventIDSaveDelay = 3.0;

const NSUInteger ZMConversationMaxEncodedTextMessageLength = 1500;
const NSUInteger ZMConversationMaxTextMessageLength = ZMConversationMaxEncodedTextMessageLength - 50; // Empirically we verified that the encoding adds 44 bytes
const NSUInteger ZMLeadingEventIDWindowBleed = 50;


@interface ZMConversation ()

@property (nonatomic) NSString *normalizedUserDefinedName;
@property (nonatomic) ZMConversationType conversationType;

@property (nonatomic) ZMEventID *tempMaximumLastReadEventID;
@property (nonatomic) NSDate *tempMaxLastReadServerTimeStamp;
@property (nonatomic) NSMutableOrderedSet *unreadTimeStamps;

@property (nonatomic) NSTimeInterval lastReadEventIDSaveDelay;
@property (nonatomic) int64_t lastReadEventIDUpdateCounter;
@property (nonatomic) ZMEventID *archivedEventID;
@property (nonatomic) BOOL internalIsArchived;

@property (nonatomic) ZMEventID *clearedEventID;
@property (nonatomic) NSDate *lastReadServerTimeStamp;
@property (nonatomic) NSDate *lastServerTimeStamp;
@property (nonatomic) NSDate *clearedTimeStamp;
@property (nonatomic) NSDate *archivedChangedTimestamp;
@property (nonatomic) NSDate *silencedChangedTimestamp;

@end

/// Declaration of properties implemented (automatically) by Core Data
@interface ZMConversation (CoreDataForward)

@property (nonatomic) NSDate *primitiveLastReadServerTimeStamp;
@property (nonatomic) NSDate *primitiveLastServerTimeStamp;
@property (nonatomic) NSUUID *primitiveRemoteIdentifier;
@property (nonatomic) NSData *remoteIdentifier_data;
@property (nonatomic) ZMVoiceChannel *primitiveVoiceChannel;

@property (nonatomic) ZMConversationSecurityLevel securityLevel;

@end


@implementation ZMConversation

@dynamic userDefinedName;
@dynamic messages;
@dynamic lastModifiedDate;
@dynamic creator;
@dynamic draftMessageText;
@dynamic normalizedUserDefinedName;
@dynamic conversationType;
@dynamic archivedEventID;
@dynamic clearedEventID;
@dynamic clearedTimeStamp;
@dynamic lastReadServerTimeStamp;
@dynamic lastServerTimeStamp;
@dynamic isSilenced;
@dynamic isMuted;
@dynamic isTrusted;
@dynamic hasUntrustedClients;
@dynamic internalIsArchived;
@dynamic archivedChangedTimestamp;
@dynamic silencedChangedTimestamp;

@synthesize tempMaximumLastReadEventID;
@synthesize tempMaxLastReadServerTimeStamp;
@synthesize lastReadEventIDSaveDelay;
@synthesize lastReadEventIDUpdateCounter;
@synthesize unreadTimeStamps;

- (BOOL)isArchived
{
    return self.internalIsArchived;
}

- (void)setIsArchived:(BOOL)isArchived
{
    self.internalIsArchived = isArchived;
    [self updateArchivedChangedTimeStampIfNeeded:self.lastServerTimeStamp andSync:YES];
}

- (NSUInteger)estimatedUnreadCount
{
    return (unsigned long)self.internalEstimatedUnreadCount;
}

+ (NSSet *)keyPathsForValuesAffectingEstimatedUnreadCount
{
    return [NSSet setWithObject: ZMConversationInternalEstimatedUnreadCountKey];
}


- (void)setIsSilenced:(BOOL)isSilenced
{
    [self willChangeValueForKey:ZMConversationIsSilencedKey];
    [self setPrimitiveValue:@(isSilenced) forKey:ZMConversationIsSilencedKey];
    [self didChangeValueForKey:ZMConversationIsSilencedKey];
    
    if (self.managedObjectContext.zm_isUserInterfaceContext) {
        [self updateSilencedChangedTimeStampIfNeeded:self.lastServerTimeStamp andSync:YES];
    }
}

+ (NSSet *)keyPathsForValuesAffectingIsSilenced
{
    return [NSSet setWithObject:ZMConversationIsSilencedKey];
}

+ (NSPredicate *)predicateForFilteringResults
{
    static NSPredicate *predicate;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"%K != %d && %K != %d",
                     ConversationTypeKey, ZMConversationTypeInvalid,
                     ConversationTypeKey, ZMConversationTypeSelf];
    });
    return predicate;
}

+ (NSFetchRequest *)sortedFetchRequest
{
    NSFetchRequest *request = [super sortedFetchRequest];

    if(request.predicate) {
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[request.predicate, self.predicateForFilteringResults]];
    }
    else {
        request.predicate = self.predicateForFilteringResults;
    }
    return request;
}

+ (NSPredicate *)predicateForObjectsThatNeedToBeInsertedUpstream;
{
    NSPredicate *superPredicate = [super predicateForObjectsThatNeedToBeInsertedUpstream];
    NSPredicate *onlyGoupPredicate = [NSPredicate predicateWithFormat:@"%K == %@", ConversationTypeKey, @(ZMConversationTypeGroup)];
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[superPredicate, onlyGoupPredicate]];
}

+ (NSPredicate *)predicateForObjectsThatNeedToBeUpdatedUpstream;
{
    NSPredicate *superPredicate = [super predicateForObjectsThatNeedToBeUpdatedUpstream];
    NSPredicate *onlyGoupPredicate = [NSPredicate predicateWithFormat:@"(%K != NULL) AND (%K != %@) AND (%K == 0)",
                                      [self remoteIdentifierDataKey],
                                      ConversationTypeKey, @(ZMConversationTypeInvalid),
                                      NeedsToBeUpdatedFromBackendKey];
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[superPredicate, onlyGoupPredicate]];
}

- (void)awakeFromFetch;
{
    [super awakeFromFetch];
    self.lastReadEventIDSaveDelay = ZMConversationDefaultLastReadEventIDSaveDelay;
    if (self.managedObjectContext.zm_isSyncContext) {
        // From the documentation: The managed object context’s change processing is explicitly disabled around this method so that you can use public setters to establish transient values and other caches without dirtying the object or its context.
        // Therefore we need to do a dispatch async  here in a performGroupedBlock to update the unread properties outside of awakeFromFetch
        [self.managedObjectContext performGroupedBlock:^{
            [self didUpdateConversationWhileFetchingUnreadMessages];
        }];
    }
}

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    self.lastReadEventIDSaveDelay = ZMConversationDefaultLastReadEventIDSaveDelay;
    if (self.managedObjectContext.zm_isSyncContext) {
        // From the documentation: You are typically discouraged from performing fetches within an implementation of awakeFromInsert. Although it is allowed, execution of the fetch request can trigger the sending of internal Core Data notifications which may have unwanted side-effects. Since we fetch the unread messages here, we should do a dispatch async
        [self.managedObjectContext performGroupedBlock:^{
            [self didUpdateConversationWhileFetchingUnreadMessages];
        }];
    }
}


-(NSOrderedSet *)activeParticipants
{
    NSMutableOrderedSet *activeParticipants = [NSMutableOrderedSet orderedSet];
    
    if (self.conversationType != ZMConversationTypeGroup) {
        [activeParticipants addObject:[ZMUser selfUserInContext:self.managedObjectContext]];
        if (self.connectedUser != nil) {
            [activeParticipants addObject:self.connectedUser];
        }
    }
    else if(self.isSelfAnActiveMember) {
        [activeParticipants addObject:[ZMUser selfUserInContext:self.managedObjectContext]];
        [activeParticipants unionOrderedSet:self.otherActiveParticipants];
    }
    else
    {
        [activeParticipants unionOrderedSet:self.otherActiveParticipants];
    }
   
    NSArray *sortedParticipants = [self sortedUsers:activeParticipants];
    return [NSOrderedSet orderedSetWithArray:sortedParticipants];
}

- (NSArray *)sortedUsers:(NSOrderedSet *)users
{
    NSSortDescriptor *nameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"normalizedName" ascending:YES];
    NSArray *sortedUser = [users sortedArrayUsingDescriptors:@[nameDescriptor]];
    
    return sortedUser;
}

+ (NSSet *)keyPathsForValuesAffectingActiveParticipants
{
    return [NSSet setWithObjects:ZMConversationOtherActiveParticipantsKey, ZMConversationIsSelfAnActiveMemberKey, nil];
}

-(NSOrderedSet *)inactiveParticipants
{
    if (self.conversationType != ZMConversationTypeGroup) {
        return [NSOrderedSet orderedSet];
    }
    if(self.isSelfAnActiveMember)
    {
        return self.otherInactiveParticipants;
    }
    else {
        NSMutableOrderedSet *otherInactive = [self.otherInactiveParticipants mutableCopy];
        [otherInactive addObject:[ZMUser selfUserInContext:self.managedObjectContext]];
        return otherInactive;
    }
}

+ (NSSet *)keyPathsForValuesAffectingInactiveParticipants
{
    return [NSSet setWithObjects:OtherInactiveParticipantsKey, ZMConversationIsSelfAnActiveMemberKey, nil];
}

- (NSOrderedSet *)allParticipants;
{
    NSMutableOrderedSet *result = [self.activeParticipants mutableCopy];
    [result unionOrderedSet:self.inactiveParticipants];
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingAllParticipants;
{
    return [NSSet setWithObjects:ZMConversationOtherActiveParticipantsKey, OtherInactiveParticipantsKey, ZMConversationIsSelfAnActiveMemberKey, nil];
}

- (ZMUser *)connectedUser
{
    if(self.conversationType == ZMConversationTypeOneOnOne || self.conversationType == ZMConversationTypeConnection) {
        return self.connection.to;
    }
    return nil;
}

+ (NSSet *)keyPathsForValuesAffectingConnectedUser
{
    return [NSSet setWithObject:ConversationTypeKey];
}


- (ZMConnectionStatus)relatedConnectionState
{
    if(self.connection != nil) {
        return self.connection.status;
    }
    return ZMConnectionStatusInvalid;
}

+ (NSSet *)keyPathsForValuesAffectingRelatedConnectionState
{
    return [NSSet setWithObject:@"connection"];
}

- (NSSet *)ignoredKeys;
{
    static NSSet *ignoredKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSSet *keys = [super ignoredKeys];
        NSString * const KeysIgnoredForTrackingModifications[] = {
            ZMConversationCallParticipantsKey,
            CallStateNeedsToBeUpdatedFromBackendKey,
            ZMConversationConnectionKey,
            ConversationTypeKey,
            CreatorKey,
            ZMConversationLastReadEventIDDataKey,
            DownloadedMessageIDsDataKey,
            DraftMessageTextKey,
            LastEventIDDataKey,
            LastModifiedDateKey,
            LastServerSyncedActiveParticipantsKey,
            ZMNormalizedUserDefinedNameKey,
            ZMConversationOtherActiveParticipantsKey,
            OtherInactiveParticipantsKey,
            VoiceChannelKey,
            ZMConversationArchivedEventIDKey,
            ZMConversationHasUnreadMissedCallKey,
            ZMConversationHasUnreadUnsentMessageKey,
            ZMConversationMessagesKey,
            HiddenMessagesKey,
            ZMConversationLastServerTimeStampKey,
            SecurityLevelKey,
            ZMConversationLastUnreadKnockDateKey,
            ZMConversationLastUnreadMissedCallDateKey,
            ZMConversationLastReadLocalTimestampKey,
            ZMConversationInternalEstimatedUnreadCountKey,
            ZMConversationIsArchivedKey,
            ZMConversationIsSilencedKey
        };
        
        NSSet *additionalKeys = [NSSet setWithObjects:KeysIgnoredForTrackingModifications count:(sizeof(KeysIgnoredForTrackingModifications) / sizeof(*KeysIgnoredForTrackingModifications))];
        ignoredKeys = [keys setByAddingObjectsFromSet:additionalKeys];
    });
    return ignoredKeys;
}

- (BOOL)isReadOnly
{
    return
    (self.conversationType == ZMConversationTypeInvalid) ||
    (self.conversationType == ZMConversationTypeSelf) ||
    (self.conversationType == ZMConversationTypeConnection) ||
    (self.conversationType == ZMConversationTypeGroup && !self.isSelfAnActiveMember);
}

+ (NSSet *)keyPathsForValuesAffectingIsReadOnly;
{
    return [NSSet setWithObjects:ConversationTypeKey, ZMConversationIsSelfAnActiveMemberKey, nil];
}

- (NSString *)displayName
{
    NSAttributedString *s = self.attributedDisplayName;
    NSString *result;
    if (0 < s.length) {
        // Get the range of the first part that is not dimmed:
        NSRange range = {};
        NSNumber *isDimmed = [s attribute:ZMIsDimmedKey atIndex:0 longestEffectiveRange:&range inRange:NSMakeRange(0, s.length)];
        if (! [isDimmed boolValue]) {
            result = [s.string substringWithRange:range];
        }
    }
    if ((result.length < 1) && (self.conversationType == ZMConversationTypeGroup)) {
        return NSLocalizedString(@"conversation.displayname.emptygroup", @"");
    }
    return result ?: @"";
}

+ (NSSet *)keyPathsForValuesAffectingAttributedDisplayName;
{
    NSMutableSet *finalSet = [NSMutableSet setWithSet:[ZMConversation keyPathsForValuesAffectingDisplayName]];
    [finalSet addObject: [NSString stringWithFormat:@"%@.%@", OtherInactiveParticipantsKey, @"displayName"]];

    return finalSet;
}

- (NSAttributedString *)attributedDisplayName
{
    switch (self.conversationType) {
        case ZMConversationTypeConnection:
        {
            NSString *name = self.connectedUser.name;
            if (name.length == 0) {
                name = self.userDefinedName;
            }
            return [[NSAttributedString alloc] initWithString:name ?: @"…"];
        }
            break;
        case ZMConversationTypeGroup:
            if (0 < self.userDefinedName.length) {
                return [[NSAttributedString alloc] initWithString:self.userDefinedName];
            }
            else {
                ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
                NSArray *activeNames = [self.otherActiveParticipants.array mapWithBlock:^NSString*(ZMUser *user) {
                    if(user == selfUser || user.name.length < 1) {
                        return nil;
                    }
                    return user.displayName;
                }];
                
                NSArray *inactiveNames = [self.otherInactiveParticipants.array mapWithBlock:^NSString*(ZMUser *user) {
                    if(user == selfUser || user.name.length < 1) {
                        return nil;
                    }
                    return user.displayName;
                }];
                
                NSString *joiner = @", ";
                NSDictionary *dimmed = @{ZMIsDimmedKey: @YES};
                NSString *activeNamesString = [activeNames componentsJoinedByString:joiner];
                NSString *inactiveNamesString = [inactiveNames componentsJoinedByString:joiner];
                
                NSMutableAttributedString *allNames = [[NSMutableAttributedString alloc] initWithString:activeNamesString attributes:@{}];
                
                if (inactiveNamesString.length > 0) {
                    NSAttributedString *attributedInactiveNames = [[NSAttributedString alloc] initWithString:inactiveNamesString attributes:dimmed];
                    [allNames appendAttributedString:[[NSAttributedString alloc] initWithString:joiner attributes:dimmed]];
                    [allNames appendAttributedString:attributedInactiveNames];
                }
                
                return allNames;
            }
            
            break;
            
        case ZMConversationTypeOneOnOne:
        {
            ZMUser *other = self.otherActiveParticipants.firstObject ?: self.connectedUser;
            NSString *name = other.name;
            if (0 < name.length) {
                return [[NSAttributedString alloc] initWithString:name];
            }
            else {
                // The user is most probably deleted
                return [[NSAttributedString alloc] initWithString:@"…"];
            }
        }
            break;
            
        case ZMConversationTypeSelf:
            return [[NSAttributedString alloc] initWithString:[ZMUser selfUserInContext:self.managedObjectContext].displayName ?: @""];
            break;
            
        case ZMConversationTypeInvalid:
            return [[NSAttributedString alloc] initWithString:@""];
            break;
    }
}

+ (NSSet *)keyPathsForValuesAffectingDisplayName;
{
    return [NSSet setWithObjects:ConversationTypeKey, @"connection",
            ZMConversationUserDefinedNameKey, nil];
}

+ (instancetype)insertGroupConversationIntoUserSession:(id<ZMManagedObjectContextProvider>)session withParticipants:(NSArray *)participants
{
    VerifyReturnNil(session != nil);
    return [self insertGroupConversationIntoManagedObjectContext:session.managedObjectContext withParticipants:participants];
}

+ (instancetype)existingOneOnOneConversationWithUser:(ZMUser *)otherUser inUserSession:(id<ZMManagedObjectContextProvider>)session;
{
    NOT_USED(session);
    return otherUser.connection.conversation;
}


- (void)setClearedEventID:(ZMEventID *)clearedEventID
{
    [self setTransientEventID:clearedEventID forKey:ZMConversationClearedEventIDKey];
    [self closeEventIDGap];
}

- (void)closeEventIDGap
{
    if (self.clearedEventID != nil) {
        ZMEventID *lowestEventID = [ZMEventID eventIDWithMajor:1 minor:0];
        ZMEventIDRange *range = [[ZMEventIDRange alloc] initWithEventIDs:@[lowestEventID, self.clearedEventID]];
        [self addEventRangeToDownloadedEvents:range];
    }
}

- (void)setClearedTimeStamp:(NSDate *)clearedTimeStamp
{
    [self willChangeValueForKey:ZMConversationClearedTimeStampKey];
    [self setPrimitiveValue:clearedTimeStamp forKey:ZMConversationClearedTimeStampKey];
    [self didChangeValueForKey:ZMConversationClearedTimeStampKey];
    if (self.managedObjectContext.zm_isSyncContext) {
        [self deleteOlderMessages];
    }
}

- (void)setLastReadServerTimeStamp:(NSDate *)lastReadServerTimeStamp
{
    [self willChangeValueForKey:ZMConversationLastReadServerTimeStampKey];
    [self setPrimitiveValue:lastReadServerTimeStamp forKey:ZMConversationLastReadServerTimeStampKey];
    [self didChangeValueForKey:ZMConversationLastReadServerTimeStampKey];
    
    if (self.managedObjectContext.zm_isSyncContext) {
        [self updateUnread];
    }
}

- (ZMEventID *)lastEventID;
{
    return [self transientEventIDForKey:LastEventIDKey];
}

- (void)setLastEventID:(ZMEventID *)newEventID;
{
    [self setTransientEventID:newEventID forKey:LastEventIDKey];
}

+ (NSSet *)keyPathsForValuesAffectingLastEventID
{
    return [NSSet setWithObject:LastEventIDDataKey];
}

- (ZMEventID *)lastReadEventID;
{
    return [self transientEventIDForKey:LastReadEventIDKey];
}

- (void)setLastReadEventID:(ZMEventID *)newEventID;
{
    [self setTransientEventID:newEventID forKey:LastReadEventIDKey];
}

- (ZMEventID *)archivedEventID
{
    return [self transientEventIDForKey:ZMConversationArchivedEventIDKey];
}

- (void)setArchivedEventID:(ZMEventID *)archivedEventID
{
    [self setTransientEventID:archivedEventID forKey:ZMConversationArchivedEventIDKey];
}

- (ZMEventID *)clearedEventID
{
    return [self transientEventIDForKey:ZMConversationClearedEventIDKey];
}

+ (NSSet *)keyPathsForValuesAffectingLastReadEventID
{
    return [NSSet setWithObject:ZMConversationLastReadEventIDDataKey];
}

- (NSUUID *)remoteIdentifier;
{
    return [self transientUUIDForKey:RemoteIdentifierKey];
}

- (void)setRemoteIdentifier:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:RemoteIdentifierKey];
}

+ (NSSet *)keyPathsForValuesAffectingRemoteIdentifier
{
    return [NSSet setWithObject:ZMConversationRemoteIdentifierDataKey];
}

- (void)setUserDefinedName:(NSString *)aName {
    
    [self willChangeValueForKey:ZMConversationUserDefinedNameKey];
    [self setPrimitiveValue:[aName copy] forKey:ZMConversationUserDefinedNameKey];
    [self didChangeValueForKey:ZMConversationUserDefinedNameKey];
    
    self.normalizedUserDefinedName = [self.userDefinedName normalizedString];
}


+ (NSArray *)defaultSortDescriptors
{
    return @[[NSSortDescriptor sortDescriptorWithKey:ZMConversationIsArchivedKey ascending:YES],
             [NSSortDescriptor sortDescriptorWithKey:LastModifiedDateKey ascending:NO],
             [NSSortDescriptor sortDescriptorWithKey:ZMConversationRemoteIdentifierDataKey ascending:YES],];
}

- (void)addParticipant:(ZMUser *)participant
{
    VerifyReturn(self.conversationType == ZMConversationTypeGroup);
    RequireString(participant != [ZMUser selfUserInContext:self.managedObjectContext], "Can't add self user to a conversation");
    [self internalAddParticipant:participant isAuthoritative:NO];
}

- (void)removeParticipant:(ZMUser *)participant;
{
    VerifyReturn(self.conversationType == ZMConversationTypeGroup);
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    [self internalRemoveParticipant:participant sender:selfUser];
}

- (void)setVisibleWindowFromMessage:(ZMMessage *)oldestMessage toMessage:(ZMMessage *)newestMessage;
{
    ZMEventID *oldestEventId;
    ZMEventID *newestEventId;
    
    NSDate *oldestTimeStamp;
    NSDate *newestTimeStamp;
    
    if(oldestMessage) {
        oldestEventId = oldestMessage.eventID;
        oldestTimeStamp = oldestMessage.serverTimestamp;
    }
    if(newestMessage) {
        newestEventId = newestMessage.eventID;
        newestTimeStamp = newestMessage.serverTimestamp;
    }
    
    if (newestTimeStamp != nil && oldestTimeStamp != nil && [newestTimeStamp compare:oldestTimeStamp] == NSOrderedAscending) {
        ZMEventID *tempID = oldestEventId;
        oldestEventId = newestEventId;
        newestEventId = tempID;
        
        ZMMessage *tempMsg = oldestMessage;
        oldestMessage = newestMessage;
        NOT_USED(oldestMessage);
        newestMessage = tempMsg;
    }
    [self updateLastReadServerTimeStampWithMessage:newestMessage];
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if(newestEventId != nil) {
        userInfo[ZMVisibleWindowUpperKey] = newestEventId;
    }
    if(oldestEventId != nil) {
        userInfo[ZMVisibleWindowLowerKey] = oldestEventId;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZMConversationDidChangeVisibleWindowNotification object:self userInfo:userInfo];
    
    if (self.hasUnreadUnsentMessage) {
        self.hasUnreadUnsentMessage = NO;
    }
}

- (void)savePendingLastRead
{
    [self updateLastReadServerTimeStampIfNeededWithTimeStamp:self.tempMaxLastReadServerTimeStamp andSync:NO];
    self.tempMaxLastReadServerTimeStamp = nil;
    self.lastReadEventIDUpdateCounter = 0;
    [self.managedObjectContext enqueueDelayedSave];
}

- (void)updateLastReadServerTimeStampWithMessage:(ZMMessage *)message
{
    NSDate *timeStamp = message.serverTimestamp;
    BOOL senderIsSelfUser = message.sender.isSelfUser;

    if( ! self.managedObjectContext.zm_isUserInterfaceContext ) {
        return;
    }
    
    if (timeStamp == nil) {
        return;
    }
    
    if (self.lastReadServerTimeStamp != nil  && [timeStamp compare:self.lastReadServerTimeStamp] == NSOrderedAscending) {
        return;
    }
    
    NSUInteger idx = [self.messages.array indexOfObjectIdenticalTo:message];
    if (idx == NSNotFound) {
        return;
    }
    
    if (idx+1  == self.messages.count) {
        timeStamp = self.lastServerTimeStamp;
    }
    else if (message.deliveryState != ZMDeliveryStateDelivered) {
        if (idx == 0) {
            timeStamp = self.lastServerTimeStamp;
        }
        else {
            __block ZMMessage *lastDeliveredMessage;
            __block NSUInteger newIdx;
            [self.messages.array enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, idx)] options:NSEnumerationReverse usingBlock:^(ZMMessage *aMessage, NSUInteger anIdx, BOOL *stop) {
                if (aMessage.deliveryState == ZMDeliveryStateDelivered) {
                    lastDeliveredMessage = aMessage;
                    newIdx = anIdx;
                    *stop = YES;
                }
            }];
            if (lastDeliveredMessage == nil ||
                [lastDeliveredMessage.serverTimestamp compare:self.lastReadServerTimeStamp] == NSOrderedAscending)
            {
                return;
            }
            timeStamp = lastDeliveredMessage.serverTimestamp;
            senderIsSelfUser = lastDeliveredMessage.sender.isSelfUser;
        }
    }
    [self updateLastReadServerTimeStamp:timeStamp senderIsSelfUser:senderIsSelfUser];
}

- (void)updateLastReadServerTimeStamp:(NSDate *)serverTimeStamp senderIsSelfUser:(BOOL)senderIsSelfUser
{
    if ((self.lastReadServerTimeStamp != nil) &&([serverTimeStamp compare:self.lastReadServerTimeStamp] == NSOrderedAscending)) {
        return;
    }
    
    if (self.tempMaxLastReadServerTimeStamp == nil ||  [self.tempMaxLastReadServerTimeStamp compare:serverTimeStamp] == NSOrderedAscending) {
        if (!senderIsSelfUser) {
            self.tempMaxLastReadServerTimeStamp = serverTimeStamp;
        }
        else {
            // This code only gets executed when we insert a message on this device and immediately set the window before the message was updated from the BE
            // Since the message was created by the selfUser, we don't want to sync the lastRead
            // To stop syncing of previously stored values, we need to reset the tempMaxLastRead to 0
            self.tempMaxLastReadServerTimeStamp = nil;
            self.lastReadEventIDUpdateCounter = 0;
            return;
        }
    }
    
    if (self.managedObjectContext.zm_isUserInterfaceContext) {
        self.lastReadEventIDUpdateCounter++;
        int64_t currentCount = self.lastReadEventIDUpdateCounter;
        
        [self.managedObjectContext.dispatchGroup enter];
        ZM_WEAK(self);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.lastReadEventIDSaveDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ZM_STRONG(self);
            if (self == nil) {
                return;
            }
            if (currentCount != self.lastReadEventIDUpdateCounter) {
                [self.managedObjectContext.dispatchGroup leave];
                return;
            }
            [self savePendingLastRead];
            [self.managedObjectContext.dispatchGroup leave];
        });
    }
    else {
        [self updateLastReadServerTimeStampIfNeededWithTimeStamp:self.tempMaxLastReadServerTimeStamp andSync:NO];
    }
}



- (void)insertUnreadTimeStamp:(NSDate *)serverTimeStamp
{
    if (serverTimeStamp == nil) {
        return;
    }
    if ([(NSDate *)self.unreadTimeStamps.firstObject compare:serverTimeStamp] == NSOrderedDescending) {
        [self.unreadTimeStamps addObject:serverTimeStamp];
    }
    else if ([(NSDate *)self.unreadTimeStamps.lastObject compare:serverTimeStamp] == NSOrderedAscending) {
        [self.unreadTimeStamps insertObject:serverTimeStamp atIndex:0];
    }
    else {
        NSUInteger index = [self.unreadTimeStamps indexOfObjectPassingTest:^BOOL(NSDate *stamp, NSUInteger idx, BOOL *stop) {
            NOT_USED(idx);
            if ([stamp compare:serverTimeStamp] == NSOrderedAscending) {
                *stop = YES;
                return YES;
            }
            return NO;
        }];
        [self.unreadTimeStamps insertObject:serverTimeStamp atIndex:index+1];
    }
}

- (id <ZMConversationMessage>)appendMessageWithText:(NSString *)text;
{
    VerifyReturnNil(![text zmHasOnlyWhitespaceCharacters]);
    VerifyReturnNil(text != nil);

    NSUUID *nonce = NSUUID.UUID;
    id <ZMConversationMessage> message = [self appendOTRMessageWithText:text nonce:nonce];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ZMConversationClearTypingNotificationName object:self];
    return message;
}

- (id<ZMConversationMessage>)appendMessageWithImageAtURL:(NSURL *)fileURL;
{
    VerifyReturnNil(fileURL != nil);
    if (! fileURL.isFileURL) {
        ZMLogWarn(@"Trying to add an image message, but the URL is not a file URL.");
        return nil;
    }
    NSError *error;
    // We specifically do not want the data to be mapped at this place, because the underlying file might go away before we're done using the data.
    NSData * const originalImageData = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];
    VerifyReturnNil(originalImageData != nil);
    CGSize const originalSize = [ZMImagePreprocessor sizeOfPrerotatedImageAtURL:fileURL];
    VerifyReturnNil(! CGSizeEqualToSize(originalSize, CGSizeZero));
    return [self appendMessageWithOriginalImageData:originalImageData originalSize:originalSize];
}

- (id<ZMConversationMessage>)appendMessageWithImageData:(NSData *)imageData;
{
    imageData = [imageData copy];
    VerifyReturnNil(imageData != nil);
    CGSize const originalSize = [ZMImagePreprocessor sizeOfPrerotatedImageWithData:imageData];
    VerifyReturnNil(! CGSizeEqualToSize(originalSize, CGSizeZero));
    
    return [self appendMessageWithOriginalImageData:imageData originalSize:originalSize];
}

- (nullable id<ZMConversationMessage>)appendMessageWithFileMetadata:(nonnull ZMFileMetadata *)fileMetadata
{
    return [self appendOTRMessageWithFileMetadata:fileMetadata nonce:NSUUID.UUID];
}

- (nullable id<ZMConversationMessage>)appendMessageWithLocationData:(nonnull ZMLocationData *)locationData
{
    return [self appendOTRMessageWithLocationData:locationData nonce:NSUUID.UUID];
}

- (id<ZMConversationMessage>)appendMessageWithOriginalImageData:(NSData *)originalImageData originalSize:(CGSize __unused)originalSize;
{
    return [self appendOTRMessageWithImageData:originalImageData nonce:[NSUUID UUID]];
}

- (id<ZMConversationMessage>)appendKnock;
{
    return [self appendOTRKnockMessageWithNonce:[NSUUID UUID]];
}

- (BOOL)isPendingConnectionConversation;
{
    return self.connection != nil && self.connection.status == ZMConnectionStatusPending;
}

+ (NSSet *)keyPathsForValuesAffectingIsPendingConnectionConversation
{
    return [NSSet setWithObjects:ZMConversationConnectionKey, @"connection.status", nil];
}

- (ZMConversationListIndicator)conversationListIndicator;
{
    if(self.connectedUser.isPendingApprovalByOtherUser) {
        return ZMConversationListIndicatorPending;
    } else if (self.callDeviceIsActive) {
            return ZMConversationListIndicatorActiveCall;
    } else if (self.voiceChannelState == ZMVoiceChannelStateIncomingCallInactive) {
        return ZMConversationListIndicatorInactiveCall;
    }
    return [self unreadListIndicator];
}

+ (NSSet *)keyPathsForValuesAffectingConversationListIndicator
{
    return [ZMConversation keyPathsForValuesAffectingUnreadListIndicator];
}


- (BOOL)hasDraftMessageText
{
    return (0 < self.draftMessageText.length);
}

+ (NSSet *)keyPathsForValuesAffectingHasDraftMessageText
{
    return [NSSet setWithObject:DraftMessageTextKey];
}

- (ZMMessage *)lastReadMessage;
{
    NSDate * const timeStamp = self.lastReadServerTimeStamp;
    if (timeStamp == nil ||
        self.messages.count == 0 ||
        [timeStamp compare:[self.messages.firstObject serverTimestamp]] == NSOrderedAscending
        )
    {
        return nil;
    }
    
    if ([timeStamp compare:[self.messages.lastObject serverTimestamp]] == NSOrderedDescending) {
        return self.messages.lastObject;
    }
    
    BOOL reverseSearch = NO;
    ZMMessage *aMessage = self.messages[self.messages.count/2];
    if ([aMessage.serverTimestamp compare:self.lastReadServerTimeStamp] == NSOrderedAscending) {
        reverseSearch = YES;
    }
    
    __block ZMMessage *result;
    __block NSDate *resultTimeStamp;
    [self.messages enumerateObjectsWithOptions:reverseSearch ? NSEnumerationReverse : 0
                                    usingBlock:^(ZMMessage *message, NSUInteger ZM_UNUSED idx, BOOL *stop) {
                                        NSDate *newTimeStamp = [message valueForKey:ZMMessageServerTimestampKey];
                                        
                                        if (newTimeStamp == nil) {
                                            ZMLogWarn(@"Conversation contains message without a timestamp, all messages should have a timestamp.");
                                        } else if ([timeStamp compare:newTimeStamp] == NSOrderedSame) {
                                            result = message;
                                            *stop = YES;
                                        } else if ([timeStamp compare:newTimeStamp] == NSOrderedAscending) {
                                            return;
                                        } else if (resultTimeStamp == nil) {
                                            resultTimeStamp = newTimeStamp;
                                            result = message;
                                        } else if ([resultTimeStamp compare:newTimeStamp] == NSOrderedAscending) {
                                            resultTimeStamp = newTimeStamp;
                                            result = message;
                                        }
                                    }];
    return result;
}

+ (NSSet *)keyPathsForValuesAffectingLastReadMessage
{
    return [NSSet setWithObjects:ZMConversationMessagesKey, ZMConversationLastReadServerTimeStampKey, nil];
}

- (void)updateKeysThatHaveLocalModifications;
{
    [super updateKeysThatHaveLocalModifications];
    NSMutableSet *newKeys = [self.keysThatHaveLocalModifications mutableCopy];
    if (self.unsyncedInactiveParticipants.count > 0) {
        [newKeys addObject:ZMConversationUnsyncedInactiveParticipantsKey];
    }
    if (self.unsyncedActiveParticipants.count > 0) {
        [newKeys addObject:ZMConversationUnsyncedActiveParticipantsKey];
    }
    
    if( ![newKeys isEqual:self.keysThatHaveLocalModifications]) {
        [self setLocallyModifiedKeys:newKeys];
    }
}

- (NSSet *)keysThatHaveLocalModifications
{
    NSMutableSet *keys = [NSMutableSet setWithSet:super.keysThatHaveLocalModifications];
    if (!self.isZombieObject) {
        if(self.hasLocalModificationsForCallDeviceIsActive) {
            [keys addObject:ZMConversationCallDeviceIsActiveKey];
        }
        if (self.hasLocalModificationsForIsSendingVideo) {
            [keys addObject:ZMConversationIsSendingVideoKey];
        }
        if (self.hasLocalModificationsForIsIgnoringCall) {
            [keys addObject:ZMConversationIsIgnoringCallKey];
        }
    }
    return [keys copy];
}

- (void)willSave
{
    [super willSave];
    
    if (self.unsyncedInactiveParticipants.count == 0 && [self.keysThatHaveLocalModifications containsObject:ZMConversationUnsyncedInactiveParticipantsKey]) {
        [self resetLocallyModifiedKeys:[NSSet setWithObject:ZMConversationUnsyncedInactiveParticipantsKey]];
    }
    if (self.unsyncedActiveParticipants.count == 0 && [self.keysThatHaveLocalModifications containsObject:ZMConversationUnsyncedActiveParticipantsKey]) {
        [self resetLocallyModifiedKeys:[NSSet setWithObject:ZMConversationUnsyncedActiveParticipantsKey]];
    }
}

- (NSArray *)keysTrackedForLocalModifications {
    NSArray *superKeys = [super keysTrackedForLocalModifications];
    NSMutableArray *trackedKeys = [superKeys mutableCopy];
    [trackedKeys addObject:ZMConversationUnsyncedInactiveParticipantsKey];
    [trackedKeys addObject:ZMConversationUnsyncedActiveParticipantsKey];
    [trackedKeys addObject:ZMConversationCallDeviceIsActiveKey];
    [trackedKeys addObject:ZMConversationIsSendingVideoKey];
    [trackedKeys addObject:ZMConversationIsIgnoringCallKey];
    return trackedKeys;
}

- (NSMutableOrderedSet *)mutableLastServerSyncedActiveParticipants
{
    return [self mutableOrderedSetValueForKey:LastServerSyncedActiveParticipantsKey];
}


- (void)resendLastUnsentMessages
{
    [self.messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(ZMMessage *message, __unused NSUInteger idx, BOOL *stop) {
        if (message.isExpired) {
            [message resend];
            *stop = YES;
        }
    }];
}

@end



@implementation ZMConversation (Internal)

@dynamic connection;
@dynamic creator;
@dynamic lastModifiedDate;
@dynamic downloadedMessageIDs;
@dynamic normalizedUserDefinedName;
@dynamic callStateNeedsToBeUpdatedFromBackend;
@dynamic hiddenMessages;


+ (NSPredicate *)callConversationPredicate;
{
    return [NSPredicate predicateWithFormat:@"(%K != NULL) AND ((%K == %@) OR (%K == %@))",
            [self remoteIdentifierDataKey],
            ConversationTypeKey, @(ZMConversationTypeOneOnOne),
            ConversationTypeKey, @(ZMConversationTypeGroup)];
}

+ (NSPredicate *)predicateForObjectsThatNeedCallStateToBeUpdatedUpstream;
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K == 0) AND (%K == 0)",
            CallStateNeedsToBeUpdatedFromBackendKey,
            NeedsToBeUpdatedFromBackendKey];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, [self callConversationPredicate], [super predicateForObjectsThatNeedToBeUpdatedUpstream]]];
}

+ (NSPredicate *)predicateForUpdatingCallStateDuringSlowSync;
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K == 0) AND (%K.@count > 0)",
                              CallStateNeedsToBeUpdatedFromBackendKey,
                              ZMConversationCallParticipantsKey];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, [self callConversationPredicate]]];
}

+ (NSPredicate *)predicateForNeedingCallStateToBeUpdatedFromBackend;
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%K == 1)",
                              CallStateNeedsToBeUpdatedFromBackendKey];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[predicate, [self callConversationPredicate]]];
}


+ (NSSet *)keyPathsForValuesAffectingIsArchived
{
    return [NSSet setWithObject:ZMConversationIsArchivedKey];
}

+ (NSString *)entityName;
{
    return @"Conversation";
} 


- (NSMutableOrderedSet *)mutableMessages;
{
    return [self mutableOrderedSetValueForKey:ZMConversationMessagesKey];
}

+ (NSPredicate *)predicateForValidConversations;
{
    NSPredicate *basePredicate = [self predicateForFilteringResults];
    NSPredicate *notAConnection = [NSPredicate predicateWithFormat:@"%K != %d", ConversationTypeKey, ZMConversationTypeConnection]; //one-to-one conversations
    NSPredicate *activeConnection = [NSPredicate predicateWithFormat:@"NOT %K.status IN %@", ZMConversationConnectionKey, @[@(ZMConnectionStatusPending), @(ZMConnectionStatusIgnored), @(ZMConnectionStatusCancelled)]]; //pending connections should be in other list, ignored and cancelled are not displayed
    
    NSPredicate *predicate1 = [NSCompoundPredicate orPredicateWithSubpredicates:@[notAConnection, activeConnection]]; // one-to-one conversations and not pending and not ignored connections
    
    NSPredicate *noConnection = [NSPredicate predicateWithFormat:@"%K == nil", ZMConversationConnectionKey]; //group conversations
    NSPredicate *notBlocked = [NSPredicate predicateWithFormat:@"%K.status != %d",
                               ZMConversationConnectionKey, ZMConnectionStatusBlocked];
    
    NSPredicate *predicate2 = [NSCompoundPredicate orPredicateWithSubpredicates:@[noConnection, notBlocked]]; //group conversations and not blocked connections
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[basePredicate, predicate1, predicate2]];
}

+ (NSPredicate *)predicateForConversationsIncludingArchived;
{
    
    NSPredicate *notClearedTimeStamp = [NSPredicate predicateWithFormat:@"%K == NULL OR %K > %K OR (%K == %K AND %K == NO)",
                                        ZMConversationClearedTimeStampKey,
                                        ZMConversationLastServerTimeStampKey, ZMConversationClearedTimeStampKey,
                                        ZMConversationLastServerTimeStampKey, ZMConversationClearedTimeStampKey,
                                        ZMConversationIsArchivedKey];
    
    NSPredicate *notClearedEventID = [NSPredicate predicateWithFormat:@"%K == NULL OR %K > %K OR (%K == %K AND %K == NO)",
                                      ZMConversationClearedEventIDDataKey,
                                      LastEventIDDataKey, ZMConversationClearedEventIDDataKey,
                                      LastEventIDDataKey, ZMConversationClearedEventIDDataKey,
                                      ZMConversationIsArchivedKey];
    
    NSPredicate *notCleared = [NSCompoundPredicate andPredicateWithSubpredicates:@[notClearedTimeStamp, notClearedEventID]];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[notCleared, [self predicateForValidConversations]]];
}

+ (NSPredicate *)predicateForArchivedConversations;
{
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[
                                                                [self predicateForConversationsIncludingArchived],
                                                                [NSPredicate predicateWithFormat:@"%K == YES", ZMConversationIsArchivedKey]
                                                                ]];
}

+ (NSPredicate *)predicateForClearedConversations
{
    NSPredicate *cleared = [NSPredicate predicateWithFormat:@"(%K != NULL OR %K != NULL) AND %K == YES",
                                ZMConversationClearedTimeStampKey,
                                ZMConversationClearedEventIDKey,
                                ZMConversationIsArchivedKey];

    return [NSCompoundPredicate andPredicateWithSubpredicates:@[cleared, [self predicateForValidConversations]]];
}

+ (NSPredicate *)predicateForConversationsExcludingArchivedAndInCall;
{
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[
                                                                [self predicateForConversationsIncludingArchived],
                                                                [NSPredicate predicateWithFormat:@"%K == NO AND %K != %d",
                                                                 ZMConversationIsArchivedKey,
                                                                 VoiceChannelStateKey, ZMVoiceChannelStateSelfConnectedToActiveChannel]
                                                                ]];
}

+ (NSPredicate *)predicateForPendingConversations;
{
    NSPredicate *basePredicate = [self predicateForFilteringResults];
    NSPredicate *pendingConversationPredicate = [NSPredicate predicateWithFormat:@"%K == %d AND %K.status == %d",
                                     ConversationTypeKey, ZMConversationTypeConnection,
                                     ZMConversationConnectionKey, ZMConnectionStatusPending];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[basePredicate, pendingConversationPredicate]];
}

+ (NSPredicate *)predicateForConversationsWithNonIdleVoiceChannel;
{
    NSPredicate *basePredicate = [self predicateForFilteringResults];

    NSPredicate *callingPredicate = [NSPredicate predicateWithFormat:@"%K != %d AND %K != %d",
                                     VoiceChannelStateKey, ZMVoiceChannelStateNoActiveUsers,
                                     ConversationTypeKey, ZMConversationTypeConnection];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[basePredicate, callingPredicate]];
}

+ (NSPredicate *)predicateForConversationWithActiveCalls;
{
    NSPredicate *basePredicate = [self predicateForFilteringResults];
    NSPredicate *callingPredicate = [NSPredicate predicateWithFormat:@"%K == %d", VoiceChannelStateKey, ZMVoiceChannelStateSelfConnectedToActiveChannel];
    
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[basePredicate, callingPredicate]];
}

+ (NSPredicate *)predicateForSharableConversations
{
    NSPredicate *basePredication = [self predicateForConversationsIncludingArchived];
    
    NSPredicate *hasOtherActiveParticipants = [NSPredicate predicateWithFormat:@"%K.@count > 0", ZMConversationOtherActiveParticipantsKey];
    NSPredicate *oneOnOneOrGroupConversation = [NSPredicate predicateWithFormat:@"%K == %i OR %K == %i",
                                                ZMConversationConversationTypeKey, ZMConversationTypeOneOnOne,
                                                ZMConversationConversationTypeKey, ZMConversationTypeGroup];
    NSPredicate *selfIsActiveMember = [NSPredicate predicateWithFormat:@"isSelfAnActiveMember == YES"];
    NSPredicate *synced = [NSPredicate predicateWithFormat:@"%K != NULL", [self remoteIdentifierDataKey]];
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[basePredication, oneOnOneOrGroupConversation, hasOtherActiveParticipants, selfIsActiveMember, synced]];
}

+ (ZMConversationList *)conversationsIncludingArchivedInContext:(NSManagedObjectContext *)moc;
{
    return [moc.conversationListDirectory conversationsIncludingArchived];
}

+ (ZMConversationList *)archivedConversationsInContext:(NSManagedObjectContext *)moc;
{
    return [moc.conversationListDirectory archivedConversations];
}

+ (ZMConversationList *)clearedConversationsInContext:(NSManagedObjectContext *)moc;
{
    return [moc.conversationListDirectory clearedConversations];
}

+ (ZMConversationList *)conversationsExcludingArchivedAndCallingInContext:(NSManagedObjectContext *)moc;
{
    return [moc.conversationListDirectory unarchivedAndNotCallingConversations];
}

+ (ZMConversationList *)pendingConversationsInContext:(NSManagedObjectContext *)moc;
{
    return [moc.conversationListDirectory pendingConnectionConversations];
}

- (void)sortMessages
{
    NSOrderedSet *sorted = [NSOrderedSet orderedSetWithArray:[self.messages sortedArrayUsingDescriptors:[ZMMessage defaultSortDescriptors]]];
    // Be sure not to "dirty" the relationship, unless we need to:
    if (! [self.messages isEqualToOrderedSet:sorted]) {
        [self setValue:sorted forKey:ZMConversationMessagesKey];
    }
    // sortMessages is called when processing downloaded events (e.g. after slow sync) which can be unordered
    // after sorting messages we also need to recalculate the unread properties
    [self didUpdateConversationWhileFetchingUnreadMessages];
}

- (void)resortMessagesWithUpdatedMessage:(ZMMessage *)message
{
    [self.mutableMessages removeObject:message];
    [self sortedAppendMessage:message];
    [self updateUnreadCountIfNeededForMessage:message];
}

- (void)updateUnreadCountIfNeededForMessage:(ZMMessage *)message
{
    BOOL senderIsNotSelf = (message.sender != [ZMUser selfUserInContext:self.managedObjectContext]);
    if (senderIsNotSelf && [message shouldGenerateUnreadCount]) {
        [self insertTimeStamp:message.serverTimestamp];
    }
}

- (void)resetParticipantsBackToLastServerSync
{
    [self.mutableOtherActiveParticipants removeAllObjects];
    [self.mutableOtherActiveParticipants addObjectsFromArray:self.mutableLastServerSyncedActiveParticipants.array];
    
    [self resetLocallyModifiedKeys:[NSSet setWithObject:ZMConversationUnsyncedActiveParticipantsKey]];
    [self resetLocallyModifiedKeys:[NSSet setWithObject:ZMConversationUnsyncedInactiveParticipantsKey]];
}

- (void)mergeWithExistingConversationWithRemoteID:(NSUUID *)remoteID;
{
    ZMConversation *existingConversation = [ZMConversation conversationWithRemoteID:remoteID createIfNeeded:NO inContext:self.managedObjectContext];
    if ((existingConversation != nil) && ![existingConversation isEqual:self]) {
        Require(self.remoteIdentifier == nil);
        [self.mutableMessages addObjectsFromArray:existingConversation.messages.array];
        [self sortMessages];
        // Just to be on the safe side, force update:
        self.needsToBeUpdatedFromBackend = YES;
        // This is a duplicate. Delete the other one
        [self.managedObjectContext deleteObject:existingConversation];
    }
    self.remoteIdentifier = remoteID;
}

- (void)updateWithMessage:(ZMMessage *)message timeStamp:(NSDate *)timeStamp eventID:(ZMEventID *)eventID
{
    [self updateLastServerTimeStampIfNeeded:timeStamp];
    [self updateLastEventIDIfNeededWithEventID:eventID];
    [self addEventToDownloadedEvents:eventID timeStamp:timeStamp];
    [self updateLastModifiedDateIfNeeded:timeStamp];
    [self updateUnreadMessagesWithMessage:message];
}


+ (instancetype)conversationWithRemoteID:(NSUUID *)UUID createIfNeeded:(BOOL)create inContext:(NSManagedObjectContext *)moc
{
    return [self conversationWithRemoteID:UUID createIfNeeded:create inContext:moc created:NULL];
}

+ (instancetype)conversationWithRemoteID:(NSUUID *)UUID createIfNeeded:(BOOL)create inContext:(NSManagedObjectContext *)moc created:(BOOL *)created
{
    VerifyReturnNil(UUID != nil);
    
    // We must only ever call this on the sync context. Otherwise, there's a race condition
    // where the UI and sync contexts could both insert the same conversation (same UUID) and we'd end up
    // having two duplicates of that conversation, and we'd have a really hard time recovering from that.
    //
    RequireString(! create || moc.zm_isSyncContext, "Race condition!");
    
    ZMConversation *result = [self fetchObjectWithRemoteIdentifier:UUID inManagedObjectContext:moc];
    
    if (result != nil) {
        if (nil != created) {
            *created = NO;
        }
        return result;
    } else if (create) {
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:moc];
        conversation.remoteIdentifier = UUID;
        if (nil != created) {
            *created = YES;
        }
        return conversation;
    }
    return nil;
}

+ (instancetype)insertGroupConversationIntoManagedObjectContext:(NSManagedObjectContext *)moc withParticipants:(NSArray *)participants;
{
    RequireString((participants.count >= 2u), "Not enough users to create group conversations");
    ZMUser *selfUser = [ZMUser selfUserInContext:moc];
    ZMConversation *conversation = (ZMConversation *)[super insertNewObjectInManagedObjectContext:moc];
    conversation.lastModifiedDate = [NSDate date];
    conversation.conversationType = ZMConversationTypeGroup;
    conversation.creator = selfUser;

    for (ZMUser *participant in participants) {
        Require([participant isKindOfClass:[ZMUser class]]);
        const BOOL isSelf = (participant == selfUser);
        RequireString(!isSelf, "Can't pass self user as a participant of a group conversation");
        if(!isSelf) {
            [conversation internalAddParticipant:participant isAuthoritative:NO];
        }
    }
    
    NSMutableSet *allClients = [NSMutableSet set];
    for (ZMUser *user in conversation.activeParticipants) {
        [allClients unionSet:user.clients];
    }
    
    // We need to check if we should add a 'secure' system message in case all participants are trusted
    [conversation increaseSecurityLevelIfNeededAfterUserClientsWereTrusted:allClients];
    [conversation appendNewConversationSystemMessageIfNeeded];
    return conversation;
}

- (ZMEventIDRangeSet *)downloadedMessageIDs;
{
    NSString *key = DownloadedMessageIDsKey;
    [self willAccessValueForKey:key];
    ZMEventIDRangeSet *eventSet = [self primitiveValueForKey:key];
    [self didAccessValueForKey:key];
    if (eventSet == nil) {
        NSData *eventSetData = [self valueForKey:DownloadedMessageIDsDataKey];
        if (eventSetData != nil) {
            eventSet = [[ZMEventIDRangeSet alloc] initWithData:eventSetData];
            [self setPrimitiveValue:eventSet forKey:key];
        }
        else {
            eventSet = [[ZMEventIDRangeSet alloc] init];
        }
    }
    return eventSet;
}

- (void)setDownloadedMessageIDs:(ZMEventIDRangeSet *)localMessages;
{
    NSString *key = DownloadedMessageIDsKey;
    [self willChangeValueForKey:key];
    [self setPrimitiveValue:localMessages forKey:key];
    [self didChangeValueForKey:key];
    if (localMessages != nil) {
        NSData *data = [localMessages serializeToData];
        [self setValue:data forKeyPath:DownloadedMessageIDsDataKey];
    } else {
        [self setValue:[[ZMEventIDRangeSet alloc] init] forKeyPath:DownloadedMessageIDsDataKey];
    }
}

+ (NSPredicate *)predicateForSearchString:(NSString *)searchString
{
    NSDictionary *formatDict = @{ZMConversationOtherActiveParticipantsKey : @"ANY %K.normalizedName MATCHES %@",
                                   ZMNormalizedUserDefinedNameKey: @"%K MATCHES %@"};
    NSPredicate *searchPredicate = [NSPredicate predicateWithFormatDictionary:formatDict
                                                         matchingSearchString:searchString];
    NSPredicate *activeMemberPredicate = [NSPredicate predicateWithFormat:@"%K == NULL OR %K == YES",
                                          ZMConversationClearedTimeStampKey,
                                          ZMConversationIsSelfAnActiveMemberKey];
    
    NSPredicate *basePredicate = [NSPredicate predicateWithFormat:@"(%K == %@)",
                                  ConversationTypeKey, @(ZMConversationTypeGroup)];
    
    NSPredicate *fullPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[basePredicate, searchPredicate,activeMemberPredicate]];
    return fullPredicate;
}

+ (NSPredicate *)userDefinedNamePredicateForSearchString:(NSString *)searchString;
{
    NSPredicate *predicate = [NSPredicate predicateWithFormatDictionary:@{ZMNormalizedUserDefinedNameKey: @"%K MATCHES %@"}
                                                   matchingSearchString:searchString];
    return predicate;
}


+ (NSUUID *)selfConversationIdentifierInContext:(NSManagedObjectContext *)context;
{
    // remoteID of self-conversation is guaranteed to be the same as remoteID of self-user
    ZMUser *selfUser = [ZMUser selfUserInContext:context];
    return selfUser.remoteIdentifier;
}

+ (ZMConversation *)selfConversationInContext:(NSManagedObjectContext *)managedObjectContext
{
    NSUUID *selfUserID = [ZMConversation selfConversationIdentifierInContext:managedObjectContext];
    return [ZMConversation conversationWithRemoteID:selfUserID createIfNeeded:NO inContext:managedObjectContext];
}




- (void)startFetchingMessages
{
    [[NSNotificationCenter defaultCenter] postNotificationName:ZMConversationRequestToLoadConversationEventsNotification object:self userInfo:nil];
}

- (ZMClientMessage *)appendClientMessageWithData:(NSData *)data
{
    VerifyReturnNil(data != nil);
    
    ZMClientMessage *message = [ZMClientMessage insertNewObjectInManagedObjectContext:self.managedObjectContext];
    [message addData:data];
    message.sender = [ZMUser selfUserInContext:self.managedObjectContext];
    [message setExpirationDate];
    [self sortedAppendMessage:message];
    return message;
}

- (ZMAssetClientMessage *)appendAssetClientMessageWithNonce:(NSUUID *)nonce hidden:(BOOL)hidden imageData:(NSData *)imageData
{
    ZMAssetClientMessage *message = [ZMAssetClientMessage assetClientMessageWithOriginalImageData:imageData nonce:nonce managedObjectContext:self.managedObjectContext];
    message.sender = [ZMUser selfUserInContext:self.managedObjectContext];
    if(!hidden) {
        [self sortedAppendMessage:message];
    }
    else {
        message.hiddenInConversation = self;
    }
    return message;
}

- (ZMAssetClientMessage *)appendOTRMessageWithFileMetadata:(ZMFileMetadata *)fileMetadata nonce:(NSUUID *)nonce
{
    ZMAssetClientMessage *message = [ZMAssetClientMessage assetClientMessageWithFileMetadata:fileMetadata nonce:nonce managedObjectContext:self.managedObjectContext];
    message.sender = [ZMUser selfUserInContext:self.managedObjectContext];
    message.isEncrypted = YES;
    [self sortedAppendMessage:message];
    return message;
}

- (ZMClientMessage *)appendOTRMessageWithLocationData:(ZMLocationData *)locationData nonce:(NSUUID *)nonce
{
    ZMGenericMessage *genericMessage = [ZMGenericMessage genericMessageWithLocation:locationData.zmLocation messageID:nonce.transportString];
    ZMClientMessage *message = [self appendClientMessageWithData:genericMessage.data];
    message.isEncrypted = YES;
    return message;
}

- (ZMClientMessage *)appendOTRKnockMessageWithNonce:(NSUUID *)nonce
{
    ZMGenericMessage *genericMessage = [ZMGenericMessage knockWithNonce:nonce.transportString];
    ZMClientMessage *message = [self appendClientMessageWithData:genericMessage.data];
    message.isEncrypted = YES;
    return message;
}

- (ZMClientMessage *)appendOTRMessageWithText:(NSString *)text nonce:(NSUUID *)nonce
{
    ZMGenericMessage *genericMessage = [ZMGenericMessage messageWithText:text nonce:nonce.transportString];
    ZMClientMessage *message = [self appendClientMessageWithData:genericMessage.data];
    message.linkPreviewState = ZMLinkPreviewStateWaitingToBeProcessed;
    message.isEncrypted = YES;
    return message;
}

- (ZMAssetClientMessage *)appendOTRMessageWithImageData:(NSData *)imageData nonce:(NSUUID *)nonce
{
    ZMAssetClientMessage *message = [self appendAssetClientMessageWithNonce:nonce hidden:false imageData:imageData];
    message.isEncrypted = YES;
    return message;
}

- (ZMClientMessage *)appendOTRSessionResetMessage
{
    ZMGenericMessage *genericMessage = [ZMGenericMessage sessionResetWithNonce:NSUUID.UUID.transportString];
    ZMClientMessage *message = [self appendClientMessageWithData:genericMessage.data];
    message.isEncrypted = YES;
    return message;
}

- (void)appendNewConversationSystemMessageIfNeeded;
{
    ZMMessage *firstMessage = self.messages.firstObject;
    if ([firstMessage isKindOfClass:[ZMSystemMessage class]]) {
        ZMSystemMessage *systemMessage = (ZMSystemMessage *)firstMessage;
        if (systemMessage.systemMessageType == ZMSystemMessageTypeNewConversation) {
            return;
        }
    }
    
    ZMSystemMessage *systemMessage = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.managedObjectContext];
    systemMessage.systemMessageType = ZMSystemMessageTypeNewConversation;
    systemMessage.sender = [ZMUser selfUserInContext:self.managedObjectContext];
    systemMessage.isEncrypted = NO;
    systemMessage.isPlainText = YES;
    systemMessage.nonce = [NSUUID new];
    systemMessage.sender = self.creator;
    systemMessage.users = self.activeParticipants.set;
    // the new conversation message should be displayed first,
    // additionally the use of reference date is to ensure proper transition for older clients so the message is the very
    // first message in conversation
    systemMessage.serverTimestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    
    [self sortedAppendMessage:systemMessage];
    systemMessage.visibleInConversation = self;
}

- (NSUInteger)sortedAppendMessage:(ZMMessage *)message;
{
    Require(message != nil);
    // This is more efficient than adding to mutableMessages and re-sorting all of them.
    NSUInteger index = self.messages.count;
    ZMMessage * const currentLastMessage = self.messages.lastObject;
    Require(currentLastMessage != message);
    if (currentLastMessage == nil) {
        [self.mutableMessages addObject:message];
    } else {
        if ([currentLastMessage compare:message] == NSOrderedAscending) {
            [self.mutableMessages addObject:message];
        } else {
            NSUInteger idx = [self.messages.array indexOfObject:message inSortedRange:NSMakeRange(0, self.messages.count) options:NSBinarySearchingInsertionIndex | NSBinarySearchingLastEqual usingComparator:^(ZMMessage *msg1, ZMMessage *msg2) {
                return [msg1 compare:msg2];
            }];
            [self.mutableMessages insertObject:message atIndex:idx];
            index = idx;
        }
    }
    
    NSPredicate *localSystemMessagePredicate = [ZMSystemMessage predicateForSystemMessagesInsertedLocally];
    if ([message.serverTimestamp compare:self.lastModifiedDate] == NSOrderedDescending
       && ![localSystemMessagePredicate evaluateWithObject:message]) {
        self.lastModifiedDate = message.serverTimestamp;
    }
    
    return index;
}

- (void)deleteOlderMessages
{
    if ( self.messages.count == 0 || self.clearedTimeStamp == nil) {
        return;
    }
    
    // If messages are not sorted beforehand, we might delete messages we were supposed to keep
    [self sortMessages];
    
    NSMutableArray *messagesToDelete = [NSMutableArray array];
    [self.messages enumerateObjectsUsingBlock:^(ZMSystemMessage *message, NSUInteger __unused idx, BOOL *stop) {
        NOT_USED(stop);
        // cleared event can be an invisible event that is not a message
        // therefore we should stop when we reach a message that is older than the clearedTimestamp
        if ([message.serverTimestamp compare:self.clearedTimeStamp] == NSOrderedDescending) {
            *stop = YES;
            return;
        }
        [messagesToDelete addObject:message];
    }];
    
    for (ZMMessage *message in messagesToDelete) {
        [self.managedObjectContext deleteObject:message];
    }
}

@end




@implementation ZMConversation (SelfConversation)

+ (ZMClientMessage *)appendSelfConversationWithGenericMessageData:(NSData * )messageData managedObjectContext:(NSManagedObjectContext *)moc;
{
    VerifyReturnNil(messageData != nil);

    ZMConversation *selfConversation = [ZMConversation selfConversationInContext:moc];
    VerifyReturnNil(selfConversation != nil);
    
    ZMClientMessage *clientMessage = [selfConversation appendClientMessageWithData:messageData];
    clientMessage.isEncrypted = YES;
    [clientMessage removeExpirationDate]; // Self messages don't expire since we always want to keep last read / cleared updates in-sync
    return clientMessage;
}


+ (ZMClientMessage *)appendSelfConversationWithLastReadOfConversation:(ZMConversation *)conversation
{
    NSDate *lastRead = conversation.lastReadServerTimeStamp;
    NSUUID *convID = conversation.remoteIdentifier;
    if (convID == nil || lastRead == nil || [convID isEqual:[ZMConversation selfConversationIdentifierInContext:conversation.managedObjectContext]]) {
        return nil;
    }

    NSUUID *nonce = [NSUUID UUID];
    ZMGenericMessage *message = [ZMGenericMessage messageWithLastRead:lastRead ofConversationWithID:convID.transportString nonce:nonce.transportString];
    VerifyReturnNil(message != nil);
    
    return [self appendSelfConversationWithGenericMessageData:message.data managedObjectContext:conversation.managedObjectContext];
}

+ (void)updateConversationWithZMLastReadFromSelfConversation:(ZMLastRead *)lastRead inContext:(NSManagedObjectContext *)context
{
    double newTimeStamp = lastRead.lastReadTimestamp;
    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:(newTimeStamp/1000)];
    NSUUID *conversationID = [NSUUID uuidWithTransportString:lastRead.conversationId];
    if (conversationID == nil || timestamp == nil) {
        return;
    }
    
    ZMConversation *conversationToUpdate = [ZMConversation conversationWithRemoteID:conversationID createIfNeeded:YES inContext:context];
    [conversationToUpdate updateLastReadServerTimeStampIfNeededWithTimeStamp:timestamp andSync:NO];
}


+ (ZMClientMessage *)appendSelfConversationWithClearedOfConversation:(ZMConversation *)conversation
{
    NSUUID *convID = conversation.remoteIdentifier;
    NSDate *cleared = conversation.clearedTimeStamp;
    if (convID == nil || cleared == nil || [convID isEqual:[ZMConversation selfConversationIdentifierInContext:conversation.managedObjectContext]]) {
        return nil;
    }
    
    NSUUID *nonce = [NSUUID UUID];
    ZMGenericMessage *message = [ZMGenericMessage messageWithClearedTimestamp:cleared ofConversationWithID:convID.transportString nonce:nonce.transportString];
    VerifyReturnNil(message != nil);
    
    return [self appendSelfConversationWithGenericMessageData:message.data managedObjectContext:conversation.managedObjectContext];
}

+ (void)updateConversationWithZMClearedFromSelfConversation:(ZMCleared *)cleared inContext:(NSManagedObjectContext *)context
{
    double newTimeStamp = cleared.clearedTimestamp;
    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:(newTimeStamp/1000)];
    NSUUID *conversationID = [NSUUID uuidWithTransportString:cleared.conversationId];
    if (conversationID == nil || timestamp == nil) {
        return;
    }
    
    ZMConversation *conversationToUpdate = [ZMConversation conversationWithRemoteID:conversationID createIfNeeded:YES inContext:context];
    [conversationToUpdate updateClearedServerTimeStampIfNeeded:timestamp andSync:NO];
}


@end




@implementation ZMConversation (ParticipantsInternal)

- (void)internalAddParticipant:(ZMUser *)participant isAuthoritative:(BOOL)isAuthoritative;
{
    VerifyReturn(participant != nil);
    RequireString([participant isKindOfClass:ZMUser.class], "Participant must be a ZMUser");
    if (participant.isSelfUser) {
        self.isSelfAnActiveMember = YES;
        self.needsToBeUpdatedFromBackend = YES;
    } else {
        [self.mutableOtherActiveParticipants addObject:participant];
        [self.mutableOtherInactiveParticipants removeObject:participant];
        if(isAuthoritative) {
            [self.mutableLastServerSyncedActiveParticipants addObject:participant];
        }
        [self decreaseSecurityLevelIfNeededAfterUserClientsWereIgnored:participant.clients];
    }
}

- (void)internalRemoveParticipant:(ZMUser *)participant sender:(ZMUser *)sender;
{
    VerifyReturn(participant != nil);
    RequireString([participant isKindOfClass:ZMUser.class], "Participant must be a ZMUser");
    
    if (participant.isSelfUser) {
        self.isSelfAnActiveMember = NO;
        self.isArchived = sender.isSelfUser;
        return;
    }
    
    if (! [self.otherActiveParticipants containsObject:participant]) {
        return;
    }
    [self.mutableOtherActiveParticipants removeObject:participant];
    [self.mutableOtherInactiveParticipants addObject:participant];
    [self increaseSecurityLevelIfNeededAfterRemovingClientForUser:participant];
}

@dynamic isSelfAnActiveMember;
@dynamic otherActiveParticipants;
@dynamic otherInactiveParticipants;

- (NSMutableOrderedSet *)mutableOtherInactiveParticipants;
{
    return [self mutableOrderedSetValueForKey:OtherInactiveParticipantsKey];
}

- (NSMutableOrderedSet *)mutableOtherActiveParticipants;
{
    return [self mutableOrderedSetValueForKey:ZMConversationOtherActiveParticipantsKey];
}

- (void)synchronizeRemovedUser:(ZMUser *)user
{
    [self.mutableLastServerSyncedActiveParticipants removeObject:user];
}

- (void)synchronizeAddedUser:(ZMUser *)user
{
    if (user.isSelfUser) {
        return; // The self user should never be in the 'active' list.
    }
    [self.mutableLastServerSyncedActiveParticipants addObject:user];
}

- (NSOrderedSet *)unsyncedInactiveParticipants
{
    NSMutableOrderedSet *set = [self.mutableLastServerSyncedActiveParticipants mutableCopy];
    [set minusOrderedSet:self.otherActiveParticipants];
    return set;
}

- (NSOrderedSet *)unsyncedActiveParticipants
{
    NSMutableOrderedSet *set = [self.otherActiveParticipants mutableCopy];
    [set minusOrderedSet:self.mutableLastServerSyncedActiveParticipants];
    return set;
}

@end



@implementation ZMConversation (DownloadedMessagesGaps)

- (void)addEventToDownloadedEvents:(ZMEventID *)eventID timeStamp:(NSDate *)timeStamp;
{
    if(eventID == nil) {
        return;
    }
    self.downloadedMessageIDs = [self.downloadedMessageIDs setByAddingRange:[[ZMEventIDRange alloc] initWithEventIDs:@[eventID]]];
    
    if (timeStamp != nil) {
        if (self.lastReadEventID != nil && [eventID isEqualToEventID:self.lastReadEventID]) {
            if ([self updateLastReadServerTimeStampIfNeededWithTimeStamp:timeStamp andSync:NO]) {
                [self didUpdateConversationWhileFetchingUnreadMessages];
            }
        }
        if (self.clearedEventID != nil) {
            if ([eventID isEqualToEventID:self.clearedEventID]) {
                [self updateClearedServerTimeStampIfNeeded:timeStamp andSync:NO];
            }
            if (self.clearedTimeStamp == nil  && eventID.major == (self.clearedEventID.major+1)) {
                // when setting the clearedEventID, we are closing the gap and won't download the clearedEvent again
                // therefore we will never set an initial clearedTimeStamp
                // we approximate here by setting to a time close the first new event
                [self updateClearedServerTimeStampIfNeeded:[timeStamp dateByAddingTimeInterval:-1] andSync:NO];
            }
        }
    }
}

- (void)addEventRangeToDownloadedEvents:(ZMEventIDRange *)eventIDRange;
{
    self.downloadedMessageIDs = [self.downloadedMessageIDs setByAddingRange:eventIDRange];
}

- (ZMEventIDRange *)lastEventIDGapForVisibleWindow:(ZMEventIDRange *)visibleWindow;
{
    ZMEventIDRange *window = [self windowWithVisibleWindow:visibleWindow];
    return [self lastGapInsideWindow:window lastMajor:window.oldestMessage.major windowBleed:ZMLeadingEventIDWindowBleed];
}

- (ZMEventIDRange *)eventIDRangeForEntireConversation
{
    ZMEventID *firstEvent = self.clearedEventID ? self.clearedEventID : [ZMEventID eventIDWithMajor:1 minor:0];
    ZMEventID *lastEvent = self.lastEventID;
    
    return [[ZMEventIDRange alloc] initWithEventIDs:@[firstEvent, lastEvent]];
}

- (ZMEventIDRange *)lastEventIDGap
{
    if(self.lastEventID == nil) {
        return nil;
    } else {
        return [self lastGapInsideWindow:[self eventIDRangeForEntireConversation] lastMajor:self.lastEventID.major windowBleed:0];
    }
}

- (ZMEventIDRange *)windowWithVisibleWindow:(ZMEventIDRange *)visibleWindow
{
    if (self.lastEventID == nil) {
        return nil;
    }
    ZMEventIDRange *window = [[ZMEventIDRange alloc] init];
    [window addEvent:self.lastEventID];
    if (self.lastReadEventID) {
        [window addEvent:self.lastReadEventID];
    }
    if(visibleWindow) {
        [window mergeRange:visibleWindow];
    }
    return window;
}

- (ZMEventIDRange *)lastGapInsideWindow:(ZMEventIDRange *)window lastMajor:(uint64_t)lastMajor windowBleed:(NSUInteger)windowBleed
{
    uint64_t lowerBound = 1;
    if( windowBleed < lastMajor) {
        lowerBound = lastMajor - windowBleed;
    }
    [window addEvent:[[ZMEventID alloc] initWithMajor:lowerBound minor:0]];
    
    ZMEventIDRange *gap = ((self.downloadedMessageIDs != nil) ? [self.downloadedMessageIDs lastGapWithinWindow:window] : window);
    return gap;
}

@end



@implementation ZMConversation (ZMVoiceChannel)

- (ZMVoiceChannel *)voiceChannel;
{
    // The 'voiceChannel' is a transient property in the model.
    [self willAccessValueForKey:VoiceChannelKey];
    ZMVoiceChannel *voiceChannel = self.primitiveVoiceChannel;
    [self didAccessValueForKey:VoiceChannelKey];
    if (voiceChannel == nil) {
        if ((self.conversationType == ZMConversationTypeOneOnOne) ||
            (self.conversationType == ZMConversationTypeGroup))
        {
            voiceChannel = [[ZMVoiceChannel alloc] initWithConversation:self];
            self.primitiveVoiceChannel = voiceChannel;
        }
    }
    return voiceChannel;
}

@end




@implementation ZMConversation (KeyValueValidation)

- (BOOL)validateUserDefinedName:(NSString **)ioName error:(NSError **)outError
{
    return [ZMStringLengthValidator validateValue:ioName mimimumStringLength:1 maximumSringLength:64 error:outError];
}

@end


@implementation ZMConversation (Connections)

- (NSString *)connectionMessage;
{
    return self.connection.message;
}

@end





@implementation NSUUID (ZMSelfConversation)

- (BOOL)isSelfConversationRemoteIdentifierInContext:(NSManagedObjectContext *)moc;
{
    // The self conversation has the same remote ID as the self user:
    return [self isSelfUserRemoteIdentifierInContext:moc];
}

@end



@implementation ZMConversation (Optimization)

+ (void)refreshObjectsThatAreNotNeededInSyncContext:(NSManagedObjectContext *)managedObjectContext;
{

    NSMutableArray *messagesToKeep = [NSMutableArray array];
    NSMutableArray *conversationsToKeep = [NSMutableArray array];
    NSMutableSet *usersToKeep = [NSMutableSet set];
    
    // make sure that the Set is not mutated while being enumerated
    NSSet *registeredObjects = managedObjectContext.registeredObjects;
    
    // gather messages to keep
    for(NSManagedObject *obj in registeredObjects) {
        if(!obj.isFault && [obj isKindOfClass:ZMConversation.class]) {
            ZMConversation *conversation = (ZMConversation *)obj;
            [messagesToKeep addObjectsFromArray:[conversation messagesNotToRefreshBecauseNeededForSorting].allObjects];
            
            if(conversation.shouldNotBeRefreshed) {
                [conversationsToKeep addObject:conversation];
                [usersToKeep unionSet:conversation.otherActiveParticipants.set];
            }
        }
    }
    [usersToKeep addObject:[ZMUser selfUserInContext:managedObjectContext]];
    
    // turn into a fault
    for(NSManagedObject *obj in registeredObjects) {
        if(!obj.isFault) {
            
            const BOOL isUser = [obj isKindOfClass:ZMUser.class];
            const BOOL isMessage = [obj isKindOfClass:ZMMessage.class];
            const BOOL isConversation = [obj isKindOfClass:ZMConversation.class];
            
            const BOOL isOfTypeToBeRefreshed = isUser || isMessage || isConversation;
            
            if((isMessage && [messagesToKeep indexOfObjectIdenticalTo:obj] != NSNotFound) ||
               (isConversation && [conversationsToKeep indexOfObjectIdenticalTo:obj] != NSNotFound) ||
               (isUser && [usersToKeep.allObjects indexOfObjectIdenticalTo:obj] != NSNotFound) ||
               !isOfTypeToBeRefreshed
            )
            {
                continue;
            }
            [managedObjectContext refreshObject:obj mergeChanges:obj.hasChanges];
        }
    }
}


- (NSSet *)messagesNotToRefreshBecauseNeededForSorting
{
    NSMutableSet *messagesToKeep = [NSMutableSet set];
    
    const static NSUInteger NumberOfMessagesToKeep = 3;
    
    if(![self hasFaultForRelationshipNamed:ZMConversationMessagesKey])
    {
        const NSUInteger length = self.messages.count;
        if(length == 0) {
            return [NSSet set];
        }
        NSUInteger currentIndex = length-1;
        const NSUInteger keepUntilIndex = (length-1 >= NumberOfMessagesToKeep) // avoid overflow
        ? (length-1 - NumberOfMessagesToKeep)
        : length-1;
        
        while(YES) { // not using a for loop because when hitting 0, --i would make it overflow and wrap
            [messagesToKeep addObject:self.messages[currentIndex]];
            if(currentIndex == keepUntilIndex) {
                break;
            }
            --currentIndex;
        };
    }
    
    return messagesToKeep;
}

- (BOOL)shouldNotBeRefreshed
{
    static const int HOUR_IN_SEC = 60 * 60;
    static const NSTimeInterval STALENESS = -36 * HOUR_IN_SEC;
    return (self.isFault) || (self.lastModifiedDate == nil) || (self.lastModifiedDate.timeIntervalSinceNow > STALENESS);
}

@end



@implementation ZMConversation (History)

- (BOOL)hasClearedMessageHistory
{
    return self.clearedEventID != nil;
}

- (BOOL)hasDownloadedMessageHistory
{
    return self.lastEventIDGap == nil && (self.lastEventID != nil || self.lastServerTimeStamp != nil);
}

- (void)clearMessageHistory
{
    self.isArchived = YES;
    
    self.lastReadEventID = self.lastEventID;
    self.clearedEventID = self.lastEventID;
    
    self.clearedTimeStamp = self.lastServerTimeStamp; // the setter of this deletes all messages
    self.lastReadServerTimeStamp = self.lastServerTimeStamp;
}

- (void)revealClearedConversation
{
    self.isArchived = NO;
}

@end
