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


#import <ZMUtilities/ZMAccentColor.h>

@protocol ZMCommonContactsSearchDelegate;
@protocol ZMCommonContactsSearchToken
@end

/// The minimal set of properties and methods that something User-like must include
@protocol ZMBareUser <NSObject>

/// The full name
@property (nonatomic, readonly) NSString *name;
/// The display name will be short e.g. "John A" for connected users, but always the full name for non-connected users.
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *initials;

/// whether this is the self user
@property (nonatomic, readonly) BOOL isSelfUser;


@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) ZMAccentColor accentColorValue;

@property (nonatomic, readonly) NSData *imageMediumData;
@property (nonatomic, readonly) NSData *imageSmallProfileData;
/// This is a unique string that will change only when the @c imageSmallProfileData changes
@property (nonatomic, readonly) NSString *imageSmallProfileIdentifier;
@property (nonatomic, readonly) NSString *imageMediumIdentifier;


/// Is @c YES if we can send a connection request to this user.
@property (nonatomic, readonly) BOOL canBeConnected;


/// Sends a connection request to the given user. May be a no-op, eg. if we're already connected.
/// A ZMUserChangeNotification with the searchUser as object will be sent notifiying about the connection status change
/// You should stop from observing the searchUser and start observing the user from there on
- (void)connectWithMessageText:(NSString *)text completionHandler:(dispatch_block_t)handler;

@property (nonatomic, readonly, copy) NSString *connectionRequestMessage;
@property (nonatomic, readonly) NSOrderedSet *topCommonConnections;
@property (nonatomic, readonly) NSUInteger totalCommonConnections;

@end



@protocol ZMCommonContactsSearchDelegate

- (void)didReceiveCommonContactsUsers:(NSOrderedSet *)users forSearchToken:(id<ZMCommonContactsSearchToken>)searchToken;

@end


@protocol ZMBareUserConnection <NSObject>

@property (nonatomic, readonly) BOOL isPendingApprovalByOtherUser;

@end
