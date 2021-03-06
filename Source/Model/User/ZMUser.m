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
@import ZMUtilities;
@import Cryptobox;
@import ZMProtos;
@import ZMTransport;

#import "ZMUser+Internal.h"
#import "NSManagedObjectContext+zmessaging.h"
#import "ZMUser+Internal.h"
#import "ZMConnection+Internal.h"
#import "ZMConversation+Internal.h"
#import "ZMUserDisplayNameGenerator+Internal.h"
#import "NSString+ZMPersonName.h"
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonCryptoError.h>
#import "NSPredicate+ZMSearch.h"
#import "ZMAddressBookContact.h"
#import <ZMCDataModel/ZMCDataModel-Swift.h>

static NSString *const ZMPersistedClientIdKey = @"PersistedClientId";

static NSString *const AccentKey = @"accentColorValue";
static NSString *const SelfUserObjectIDAsStringKey = @"SelfUserObjectID";
static NSString *const SelfUserObjectIDKey = @"ZMSelfUserManagedObjectID";
static NSString *const SessionObjectIDKey = @"ZMSessionManagedObjectID";
static NSString *const SessionObjectIDAsStringKey = @"SessionObjectID";
static NSString *const SelfUserKey = @"ZMSelfUser";
static NSString *const NormalizedNameKey = @"normalizedName";
static NSString *const NormalizedEmailAddressKey = @"normalizedEmailAddress";
static NSString *const RemoteIdentifierKey = @"remoteIdentifier";

static NSString *const ConversationsCreatedKey = @"conversationsCreated";
static NSString *const ActiveConversationsKey = @"activeConversations";
static NSString *const ActiveCallConversationsKey = @"activeCallConversations";
static NSString *const ConnectionKey = @"connection";
static NSString *const EmailAddressKey = @"emailAddress";
static NSString *const PhoneNumberKey = @"phoneNumber";
static NSString *const InactiveConversationsKey = @"inactiveConversations";
static NSString *const LastServerSyncedActiveConversationsKey = @"lastServerSyncedActiveConversations";
static NSString *const LocalMediumRemoteIdentifierDataKey = @"localMediumRemoteIdentifier_data";
static NSString *const LocalMediumRemoteIdentifierKey = @"localMediumRemoteIdentifier";
static NSString *const LocalSmallProfileRemoteIdentifierKey = @"localSmallProfileRemoteIdentifier";
static NSString *const LocalSmallProfileRemoteIdentifierDataKey = @"localSmallProfileRemoteIdentifier_data";
static NSString *const MediumRemoteIdentifierDataKey = @"mediumRemoteIdentifier_data";
static NSString *const MediumRemoteIdentifierKey = @"mediumRemoteIdentifier";
static NSString *const SmallProfileRemoteIdentifierDataKey = @"smallProfileRemoteIdentifier_data";
static NSString *const SmallProfileRemoteIdentifierKey = @"smallProfileRemoteIdentifier";
static NSString *const OriginalProfileImageDataKey = @"originalProfileImageData";
static NSString *const NameKey = @"name";
static NSString *const ImageMediumDataKey = @"imageMediumData";
static NSString *const ImageSmallProfileDataKey = @"imageSmallProfileData";
static NSString *const SystemMessagesKey = @"systemMessages";
static NSString *const ShowingUserAddedKey = @"showingUserAdded";
static NSString *const ShowingUserRemovedKey = @"showingUserRemoved";
static NSString *const UserClientsKey = @"clients";


@interface ZMBoxedSelfUser : NSObject

@property (nonatomic, weak) ZMUser *selfUser;

@end



@implementation ZMBoxedSelfUser
@end

@interface ZMBoxedSession : NSObject

@property (nonatomic, weak) ZMSession *session;

@end



@implementation ZMBoxedSession
@end


@implementation ZMSession

@dynamic selfUser;

+ (NSArray *)defaultSortDescriptors;
{
    return nil;
}

+ (NSString *)entityName
{
    return @"Session";
}

+ (BOOL)hasLocallyModifiedDataFields
{
    return NO;
}

@end


@interface ZMUser ()

@property (nonatomic) NSString *normalizedName;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) ZMAccentColor accentColorValue;
@property (nonatomic, copy) NSString *emailAddress;
@property (nonatomic, copy) NSData *imageMediumData;
@property (nonatomic, copy) NSData *imageSmallProfileData;
@property (nonatomic, copy) NSString *phoneNumber;
@property (nonatomic, copy) NSString *normalizedEmailAddress;

@property (nonatomic, readonly) UserClient *selfClient;

@end



@implementation ZMUser


- (BOOL)isSelfUser
{
    return self == [self.class selfUserInContext:self.managedObjectContext];
}

+ (NSString *)entityName;
{
    return @"User";
}

+ (NSString *)sortKey
{
    return NormalizedNameKey;
}

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    // The UI can never insert users. A newly inserted user will always have to be sync'd
    // with data from the backend. Not that -updateWithTransportData:authoritative: will
    // clear this flag.
    self.needsToBeUpdatedFromBackend = YES;
}

@dynamic accentColorValue;
@dynamic emailAddress;
@dynamic imageMediumData;
@dynamic imageSmallProfileData;
@dynamic name;
@dynamic normalizedEmailAddress;
@dynamic normalizedName;
@dynamic phoneNumber;
@dynamic originalProfileImageData;
@dynamic clients;

- (UserClient *)selfClient
{
    NSString *persistedClientId = [self.managedObjectContext persistentStoreMetadataForKey:ZMPersistedClientIdKey];
    if (persistedClientId == nil) {
        return nil;
    }
    return [self.clients.allObjects firstObjectMatchingWithBlock:^BOOL(UserClient *aClient) {
        return [aClient.remoteIdentifier isEqualToString:persistedClientId];
    }];
}

- (NSData *)imageMediumData
{
    return [self imageDataForFormat:ZMImageFormatMedium];
}

- (void)setImageMediumData:(NSData *)imageMediumData
{
    [self setImageData:imageMediumData forFormat:ZMImageFormatMedium properties:nil];
}

- (NSData *)imageSmallProfileData
{
    return [self imageDataForFormat:ZMImageFormatProfile];
}

- (void)setImageSmallProfileData:(NSData *)imageSmallProfileData
{
    [self setImageData:imageSmallProfileData forFormat:ZMImageFormatProfile properties:nil];
}

- (NSString *)imageMediumIdentifier;
{
    NSUUID *uuid = self.localMediumRemoteIdentifier;
    return uuid.UUIDString ?: @"";
}

- (NSString *)imageSmallProfileIdentifier;
{
    NSUUID *uuid = self.localSmallProfileRemoteIdentifier;
    return uuid.UUIDString ?: @"";
}

- (NSString *)displayName;
{
    NSString *displayName = [self.managedObjectContext.displayNameGenerator displayNameForUser:self];
//    VerifyReturnValue(displayName != nil, @"");
    return displayName;
}

- (NSString *)initials
{
    NSString *initials = [self.managedObjectContext.displayNameGenerator initialsForUser:self];
    VerifyReturnValue(initials != nil, @"");    
    return initials;
}


- (ZMConversation *)oneToOneConversation
{
    return self.connection.conversation;
}


- (BOOL)canBeConnected;
{
    return ! self.isConnected && ! self.isPendingApprovalByOtherUser;
}

- (BOOL)isConnected;
{
    return self.connection != nil && self.connection.status == ZMConnectionStatusAccepted;
}

- (NSUInteger)totalCommonConnections
{
    return 0;
}

- (NSOrderedSet *)topCommonConnections
{
    return [NSOrderedSet orderedSet];
}

+ (NSSet *)keyPathsForValuesAffectingIsConnected
{
    return [NSSet setWithObjects:ConnectionKey, @"connection.status", nil];
}

- (void)connectWithMessageText:(NSString *)text completionHandler:(dispatch_block_t)handler;
{
    if(self.connection == nil || self.connection.status == ZMConnectionStatusCancelled) {
        ZMConversation *existingConversation;
        if (self.connection.status == ZMConnectionStatusCancelled) {
            existingConversation = self.connection.conversation;
            self.connection = nil;
        }
        self.connection = [ZMConnection insertNewSentConnectionToUser:self existingConversation:existingConversation];
        self.connection.message = text;
    }
    else {
        NOT_USED(text);
        switch (self.connection.status) {
            case ZMConnectionStatusInvalid:
                self.connection.lastUpdateDate = [NSDate date];
                self.connection.status = ZMConnectionStatusSent;
                break;
            case ZMConnectionStatusAccepted:
            case ZMConnectionStatusSent:
            case ZMConnectionStatusCancelled:
                // Do nothing
                break;
            case ZMConnectionStatusPending:
            case ZMConnectionStatusIgnored:
            case ZMConnectionStatusBlocked:
                self.connection.status = ZMConnectionStatusAccepted;
                if(self.connection.conversation.conversationType == ZMConversationTypeConnection) {
                    self.connection.conversation.conversationType = ZMConversationTypeOneOnOne;
                }
                break;
                
        }
    }
    if (handler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler();
        });
    }
}

- (NSString *)connectionRequestMessage;
{
    return self.connection.message;
}

+ (NSSet *)keyPathsForValuesAffectingConnectionRequestMessage {
    return [NSSet setWithObject:@"connection.message"];
}


- (NSSet<UserClient *> *)clientsRequiringUserAttention
{
    NSMutableSet *clientsRequiringUserAttention = [NSMutableSet set];
    
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    
    for (UserClient *userClient in self.clients) {
        if (userClient.needsToNotifyUser && ! [selfUser.selfClient.trustedClients containsObject:userClient]) {
            [clientsRequiringUserAttention addObject:userClient];
        }
    }
    
    return clientsRequiringUserAttention;
}

@end



@implementation ZMUser (Internal)

@dynamic activeConversations;
@dynamic inactiveConversations;
@dynamic normalizedName;
@dynamic connection;
@dynamic showingUserAdded;
@dynamic showingUserRemoved;

- (NSArray *)keysTrackedForLocalModifications
{
    if(self.isSelfUser) {
        return [super keysTrackedForLocalModifications];
    }
    else {
        return @[];
    }
}

- (NSSet *)ignoredKeys;
{
    static NSSet *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableSet *ignoredKeys = [[super ignoredKeys] mutableCopy];
        [ignoredKeys addObjectsFromArray:@[
                                           NormalizedNameKey,
                                           ConversationsCreatedKey,
                                           ActiveConversationsKey,
                                           ActiveCallConversationsKey,
                                           ConnectionKey,
                                           ConversationsCreatedKey,
                                           InactiveConversationsKey,
                                           LastServerSyncedActiveConversationsKey,
                                           LocalMediumRemoteIdentifierDataKey,
                                           LocalSmallProfileRemoteIdentifierDataKey,
                                           NormalizedEmailAddressKey,
                                           NormalizedNameKey,
                                           OriginalProfileImageDataKey,
                                           SystemMessagesKey,
                                           UserClientsKey,
                                           ShowingUserAddedKey,
                                           ShowingUserRemovedKey
                                           ]];
        keys = [ignoredKeys copy];
    });
    return keys;
}

+ (instancetype)userWithRemoteID:(NSUUID *)UUID createIfNeeded:(BOOL)create inContext:(NSManagedObjectContext *)moc;
{
    // We must only ever call this on the sync context. Otherwise, there's a race condition
    // where the UI and sync contexts could both insert the same user (same UUID) and we'd end up
    // having two duplicates of that user, and we'd have a really hard time recovering from that.
    //
    RequireString(! create || moc.zm_isSyncContext, "Race condition!");
    
    ZMUser *result = [self fetchObjectWithRemoteIdentifier:UUID inManagedObjectContext:moc];
    
    if (result != nil) {
        return result;
    } else if(create) {
        ZMUser *user = [ZMUser insertNewObjectInManagedObjectContext:moc];
        user.remoteIdentifier = UUID;
        return user;
    }
    else {
        return nil;
    }
}

+ (NSOrderedSet <ZMUser *> *)usersWithRemoteIDs:(NSOrderedSet <NSUUID *>*)UUIDs inContext:(NSManagedObjectContext *)moc;
{
    
    return [self fetchObjectsWithRemoteIdentifiers:UUIDs inManagedObjectContext:moc];
}

- (NSUUID *)remoteIdentifier;
{
    return [self transientUUIDForKey:@"remoteIdentifier"];
}

- (void)setRemoteIdentifier:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:@"remoteIdentifier"];
}

+ (ZMAccentColor)accentColorFromPayloadValue:(NSNumber *)payloadValue
{
    ZMAccentColor color = (ZMAccentColor) payloadValue.intValue;
    if ((color <= ZMAccentColorUndefined) || (ZMAccentColorMax < color)) {
        color = (ZMAccentColor) (arc4random_uniform(ZMAccentColorMax - 1) + 1);
    }
    return color;
}

- (void)updateWithTransportData:(NSDictionary *)transportData authoritative:(BOOL)authoritative
{
    NSUUID *remoteID = [transportData[@"id"] UUID];
    if (self.remoteIdentifier == nil) {
        self.remoteIdentifier = remoteID;
    } else {
        RequireString([self.remoteIdentifier isEqual:remoteID], "User ids do not match in update: %s vs. %s",
                      remoteID.transportString.UTF8String,
                      self.remoteIdentifier.transportString.UTF8String);
    }

    NSString *name = [transportData optionalStringForKey:@"name"];
    if (name != nil || authoritative) {
        self.name = name;
    }
    
    NSString *email = [transportData optionalStringForKey:@"email"];
    if (email != nil || authoritative) {
        self.emailAddress = email;
    }
    
    NSString *phone = [transportData optionalStringForKey:@"phone"];
    if (phone != nil || authoritative) {
        self.phoneNumber = phone;
    }
    
    NSNumber *accentId = [transportData optionalNumberForKey:@"accent_id"];
    if (accentId != nil || authoritative) {
        self.accentColorValue = [ZMUser accentColorFromPayloadValue:accentId];
    }
    
    NSArray *picture = [transportData optionalArrayForKey:@"picture"];
    if ((picture != nil || authoritative) && ![self hasLocalModificationsForKeys:[NSSet setWithArray:@[ImageMediumDataKey, ImageSmallProfileDataKey]]]) {
        [self updateImageWithTransportData:picture];
    }
    
    // We intentionally ignore the preview data.
    //
    // Need to see if we're changing the resolution, but it's currently way too small
    // to be of any use.
    
    if (authoritative) {
        self.needsToBeUpdatedFromBackend = NO;
    }
    
    [self updatePotentialGapSystemMessagesIfNeeded];
}

- (void)updatePotentialGapSystemMessagesIfNeeded
{
    for (ZMSystemMessage *systemMessage in self.showingUserAdded) {
        [systemMessage updateNeedsUpdatingUsersIfNeeded];
    }
    
    for (ZMSystemMessage *systemMessage in self.showingUserRemoved) {
        [systemMessage updateNeedsUpdatingUsersIfNeeded];
    }
}

- (void)updateImageWithTransportData:(NSArray *)transportData;
{
    if (transportData.count == 0) {
        self.mediumRemoteIdentifier = nil;
        self.smallProfileRemoteIdentifier = nil;
        self.imageCorrelationIdentifier = nil;
        self.imageMediumData = nil;
        self.imageSmallProfileData = nil;
        return;
    }
    
    for (NSDictionary *picture in transportData) {
        if (! [picture isKindOfClass:[NSDictionary class]]) {
            ZMLogError(@"Invalid picture data in user info.");
            continue;
        }
        NSDictionary *info = [picture dictionaryForKey:@"info"];
        if ([[info stringForKey:@"tag"] isEqualToString:@"medium"]) {
            self.mediumRemoteIdentifier = [picture uuidForKey:@"id"];
        }
        else if ([[info stringForKey:@"tag"] isEqualToString:@"smallProfile"]) {
            self.smallProfileRemoteIdentifier = [picture uuidForKey:@"id"];
        }
    }
}

- (NSDictionary *)pictureDataWithTag:(NSString *)tag inTransportData:(NSDictionary *)transportData
{
    NSArray *pictures = [transportData optionalArrayForKey:@"picture"];
    if (pictures == nil) {
        return nil;
    }
    for (NSDictionary *pictureData in [pictures asDictionaries]) {
        if ([[[pictureData dictionaryForKey:@"info"] stringForKey:@"tag"] isEqualToString:tag]) {
            return pictureData;
        }
    }
    return nil;
}

+ (NSPredicate *)predicateForObjectsThatNeedToBeUpdatedUpstream;
{
    NSPredicate *basePredicate = [super predicateForObjectsThatNeedToBeUpdatedUpstream];
    NSPredicate *needsToBeUpdated = [NSPredicate predicateWithFormat:@"needsToBeUpdatedFromBackend == 0"];
    NSPredicate *nilOrNotNilRemoteIdentifiers = [NSPredicate predicateWithFormat:@"(%K == nil && %K == nil) || (%K != nil && %K != nil)",
                       SmallProfileRemoteIdentifierDataKey, MediumRemoteIdentifierDataKey,
                       SmallProfileRemoteIdentifierDataKey, MediumRemoteIdentifierDataKey
                    ];
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[basePredicate, needsToBeUpdated, nilOrNotNilRemoteIdentifiers]];
}

+ (NSPredicate *)predicateForConnectedUsersWithSearchString:(NSString *)searchString
{
    return [self predicateForUsersWithSearchString:searchString
                           connectionStatusInArray:@[@(ZMConnectionStatusAccepted)]];
}

+ (NSPredicate *)predicateForUsersWithSearchString:(NSString *)searchString
                           connectionStatusInArray:(NSArray<NSNumber *> *)connectionStatusArray
{
    NSString *normalizedQueryString = [searchString normalizedString];
    NSString *normalizedEmailQueryString = [searchString normalizedEmailaddress];
    
    NSPredicate *statusPredicate = [NSPredicate predicateWithFormat:@"(%K.status IN (%@))",
                                    ConnectionKey, connectionStatusArray];
    
    NSPredicate *predicate;
    
    if(searchString.length > 0) {
        NSPredicate *namePredicate = [NSPredicate predicateWithFormatDictionary:@{NormalizedNameKey : @"%K MATCHES %@"}
                                                           matchingSearchString:normalizedQueryString];
        NSPredicate *emailPredicate = [NSPredicate predicateWithFormat: @"%K == %@",
                                       NormalizedEmailAddressKey, normalizedEmailQueryString];
        NSPredicate *searchPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[emailPredicate, namePredicate]];
        predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[searchPredicate, statusPredicate]];
    }
    else {
        predicate = statusPredicate;
    }
    
    return predicate;
}

@end


@implementation ZMUser (SelfUser)

+ (NSManagedObjectID *)storedObjectIdForUserInfoKey:(NSString *)objectIdKey persistedMetadataKey:(NSString *)metadataKey inContext:(NSManagedObjectContext *)moc
{
    NSManagedObjectID *moid = moc.userInfo[objectIdKey];
    if (moid == nil) {
        NSString *moidString = [moc persistentStoreMetadataForKey:metadataKey];
        if (moidString != nil) {
            NSURL *moidURL = [NSURL URLWithString:moidString];
            if (moidURL != nil) {
                moid = [moc.persistentStoreCoordinator managedObjectIDForURIRepresentation:moidURL];
                if (moid != nil) {
                    moc.userInfo[objectIdKey] = moid;
                }
            }
        }
    }
    return moid;
}

+ (ZMUser *)obtainCachedSessionById:(NSManagedObjectID *)moid inContext:(NSManagedObjectContext *)moc
{
    ZMUser *selfUser;
    if (moid != nil) {
        // It's ok for this to fail -- it will if the object is not around.
        ZMSession *session = (ZMSession *)[moc existingObjectWithID:moid error:NULL];
        Require((session == nil) || [session isKindOfClass: [ZMSession class]]);
        selfUser = session.selfUser;
    }
    return selfUser;
}

+ (ZMUser *)obtainCachedSelfUserById:(NSManagedObjectID *)moid inContext:(NSManagedObjectContext *)moc
{
    ZMUser *selfUser;
    if (moid != nil) {
        // It's ok for this to fail -- it will if the object is not around.
        NSManagedObject *result = [moc existingObjectWithID:moid error:NULL];
        Require((result == nil) || [result isKindOfClass: [ZMUser class]]);
        selfUser = (ZMUser *)result;
    }
    return selfUser;
}

+ (ZMUser *)createSessionIfNeededInContext:(NSManagedObjectContext *)moc withSelfUser:(ZMUser *)selfUser
{
    //clear old keys
    [moc.userInfo removeObjectForKey:SelfUserObjectIDKey];
    [moc setPersistentStoreMetadata:nil forKey:SelfUserObjectIDAsStringKey];

    NSError *error;

    //if there is no already session object than create one
    ZMSession *session = (ZMSession *)[moc executeFetchRequestOrAssert:[ZMSession sortedFetchRequest]].firstObject;
    if (session == nil) {
        session = [ZMSession insertNewObjectInManagedObjectContext:moc];
        RequireString([moc obtainPermanentIDsForObjects:@[session] error:&error],
                      "Failed to get ID for self user: %lu", (long) error.code);
    }
    
    //if there is already user in session, don't create new
    selfUser = selfUser ?: session.selfUser;
    
    if (selfUser == nil) {
        selfUser = [ZMUser insertNewObjectInManagedObjectContext:moc];
        RequireString([moc obtainPermanentIDsForObjects:@[selfUser] error:&error],
                      "Failed to get ID for self user: %lu", (long) error.code);
    }

    session.selfUser = selfUser;
    
    //store session object id in persistent metadata, so we can retrieve it from other context
    moc.userInfo[SessionObjectIDKey] = session.objectID;
    [moc setPersistentStoreMetadata:session.objectID.URIRepresentation.absoluteString forKey:SessionObjectIDAsStringKey];
    // This needs to be a 'real' save, to make sure we push the metadata:
    RequireString([moc save:&error], "Failed to save self user: %lu", (long) error.code);

    return selfUser;
}

+ (ZMUser *)unboxSelfUserFromContextUserInfo:(NSManagedObjectContext *)moc
{
    ZMBoxedSelfUser *boxed = moc.userInfo[SelfUserKey];
    return boxed.selfUser;
}

+ (void)boxSelfUser:(ZMUser *)selfUser inContextUserInfo:(NSManagedObjectContext *)moc
{
    ZMBoxedSelfUser *boxed = [[ZMBoxedSelfUser alloc] init];
    boxed.selfUser = selfUser;
    moc.userInfo[SelfUserKey] = boxed;
}

+ (BOOL)hasSessionEntityInContext:(NSManagedObjectContext *)moc
{
    //In older client versions there is no Session entity (first model version )...
    return (moc.persistentStoreCoordinator.managedObjectModel.entitiesByName[[ZMSession entityName]] != nil);
}

+ (instancetype)selfUserInContext:(NSManagedObjectContext *)moc;
{
    // This method is a contention point.
    //
    // We're storing the object ID of the session (previously self user) (as a string) inside the store's metadata.
    // The metadata gets persisted, hence we're able to retrieve the session (self user) across launches.
    // Converting the string representation to an instance of NSManagedObjectID is not cheap.
    // We're hence caching the value inside the context's userInfo.
    
    //1. try to get boxed user from user info
    ZMUser *selfUser = [self unboxSelfUserFromContextUserInfo:moc];
    if (selfUser) {
        return selfUser;
    }
    
    // 2. try to get session object id by session key from user info or metadata
    NSManagedObjectID *moid = [self storedObjectIdForUserInfoKey:SessionObjectIDKey persistedMetadataKey:SessionObjectIDAsStringKey inContext:moc];
    if (moid == nil) {
        //3. try to get user object id by user id key from user info or metadata
        moid = [self storedObjectIdForUserInfoKey:SelfUserObjectIDKey persistedMetadataKey:SelfUserObjectIDAsStringKey inContext:moc];
        if (moid != nil) {
            //4. get user by it's object id
            selfUser = [self obtainCachedSelfUserById:moid inContext:moc];
            if (selfUser != nil) {
                //there can be no session object, create one and store self user in it
                (void)[self createSessionIfNeededInContext:moc withSelfUser:selfUser];
            }
        }
    }
    else {
        //4. get user from session by it's object id
        selfUser = [self obtainCachedSessionById:moid inContext:moc];
    }
    
    if (selfUser == nil) {
        //creat user and store it's id in metadata by session key
        selfUser = [self createSessionIfNeededInContext:moc withSelfUser:nil];
    }
    //5. box user and store box in user info by user key
    [self boxSelfUser:selfUser inContextUserInfo:moc];
    
    return selfUser;
}

@end


@implementation  ZMUser (Utilities)

+ (ZMUser<ZMEditableUser> *)selfUserInUserSession:(id<ZMManagedObjectContextProvider>)session
{
    VerifyReturnNil(session != nil);
    return [self selfUserInContext:session.managedObjectContext];
}

@end




@implementation ZMUser (Editable)

@dynamic originalProfileImageData;


- (void)setName:(NSString *)aName {
    
    [self willChangeValueForKey:NameKey];
    [self setPrimitiveValue:[aName copy] forKey:NameKey];
    [self didChangeValueForKey:NameKey];
    
    self.normalizedName = [self.name normalizedString];
}

- (void)setEmailAddress:(NSString *)anEmailAddress {
    
    [self willChangeValueForKey:EmailAddressKey];
    [self setPrimitiveValue:[anEmailAddress copy] forKey:EmailAddressKey];
    [self didChangeValueForKey:EmailAddressKey];
    
    self.normalizedEmailAddress = [self.emailAddress normalizedEmailaddress];
}

- (void)deleteProfileImage
{
    self.mediumRemoteIdentifier = nil;
    self.smallProfileRemoteIdentifier = nil;
    [self processingDidFinish];
    [self setLocallyModifiedKeys:[NSSet setWithObjects:MediumRemoteIdentifierDataKey, SmallProfileRemoteIdentifierDataKey, nil]];
    
    self.imageCorrelationIdentifier = nil;
}

- (void)setOriginalProfileImageData:(NSData *)data;
{
    VerifyReturn(data != nil);
    [self willChangeValueForKey:OriginalProfileImageDataKey];
    [self setPrimitiveValue:data forKey:OriginalProfileImageDataKey];
    [self didChangeValueForKey:OriginalProfileImageDataKey];
    
    self.imageCorrelationIdentifier = [NSUUID UUID];
}

@end





@implementation ZMUser (Connections)


- (BOOL)isBlocked
{
    return self.connection != nil && self.connection.status == ZMConnectionStatusBlocked;
}

+ (NSSet *)keyPathsForValuesAffectingIsBlocked
{
    return [NSSet setWithObjects:ConnectionKey, @"connection.status", nil];
}

- (BOOL)isIgnored
{
    return self.connection != nil && self.connection.status == ZMConnectionStatusIgnored;
}

+ (NSSet *)keyPathsForValuesAffectingIsIgnored
{
    return [NSSet setWithObjects:ConnectionKey, @"connection.status", nil];
}

- (BOOL)isPendingApprovalBySelfUser
{
    return self.connection != nil && (self.connection.status == ZMConnectionStatusPending ||
                                      self.connection.status == ZMConnectionStatusIgnored);
}

+ (NSSet *)keyPathsForValuesAffectingIsPendingApprovalBySelfUser
{
    return [NSSet setWithObjects:ConnectionKey, @"connection.status", nil];
}

- (BOOL)isPendingApprovalByOtherUser
{
    return self.connection != nil && self.connection.status == ZMConnectionStatusSent;
}

+ (NSSet *)keyPathsForValuesAffectingIsPendingApprovalByOtherUser
{
    return [NSSet setWithObjects:ConnectionKey, @"connection.status", nil];
}


- (void)accept;
{
    [self connectWithMessageText:nil completionHandler:nil];
}

//
// C.f. <https://github.com/zinfra/brig/blob/develop/doc/connections.md>
//

- (void)block;
{
    switch (self.connection.status) {
        case ZMConnectionStatusBlocked:
        case ZMConnectionStatusInvalid:
        case ZMConnectionStatusCancelled:
            // do nothing
            break;
            
        case ZMConnectionStatusIgnored:
        case ZMConnectionStatusAccepted:
        case ZMConnectionStatusPending:
        case ZMConnectionStatusSent:
            self.connection.status = ZMConnectionStatusBlocked;
            break;
    };
}

- (void)ignore;
{
    switch (self.connection.status) {
        case ZMConnectionStatusInvalid:
        case ZMConnectionStatusSent:
        case ZMConnectionStatusIgnored:
        case ZMConnectionStatusCancelled:
            // do nothing
            break;
        case ZMConnectionStatusBlocked:
        case ZMConnectionStatusAccepted:
        case ZMConnectionStatusPending:
            self.connection.status = ZMConnectionStatusIgnored;
            break;
            
    };
}

- (void)cancelConnectionRequest
{
    if (self.connection.status == ZMConnectionStatusSent) {
        self.connection.status = ZMConnectionStatusCancelled;
    }
}

- (BOOL)trusted
{
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    UserClient *selfClient = selfUser.selfClient;
    __block BOOL hasOnlyTrustedClients = YES;
    [self.clients enumerateObjectsUsingBlock:^(UserClient *client, BOOL * _Nonnull stop) {
        if (client != selfClient && ![selfClient.trustedClients containsObject:client]) {
            hasOnlyTrustedClients = NO;
            *stop = YES;
        }
    }];
    return hasOnlyTrustedClients;
}

- (BOOL)untrusted
{
    ZMUser *selfUser = [ZMUser selfUserInContext:self.managedObjectContext];
    UserClient *selfClient = selfUser.selfClient;
    __block BOOL hasUntrustedClients = NO;
    [self.clients enumerateObjectsUsingBlock:^(UserClient *client, BOOL * _Nonnull stop) {
        if (client != selfClient && ![selfClient.trustedClients containsObject:client]) {
            hasUntrustedClients = YES;
            *stop = YES;
        }
    }];
    return hasUntrustedClients;
}

@end



@implementation ZMUser (ImageData)

- (void)setImageData:(NSData *)imageData forFormat:(ZMImageFormat)format properties:(ZMIImageProperties * __unused)properties;
{
    //NOTE: default case is intentionally missing, to trigger a compile error when new image formats are added (so that we can decide whether we want to handle them or not)
    switch (format) {
        case ZMImageFormatMedium:
            [self setImageData:imageData forKey:ImageMediumDataKey format:format];
            break;
            
        case ZMImageFormatProfile:
            [self setImageData:imageData forKey:ImageSmallProfileDataKey format:format];
            break;

        case ZMImageFormatInvalid:
        case ZMImageFormatOriginal:
        case ZMImageFormatPreview:
            RequireString(NO, "Unexpected image format '%lu' set in user", (unsigned long)format);
            break;
    }
}

- (void)setImageData:(NSData *)imageData forKey:(NSString *)key format:(ZMImageFormat)format
{
    [self willChangeValueForKey:key];
    if (self.isSelfUser) {
        [self setPrimitiveValue:imageData forKey:key];
        
        if (self.originalProfileImageData != nil) {
            [self setLocallyModifiedKeys:[NSSet setWithObject:key]];
        }
    }
    else {
        switch (format) {
            case ZMImageFormatMedium: {
                [self.managedObjectContext.zm_userImageCache setLargeUserImage:self imageData:imageData]; // user image cache is thead safe
                break;
                
            }
            case ZMImageFormatProfile: {
                [self.managedObjectContext.zm_userImageCache setSmallUserImage:self imageData:imageData]; // user image cache is thead safe
                break;
            }
            default:
                RequireString(NO, "Unexpected image format '%lu' set in user", (unsigned long)format);
                break;
        }
    }
    [self didChangeValueForKey:key];
    [self.managedObjectContext saveOrRollback];
}


- (NSData *)imageDataForFormat:(ZMImageFormat)format;
{
    
    switch (format) {
        case ZMImageFormatMedium: {
            if(self.isSelfUser) {
                return [self primitiveValueForKey:ImageMediumDataKey];
            } else {
                return [self.managedObjectContext.zm_userImageCache largeUserImage:self]; // user image cache is thead safe
            }
        }
        case ZMImageFormatProfile: {
            if(self.isSelfUser) {
                return [self primitiveValueForKey:ImageSmallProfileDataKey];
            } else {
                return [self.managedObjectContext.zm_userImageCache smallUserImage:self]; // user image cache is thead safe
            }
        }
            
        case ZMImageFormatInvalid:
        case ZMImageFormatOriginal:
        case ZMImageFormatPreview:
            RequireString(NO, "Unexpected image format '%lu' requested from user", (unsigned long)format);
            break;
    }
    
    return nil;
}

- (BOOL)isInlineForFormat:(ZMImageFormat)format
{
    NOT_USED(format);
    return NO;
}


- (BOOL)isPublicForFormat:(ZMImageFormat)format
{
    NOT_USED(format);
    return YES;
}

- (BOOL)isUsingNativePushForFormat:(ZMImageFormat)format
{
    NOT_USED(format);
    return NO;
}

- (CGSize)originalImageSize
{
    return [ZMImagePreprocessor sizeOfPrerotatedImageWithData:self.originalProfileImageData];
}


- (NSOrderedSet *)requiredImageFormats;
{
    return [NSOrderedSet orderedSetWithObjects:@(ZMImageFormatMedium), @(ZMImageFormatProfile), nil];
}

- (NSData *)originalImageData;
{
    return self.originalProfileImageData;
}

- (void)processingDidFinish;
{
    if (self.originalProfileImageData != nil) {
        [self willChangeValueForKey:OriginalProfileImageDataKey];
        [self setPrimitiveValue:nil forKey:OriginalProfileImageDataKey];
        [self didChangeValueForKey:OriginalProfileImageDataKey];
        [self.managedObjectContext enqueueDelayedSave];
    }
}

- (NSUUID *)mediumRemoteIdentifier;
{
    return [self transientUUIDForKey:@"mediumRemoteIdentifier"];
}

- (void)setMediumRemoteIdentifier:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:@"mediumRemoteIdentifier"];
}

- (NSUUID *)smallProfileRemoteIdentifier;
{
    return [self transientUUIDForKey:@"smallProfileRemoteIdentifier"];
}

- (void)setSmallProfileRemoteIdentifier:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:@"smallProfileRemoteIdentifier"];
}



- (NSUUID *)imageCorrelationIdentifier;
{
    return [self transientUUIDForKey:@"imageCorrelationIdentifier"];
}

- (void)setImageCorrelationIdentifier:(NSUUID *)identifier;
{
    [self setTransientUUID:identifier forKey:@"imageCorrelationIdentifier"];
}


- (NSUUID *)localMediumRemoteIdentifier;
{
    return [self transientUUIDForKey:@"localMediumRemoteIdentifier"];
}

- (void)setLocalMediumRemoteIdentifier:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:@"localMediumRemoteIdentifier"];
}

- (NSUUID *)localSmallProfileRemoteIdentifier;
{
    return [self transientUUIDForKey:@"localSmallProfileRemoteIdentifier"];
}

- (void)setLocalSmallProfileRemoteIdentifier:(NSUUID *)remoteIdentifier;
{
    [self setTransientUUID:remoteIdentifier forKey:@"localSmallProfileRemoteIdentifier"];
}

+ (NSPredicate *)predicateForMediumImageNeedingToBeUpdatedFromBackend;
{
    return [NSPredicate predicateWithFormat:@"(%K != nil)", MediumRemoteIdentifierDataKey];
}

+ (NSPredicate *)predicateForSmallImageNeedingToBeUpdatedFromBackend;
{
    return [NSPredicate predicateWithFormat:@"(%K != nil)", SmallProfileRemoteIdentifierDataKey];
}

+ (NSPredicate *)predicateForUsersOtherThanSelf
{
    return [NSPredicate predicateWithFormat:@"isSelfUser != YES"];
}

+ (NSPredicate *)predicateForSelfUser
{
    return [NSPredicate predicateWithFormat:@"isSelfUser == YES"];
}

+ (NSPredicate *)predicateForMediumImageDownloadFilter
{
    NSPredicate *localIdIsOld = [NSPredicate predicateWithFormat:@"%K != %K", LocalMediumRemoteIdentifierDataKey, MediumRemoteIdentifierDataKey];
    NSPredicate *selfLocalIdIsOld = [NSCompoundPredicate andPredicateWithSubpredicates:@[[self predicateForSelfUser], localIdIsOld]];
    NSPredicate *imageNotInCache = [NSPredicate predicateWithBlock:^BOOL(ZMUser * _Nonnull user, NSDictionary<NSString *,id> * _Nullable bindings) {
        NOT_USED(bindings);
        return ! user.isSelfUser && user.imageMediumData == nil;
    }];
    
    return [NSCompoundPredicate orPredicateWithSubpredicates:@[selfLocalIdIsOld, imageNotInCache]];
}
+ (NSPredicate *)predicateForSmallImageDownloadFilter
{
    NSPredicate *localIdIsOld = [NSPredicate predicateWithFormat:@"%K != %K", LocalSmallProfileRemoteIdentifierDataKey,
                                 SmallProfileRemoteIdentifierDataKey];
    NSPredicate *selfLocalIdIsOld = [NSCompoundPredicate andPredicateWithSubpredicates:@[[self predicateForSelfUser], localIdIsOld]];
    NSPredicate *imageNotInCache = [NSPredicate predicateWithBlock:^BOOL(ZMUser * _Nonnull user, NSDictionary<NSString *,id> * _Nullable bindings) {
        NOT_USED(bindings);
        return ! user.isSelfUser && user.imageSmallProfileData == nil;
    }];
    
    return [NSCompoundPredicate orPredicateWithSubpredicates:@[selfLocalIdIsOld, imageNotInCache]];
}

@end



@implementation ZMUser (KeyValueValidation)

+ (BOOL)validateName:(NSString **)ioName error:(NSError **)outError
{
    // The backend limits to 128. We'll fly just a bit below the radar.
    return [ZMStringLengthValidator validateValue:ioName mimimumStringLength:2 maximumSringLength:100 error:outError];
}

+ (BOOL)validateAccentColorValue:(NSNumber **)ioAccent error:(NSError **)outError
{
    return [ZMAccentColorValidator validateValue:ioAccent error:outError];
}

+ (BOOL)validateEmailAddress:(NSString **)ioEmailAddress error:(NSError **)outError
{
    return [ZMEmailAddressValidator validateValue:ioEmailAddress error:outError];
}

+ (BOOL)validatePassword:(NSString **)ioPassword error:(NSError **)outError
{
    return [ZMStringLengthValidator validateValue:ioPassword mimimumStringLength:8 maximumSringLength:120 error:outError];
}

+ (BOOL)validatePhoneNumber:(NSString **)ioPhoneNumber error:(NSError **)outError
{
    if (ioPhoneNumber == NULL || [*ioPhoneNumber length] < 1) {
        return NO;
    }
    else {
        return [ZMPhoneNumberValidator validateValue:ioPhoneNumber error:outError];
    }
}

+ (BOOL)validatePhoneVerificationCode:(NSString **)ioVerificationCode error:(NSError **)outError
{
    if (*ioVerificationCode == nil) {
        return NO;
    }
    else {
        return [ZMStringLengthValidator validateValue:ioVerificationCode
                                  mimimumStringLength:6
                                   maximumSringLength:6
                                                error:outError];
    }
}

- (BOOL)validateValue:(id *)value forKey:(NSString *)key error:(NSError **)error
{
    if (self.isInserted) {
        // Self user gets inserted, no other users will. Ignore this case.
        //We does not need to validate selfUser for now, 'cuase it's not setup yet, i.e. it has empty name at this point
        return YES;
    }
    return [super validateValue:value forKey:key error:error];
}

- (BOOL)validateEmailAddress:(NSString **)ioEmailAddress error:(NSError **)outError
{
    return [ZMUser validateEmailAddress:ioEmailAddress error:outError];
}

- (BOOL)validateName:(NSString **)ioName error:(NSError **)outError
{
    return [ZMUser validateName:ioName error:outError];
}

- (BOOL)validateAccentColorValue:(NSNumber **)ioAccent error:(NSError **)outError
{
    return [ZMUser validateAccentColorValue:ioAccent error:outError];
}



@end




@implementation NSUUID (SelfUser)

- (BOOL)isSelfUserRemoteIdentifierInContext:(NSManagedObjectContext *)moc;
{
    return [[ZMUser selfUserInContext:moc].remoteIdentifier isEqual:self];
}

@end


@implementation ZMUser (Protobuf)

- (ZMUserId *)userId
{
    ZMUserIdBuilder *userIdBuilder = [ZMUserId builder];
    [userIdBuilder setUuid:[self.remoteIdentifier data]];
    return [userIdBuilder build];
}

@end


