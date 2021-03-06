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


@import ZMCSystem;

#import "ZMConversation.h"

@class ZMUserSession;
@class ZMUser;
@class ZMVoiceChannelParticipantState;
@protocol CallingInitialisationObserverToken
@end
@protocol CallingInitialisationObserver <NSObject>
- (void)couldNotInitialiseCallWithError:(NSError *)error;
@end


typedef NS_ENUM(uint8_t, ZMVoiceChannelConnectionState) {
    ZMVoiceChannelConnectionStateInvalid,
    ZMVoiceChannelConnectionStateNotConnected,
    ZMVoiceChannelConnectionStateConnecting,    ///<  The user is in the process of joining the media flow channel
    ZMVoiceChannelConnectionStateConnected      ///<  The media flow channel is established.  The user is fully connected and can participate in the voice channel
};

typedef NS_ENUM(uint8_t, ZMVoiceChannelState) {
    ZMVoiceChannelStateInvalid = 0,
    ZMVoiceChannelStateNoActiveUsers, ///< Nobody is active on the voice channel
    ZMVoiceChannelStateOutgoingCall, ///< We are connecting and nobody is in a connected state on the voice channel yet (ie: we are calling)
    ZMVoiceChannelStateOutgoingCallInactive, ///< We are connecting and nobody is in a connected state on the voice channel yet (ie: we are calling) but not ringing anymore.
    ZMVoiceChannelStateIncomingCall, ///< Someone else is calling (ringing) you on the voice channel.
    ZMVoiceChannelStateIncomingCallInactive, // Group call is in progress but it's not ringing for us.
    ZMVoiceChannelStateSelfIsJoiningActiveChannel, ///< Somebody else is in a connected state on the voice channel and we are connecting (ie: we are joining)
    ZMVoiceChannelStateSelfConnectedToActiveChannel, ///< Self connects to voice channel AND there is someone already connected on the channel
    ZMVoiceChannelStateDeviceTransferReady, ///< This device is ready to have the call transfered to it
};


typedef NS_ENUM(uint8_t, ZMVoiceChannelCallEndReason) {
    ZMVoiceChannelCallEndReasonRequested, ///< Default when other user ends the call
    ZMVoiceChannelCallEndReasonRequestedSelf, ///< when self user ends the call
    ZMVoiceChannelCallEndReasonRequestedAVS, ///< AVS requested to end call. (media wasn't flowing etc.)
    ZMVoiceChannelCallEndReasonOtherLostMedia, ///< Other participant lost media flow
    ZMVoiceChannelCallEndReasonInterrupted, ///< When GSM call interrupts call
    ZMVoiceChannelCallEndReasonDisconnected ///< When the client disconnects from the service due to other technical reasons
};


// The voice channel of a conversation.
//
// N.B.: The conversation owns the voice channel, but the voice channel only has a weak reference back to the conversations. Users of the voice channel @b must hold onto a strong reference to the owning conversations. Failure to do so can lead to undefined behaviour.
// !!!: tl;dr Don't hold on to any @c ZMVoiceChannel references. Store the @c ZMConversation reference instead and ask it for the voice channel
//
@interface ZMVoiceChannel : NSObject

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly) ZMVoiceChannelState state;
@property (nonatomic, readonly, weak) ZMConversation *conversation; ///< The owning conversation

/// The current  Video device ID used. Nil if no video. Default to the front camera
@property (nonatomic, copy, readonly) NSString *currentVideoDeviceID;

/// Returns @c nil if there's no active voice channel
+ (instancetype)activeVoiceChannelInSession:(id<ZMManagedObjectContextProvider>)session;


/// For each participant call the block with that user and the user's connection state and muted state.
- (void)enumerateParticipantStatesWithBlock:(void(^)(ZMUser *user, ZMVoiceChannelConnectionState connectionState, BOOL muted))block ZM_NON_NULL(1);

/// Voice channel participants. May be a subset of conversation participants.
- (NSOrderedSet *)participants;

- (ZMVoiceChannelParticipantState *)participantStateForUser:(ZMUser *)user;

@property (nonatomic, readonly) ZMVoiceChannelConnectionState selfUserConnectionState;



/// Adds an observer that notifies if there are errors establishing a video or audio call
/// The returned token needs to be retained and used to remove the observer in removeCallingInitialisationObserver:
- (id<CallingInitialisationObserverToken>)addCallingInitializationObserver:(id<CallingInitialisationObserver>)observer;

/// Unregister from notifications about call establishment
- (void)removeCallingInitialisationObserver:(id<CallingInitialisationObserverToken>)token;

@end



@interface ZMVoiceChannelParticipantState : NSObject

@property (nonatomic, readonly) ZMVoiceChannelConnectionState connectionState;
@property (nonatomic, readonly) BOOL muted;
@property (nonatomic, readonly) BOOL isSendingVideo;

@end



@interface ZMConversation (ZMVoiceChannel)

@property (nonatomic, readonly) ZMVoiceChannel *voiceChannel; ///< NOTE: this object is transient, and will be re-created periodically. Do not hold on to this object, hold on to the owning conversation instead.

@end



@interface ZMVoiceChannel (ZMDebug)

/// Attributed string to be displayed to the user to help tracking down calling related bugs.
+ (NSAttributedString *)voiceChannelDebugInformation;

@end
