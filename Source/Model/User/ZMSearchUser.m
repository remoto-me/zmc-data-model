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


@import ZMTransport;
@import ZMUtilities;

#import "ZMSearchUser+Internal.h"

#import "NSManagedObjectContext+zmessaging.h"
#import "NSManagedObjectContext+ZMSearchDirectory.h"
#import "ZMUser+Internal.h"
#import "ZMConnection+Internal.h"
#import "ZMPersonName.h"
#import "ZMAddressBookContact.h"

#import "ZMNotifications+Internal.h"
#import <ZMCDataModel/ZMCDataModel-Swift.h>

static NSCache *searchUserToSmallProfileImageCache;
static NSCache *searchUserToMediumImageCache;
static NSCache *searchUserToMediumAssetIDCache;

NSString *const ZMSearchUserMutualFriendsKey = @"mutual_friends";
NSString *const ZMSearchUserTotalMutualFriendsKey = @"total_mutual_friends";

@interface ZMSearchUser ()
{
    NSData *_imageSmallProfileData;
    NSString *_imageSmallProfileIdentifier;
    
    NSData *_imageMediumData;
}

@property (nonatomic) NSString *displayName;
@property (nonatomic) NSString *initials;
@property (nonatomic) NSString *name; //< name received from BE

@property (nonatomic) BOOL isConnected;
@property (nonatomic) ZMAccentColor accentColorValue;

@property (nonatomic, copy) NSString *connectionRequestMessage;
@property (nonatomic) BOOL isPendingApprovalByOtherUser;

@property (nonatomic, readonly) NSManagedObjectContext *syncMOC;
@property (nonatomic, readonly) NSManagedObjectContext *uiMOC;

@property (nonatomic) ZMUser *user;
@property (nonatomic) ZMAddressBookContact *contact;

@end



@interface ZMSearchUser (MediumImage_Private)

- (void)privateRequestMediumProfileImageInUserSession:(id<ZMManagedObjectContextProvider>)userSession;

@end



@implementation ZMSearchUser

- (instancetype)initWithName:(NSString *)name accentColor:(ZMAccentColor)color remoteID:(NSUUID *)remoteID user:(ZMUser *)user syncManagedObjectContext:(NSManagedObjectContext *)syncMOC uiManagedObjectContext:(NSManagedObjectContext *)uiMOC;
{
    self = [super init];
    if (self) {
        _user = user;
        _syncMOC = syncMOC;
        _uiMOC = uiMOC;
        if (self.user == nil) {
            _name = name;
            
            ZMPersonName *personName = [ZMPersonName personWithName:name];
            _initials = personName.initials;
            
            _accentColorValue =  color;
            _isConnected = NO;
            _remoteIdentifier = remoteID;
        }
//        CheckString(self.remoteIdentifier != nil, "No remote ID?");
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name accentColor:(ZMAccentColor)color remoteID:(NSUUID *)remoteID user:(ZMUser *)user userSession:(id<ZMManagedObjectContextProvider>)userSession;
{
    return [self initWithName:name accentColor:color remoteID:remoteID user:user syncManagedObjectContext:userSession.syncManagedObjectContext uiManagedObjectContext:userSession.managedObjectContext];
}

- (instancetype)initWithUser:(ZMUser *)user userSession:(id<ZMManagedObjectContextProvider>)userSession globalCommonConnections:(NSOrderedSet <ZMUser *> *)connections cachedCommonConnections:(ZMSuggestedUserCommonConnections *)cachedCommonConnections
{
    self = [self initWithName:user.name
                  accentColor:user.accentColorValue
                     remoteID:user.remoteIdentifier
                         user:user
                  userSession:userSession];
    if (nil != self) {
        // Read data from the cache if present
        if (cachedCommonConnections != nil && ![cachedCommonConnections isEmpty]) {
            self.totalCommonConnections = cachedCommonConnections.totalCommonConnections;
            self.topCommonConnections = [ZMSearchUser userTopCommonConnectionsWithConnectionIDs:cachedCommonConnections.topCommonConnectionsIDs
                                                                        globalCommonConnections:connections];
        }
        else {
            self.topCommonConnections = user.topCommonConnections;
            self.totalCommonConnections = user.totalCommonConnections;
        }
    }
    return self;
}

+ (NSArray <ZMSearchUser *> *)usersWithUsers:(NSArray <ZMUser *> *)users userSession:(id<ZMManagedObjectContextProvider>)userSession;
{
    VerifyReturnNil([users isKindOfClass:[NSArray class]]);
    NSMutableOrderedSet *connectionUUIDs = [[NSMutableOrderedSet alloc] init];
    NSMutableDictionary *cachedCommonConnections = [[NSMutableDictionary alloc] init];
    
    for (ZMUser *user in users) {
        ZMSuggestedUserCommonConnections *suggestedCommonConnections = [userSession.managedObjectContext.commonConnectionsForUsers objectForKey:user.remoteIdentifier];
        cachedCommonConnections[user.remoteIdentifier.UUIDString] = suggestedCommonConnections;
        [connectionUUIDs addObjectsFromArray:suggestedCommonConnections.topCommonConnectionsIDs.array];
    }
    
    NSOrderedSet *connections = [self commonConnectionsWithIds:connectionUUIDs inContext:userSession.managedObjectContext];
    NSMutableArray <ZMSearchUser *> *searchUsers = [[NSMutableArray alloc] init];
    
    for (ZMUser *user in users) {
        ZMSearchUser *searchUser = [[ZMSearchUser alloc] initWithUser:user userSession:userSession globalCommonConnections:connections cachedCommonConnections:cachedCommonConnections[user.remoteIdentifier.UUIDString]];
        if (searchUser != nil) {
            [searchUsers addObject:searchUser];
        }
    }
    
    return searchUsers;
}

- (instancetype)initWithPayload:(NSDictionary *)payload userSession:(id<ZMManagedObjectContextProvider>)userSession globalCommonConnections:(NSOrderedSet <ZMUser *> *)connections
{
    NSUUID *identifier = [payload optionalUuidForKey:@"id"];
    NSNumber *accentId = [payload optionalNumberForKey:@"accent_id"];
    ZMUser *existingUser = [ZMUser userWithRemoteID:identifier
                                     createIfNeeded:NO
                                          inContext:userSession.managedObjectContext];

    self = [self initWithName:payload[@"name"]
                  accentColor:[ZMUser accentColorFromPayloadValue:accentId]
                     remoteID:identifier
                         user:existingUser
                  userSession:userSession];
    
    
    if (nil != self) {
        if (payload[ZMSearchUserTotalMutualFriendsKey] == nil) {
            // Read data from the cache if present
            ZMSuggestedUserCommonConnections *cachedCommonConnections = [self.uiMOC.commonConnectionsForUsers objectForKey:self.remoteIdentifier];
            
            if (cachedCommonConnections != nil && ![cachedCommonConnections isEmpty]) {
                self.totalCommonConnections = cachedCommonConnections.totalCommonConnections;
                self.topCommonConnections = [ZMSearchUser userTopCommonConnectionsWithConnectionIDs:cachedCommonConnections.topCommonConnectionsIDs
                                                                            globalCommonConnections:connections];
            }
        } else {
            self.totalCommonConnections = [[payload optionalNumberForKey:ZMSearchUserTotalMutualFriendsKey] unsignedIntegerValue];
            NSArray *uuids = [[payload optionalArrayForKey:ZMSearchUserMutualFriendsKey] mapWithBlock:^NSData *(NSString *uuid) {
                return [NSUUID uuidWithTransportString:uuid].data;
            }];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", [ZMUser remoteIdentifierDataKey], uuids];
            self.topCommonConnections = [connections filteredOrderedSetUsingPredicate:predicate];
        }
    }
    
    
    return self;
}

+ (NSArray <ZMSearchUser *> *)usersWithPayloadArray:(NSArray <NSDictionary *> *)payloadArray userSession:(id<ZMManagedObjectContextProvider>)userSession;
{
    VerifyReturnNil([payloadArray isKindOfClass:[NSArray class]]);
    NSMutableOrderedSet *connectionUUIDs = [[NSMutableOrderedSet alloc] init];
    
    for (NSDictionary *payload in payloadArray) {
        [connectionUUIDs addObjectsFromArray:[payload optionalArrayForKey:ZMSearchUserMutualFriendsKey]];
    }
    
    NSOrderedSet *connections = [self commonConnectionsWithIds:connectionUUIDs inContext:userSession.managedObjectContext];
    NSMutableArray <ZMSearchUser *> *searchUsers = [[NSMutableArray alloc] init];
    
    for (NSDictionary *payload in payloadArray) {
        VerifyReturnNil([payload isKindOfClass:[NSDictionary class]]);
        VerifyReturnNil([payload uuidForKey:@"id"] != nil);
        ZMSearchUser *searchUser = [[ZMSearchUser alloc] initWithPayload:payload userSession:userSession globalCommonConnections:connections];
        if (searchUser != nil) {
            [searchUsers addObject:searchUser];
        }
    }
    
    return searchUsers;
}

+ (NSOrderedSet *)commonConnectionsWithIds:(NSOrderedSet *)set inContext:(NSManagedObjectContext *)moc
{
    NSOrderedSet *uuids = [set mapWithBlock:^id(NSString *commonUserUUIDString) {
        return [[NSUUID alloc] initWithUUIDString:commonUserUUIDString];
    }];
    return [ZMUser fetchObjectsWithRemoteIdentifiers:uuids inManagedObjectContext:moc];
}

+ (NSOrderedSet *)userTopCommonConnectionsWithConnectionIDs:(NSOrderedSet *)connectionIDs globalCommonConnections:(NSOrderedSet *)globalConnections
{
    NSArray *commonConnectionsUUIDData = [connectionIDs.array mapWithBlock:^NSData *(NSString *UUIDString) {
        return [[NSUUID alloc] initWithUUIDString:UUIDString].data;
    }];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@", [ZMUser remoteIdentifierDataKey], commonConnectionsUUIDData];
    return [globalConnections filteredOrderedSetUsingPredicate:predicate];
}

- (instancetype)initWithContact:(ZMAddressBookContact *)contact user:(ZMUser *)user userSession:(id<ZMManagedObjectContextProvider>)userSession
{
    self = [self initWithName:contact.name accentColor:ZMAccentColorUndefined remoteID:nil user:user userSession:userSession];
    
    if (self != nil) {
        _contact = contact;
    }
    
    return self;
}

- (NSString *)name
{
    return self.user ? self.user.name : _name;
}

- (NSString *)displayName
{
    return self.user ? self.user.displayName : _name;
}

- (NSString *)initials
{
    return self.user ? self.user.initials : _initials;
}

- (BOOL)isConnected;
{
    return self.user ? self.user.isConnected : _isConnected;
}

+ (NSSet *)keyPathsForValuesAffectingIsConnected
{
    return [NSSet setWithObjects:@"user", @"user.isConnected", nil];
}

- (ZMAccentColor)accentColorValue;
{
    return self.user ? self.user.accentColorValue : _accentColorValue;
}


- (NSUUID *)remoteIdentifier
{
    return self.user ? self.user.remoteIdentifier : _remoteIdentifier;
}

- (BOOL)hasCachedMediumAssetIDOrData
{
    return (self.imageMediumData != nil || self.mediumAssetID != nil);
}

- (BOOL)isLocalOrHasCachedProfileImageData;
{
    return (self.user != nil) || (self.imageSmallProfileData != nil && self.hasCachedMediumAssetIDOrData);
}

@synthesize isPendingApprovalByOtherUser = _isPendingApprovalByOtherUser;
- (BOOL)isPendingApprovalByOtherUser;
{
    return (self.user != nil) ? self.user.isPendingApprovalByOtherUser : _isPendingApprovalByOtherUser;
}

+ (NSSet *)keyPathsForValuesAffectingIsPendingApprovalByOtherUser
{
    return [NSSet setWithObjects:@"user.isPendingApprovalByOtherUser", @"user", nil];
}

- (void)connectWithMessageText:(NSString *)text completionHandler:(dispatch_block_t)handler;
{
    dispatch_block_t completionHandler = ^(){
        [self.uiMOC.globalManagedObjectContextObserver notifyUpdatedSearchUser:self];
        if (handler != nil) {
            handler();
        }
    };
    
    // Copy before switching thread / queue:
    handler = [handler copy];
    text = [text copy];
    
    if (! [self canBeConnected]) {
        if (handler != nil) {
            handler();
        }
        return;
    }
    
    self.isPendingApprovalByOtherUser = YES;
    self.connectionRequestMessage = text;
    
    if (self.user != nil) {
        [self.user connectWithMessageText:text completionHandler:completionHandler];
    } else {
        CheckString(self.syncMOC != nil,
                    "No user session / sync context.");
        NSString *name = [self.name copy];
        ZMAccentColor accentColorValue = self.accentColorValue;
        [self.syncMOC performGroupedBlock:^{
            ZMUser *user = [ZMUser userWithRemoteID:self.remoteIdentifier createIfNeeded:YES inContext:self.syncMOC];
            user.name = name;
            user.accentColorValue = accentColorValue;
            user.needsToBeUpdatedFromBackend = YES;
            ZMConnection *connection = [ZMConnection insertNewSentConnectionToUser:user];
            connection.message = text;
            self.user = user;
            
            // Do a delayed save and run the handler on the main queue, once it's done:
            ZMSDispatchGroup * g = [ZMSDispatchGroup groupWithLabel:@"ZMSearchUser"];
            [self.syncMOC enqueueDelayedSaveWithGroup:g];
            
            ZM_WEAK(self);
            [g notifyOnQueue:dispatch_get_main_queue() block:^{
                ZM_STRONG(self);
                completionHandler();
            }];
        }];
    }
}

- (BOOL)isSelfUser
{
    return self.user.isSelfUser;
}

- (BOOL)canBeConnected
{
    return ((self.user == nil) ?
            (!self.isConnected && self.remoteIdentifier != nil) :
            self.user.canBeConnected);
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: %p> (ID: %@, name: %@, accent: %d, connected: %@), user: ",
                                    self.class, self, self.remoteIdentifier.transportString, self.displayName, self.accentColorValue,
                                    self.isConnected ? @"YES" : @"NO"];
    if (self.user != nil) {
        [description appendFormat:@"<%@: %p> %@", self.user.class, self.user, self.user.objectID.URIRepresentation];
    } else {
        [description appendString:@" nil"];
    }
    return description;
}

- (NSUInteger)hash;
{
    union {
        NSUInteger hash;
        uuid_t uuid;
    } u;
    u.hash = 0;
    [self.remoteIdentifier getUUIDBytes:u.uuid];
    return u.hash;
}

- (BOOL)isEqual:(id)object;
{
    if (! [object isKindOfClass:[ZMSearchUser class]]) {
        return NO;
    }
    ZMSearchUser *other = object;
    
    if  (self.remoteIdentifier == nil) {
        return [self.contact isEqual:other.contact] && other.user == nil;
    } else {
        return other.remoteIdentifier == self.remoteIdentifier || [other.remoteIdentifier isEqual:self.remoteIdentifier];
    }
}


+ (NSCache *)searchUserToSmallProfileImageCache;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        searchUserToSmallProfileImageCache = [[NSCache alloc] init];
    });
    return searchUserToSmallProfileImageCache;
}

+ (NSCache *)searchUserToMediumImageCache;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        searchUserToMediumImageCache = [[NSCache alloc] init];
        searchUserToMediumImageCache.countLimit = 10;
    });
    return searchUserToMediumImageCache;
}

+ (NSCache *)searchUserToMediumAssetIDCache;
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        searchUserToMediumAssetIDCache = [[NSCache alloc] init];
    });
    return searchUserToMediumAssetIDCache;
}


- (NSData *)cachedSmallProfileData
{
    return [[ZMSearchUser searchUserToSmallProfileImageCache] objectForKey:self.remoteIdentifier];
}

- (NSData *)cachedMediumProfileData
{
    return [[ZMSearchUser searchUserToMediumImageCache] objectForKey:self.remoteIdentifier];
}

- (NSUUID *)cachedMediumAssetID
{
    return [[ZMSearchUser searchUserToMediumAssetIDCache] objectForKey:self.remoteIdentifier];
}

- (NSData *)imageSmallProfileData
{
    if (self.user != nil) {
        return self.user.imageSmallProfileData;
    }
    if (_imageSmallProfileData == nil) {
        _imageSmallProfileData = [self cachedSmallProfileData];
        if (_imageSmallProfileData != nil) {
            _imageSmallProfileIdentifier = self.remoteIdentifier.transportString;
        };
    }
    return _imageSmallProfileData;
}


+ (NSSet *)keyPathsForValuesAffectingImageSmallProfileData
{
    return [NSSet setWithObjects:@"user.imageSmallProfileData", nil];
}

- (NSData *)imageMediumData
{
    if (self.user != nil) {
        return self.user.imageMediumData;
    }
    if (_imageMediumData == nil) {
        _imageMediumData = [self cachedMediumProfileData];
    }
    return _imageMediumData;
}


- (NSUUID *)mediumAssetID
{
    if (_mediumAssetID == nil) {
        _mediumAssetID = [self cachedMediumAssetID];
    }
    return _mediumAssetID;
}

- (NSString *)imageSmallProfileIdentifier
{
    if (self.user != nil) {
        return self.user.imageSmallProfileIdentifier;
    }
    if (_imageSmallProfileIdentifier != nil) {
        return _imageSmallProfileIdentifier;
    }
    if ([self cachedSmallProfileData] != nil) {
        return self.remoteIdentifier.transportString;
    }
    return nil;
}


- (NSString *)imageMediumIdentifier
{
    if (self.user != nil) {
        return self.user.imageMediumIdentifier;
    }
    if (self.mediumAssetID != nil) {
        return self.mediumAssetID.transportString;
    }
    if ([self cachedMediumProfileData] != nil) {
        return self.remoteIdentifier.transportString;
    }
    return nil;
}

- (void)notifyNewSmallImageData:(NSData *)data managedObjectContextObserver:(ManagedObjectContextObserver *)mocObserver;
{
    _imageSmallProfileData = data;
    [mocObserver notifyUpdatedSearchUser:self];
}

- (void)setAndNotifyNewMediumImageData:(NSData *)data managedObjectContextObserver:(ManagedObjectContextObserver *)mocObserver;
{
    if (_imageMediumData == nil || ![_imageMediumData isEqualToData:data]) {
        _imageMediumData = data;
    }
    [mocObserver notifyUpdatedSearchUser:self];
}


@end




@implementation ZMSearchUser (Connections)

@dynamic isPendingApprovalByOtherUser; // This is implemented above

@end

