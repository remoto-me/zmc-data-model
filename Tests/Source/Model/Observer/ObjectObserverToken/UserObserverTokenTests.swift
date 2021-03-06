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


import Foundation
@testable import ZMCDataModel

extension NSManagedObject {
    func changedKeys() -> Set<String> {
        var result : [String] = []
        for key in self.changedValues().keys {
            result.append(key as String)
        }
        return Set(result)
    }
}

class UserObserverTokenTests : ZMBaseManagedObjectTest {
    
    let UserClientsKey = "clients"

    enum UserInfoChangeKey: String {
        case Name = "nameChanged"
        case AccentColor = "accentColorValueChanged"
        case ImageMediumData = "imageMediumDataChanged"
        case ImageSmallProfileData = "imageSmallProfileDataChanged"
        case ProfileInfo = "profileInformationChanged"
        case ConnectionState = "connectionStateChanged"
        case TrustLevel = "trustLevelChanged"
    }

    let userInfoChangeKeys: [UserInfoChangeKey] = [
        .Name,
        .AccentColor,
        .ImageMediumData,
        .ImageSmallProfileData,
        .ProfileInfo,
        .ConnectionState,
        .TrustLevel
    ]
    
    override func setUp() {
        super.setUp()
        self.setUpCaches()
        self.uiMOC.globalManagedObjectContextObserver.syncCompleted(NSNotification(name: "fake", object: nil))
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))
    }

    func checkThatItNotifiesTheObserverOfAChange(user : ZMUser, modifier: ZMUser -> Void, expectedChangedField: UserInfoChangeKey, customAffectedKeys: AffectedKeys? = nil) {

        // given
        self.uiMOC.saveOrRollback()
        let observer = UserChangeObserver(user:user)

        // when
        modifier(user)
        self.uiMOC.saveOrRollback()

        // then
        let changeCount = observer.notifications.count
        XCTAssertEqual(changeCount, 1)

        // and when
        self.uiMOC.saveOrRollback()

        // then
        XCTAssertEqual(observer.notifications.count, changeCount, "Should not have changed further once")

        if let changes = observer.notifications.firstObject as? UserChangeInfo {
            for key in userInfoChangeKeys where key != expectedChangedField  {
                if let value = changes.valueForKey(key.rawValue) as? NSNumber {
                    XCTAssertFalse(value.boolValue, "\(key.rawValue) was supposed to be false")
                }
                else {
                    XCTFail("Can't find key or key is not boolean for '\(key.rawValue)'")
                }
            }
        }
        observer.tearDown()
    }


    func testThatItNotifiesTheObserverOfANameChange()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.name = "George"
        self.uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier: { $0.name = "Phil"},
            expectedChangedField: .Name)

    }

    func testThatItNotifiestheObserverOfMultipleNameChanges()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        let observer = UserChangeObserver(user: user)
        self.uiMOC.saveOrRollback()

        // when
        user.name = "Foo"
        self.uiMOC.saveOrRollback()

        // then
        XCTAssertEqual(observer.notifications.count, 1)

        // and when
        user.name = "Bar"
        self.uiMOC.saveOrRollback()

        // then
        XCTAssertEqual(observer.notifications.count, 2)

        // and when
        self.uiMOC.saveOrRollback()
        observer.tearDown()

        observer.tearDown()
    }

    func testThatItNotifiesTheObserverOfAnAccentColorChange()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.accentColorValue = ZMAccentColor.StrongBlue

        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier: { $0.accentColorValue = ZMAccentColor.SoftPink },
            expectedChangedField: .AccentColor)

    }

    func testThatItNotifiesTheObserverOfAMediumProfileImageChange()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.remoteIdentifier = NSUUID.createUUID()
        user.mediumRemoteIdentifier = NSUUID.createUUID()
        user.imageMediumData = self.verySmallJPEGData()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier: { $0.imageMediumData = NSData() },
            expectedChangedField: .ImageMediumData)
    }

    func testThatItNotifiesTheObserverOfASmallProfileImageChange()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.remoteIdentifier = NSUUID.createUUID()
        user.smallProfileRemoteIdentifier = NSUUID.createUUID()
        user.imageSmallProfileData = self.verySmallJPEGData()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier: { $0.imageSmallProfileData = NSData() },
            expectedChangedField: .ImageSmallProfileData)
    }

    func testThatItNotifiesTheObserverOfAnEmailChange()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.setEmailAddress("foo@example.com", onUser: user)

        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier: { self.setEmailAddress(nil, onUser: $0) },
            expectedChangedField: .ProfileInfo)
    }

    func testThatItNotifiesTheObserverOfAPhoneNumberChange()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.setPhoneNumber("+99-32312423423", onUser: user)


        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier: { self.setPhoneNumber("+99-0000", onUser: $0) },
            expectedChangedField: .ProfileInfo)
    }

    func testThatItNotifiesTheObserverOfAConnectionStateChange()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.connection = ZMConnection.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.connection!.status = ZMConnectionStatus.Pending
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier : { $0.connection!.status = ZMConnectionStatus.Accepted },
            expectedChangedField: .ConnectionState,
            customAffectedKeys: AffectedKeys.All)
    }

    func testThatItNotifiesTheObserverOfACreatedIncomingConnection()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier : {
                $0.connection = ZMConnection.insertNewObjectInManagedObjectContext(self.uiMOC)
                $0.connection!.status = ZMConnectionStatus.Pending
            },
            expectedChangedField: .ConnectionState,
            customAffectedKeys: AffectedKeys.All)
    }

    func testThatItNotifiesTheObserverOfACreatedOutgoingConnection()
    {
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()

        // when
        self.checkThatItNotifiesTheObserverOfAChange(user,
            modifier : {
                $0.connection = ZMConnection.insertNewObjectInManagedObjectContext(self.uiMOC)
                $0.connection!.status = ZMConnectionStatus.Sent
            },
            expectedChangedField: .ConnectionState,
            customAffectedKeys: AffectedKeys.All)
    }

    func testThatItStopsNotifyingAfterUnregisteringTheToken() {

        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.setEmailAddress("foo@example.com", onUser: user)
        self.uiMOC.saveOrRollback()

        let observer = UserChangeObserver(user: user)
        observer.tearDown()


        // when
        user.emailAddress = "aaaaaa@example.com"
        self.uiMOC.saveOrRollback()

        // then
        XCTAssertEqual(observer.notifications.count, 0)
    }

    func testThatItNotifiesUserForClientStartsTrusting() {

        // given
        let user = ZMUser.selfUserInContext(self.uiMOC)
        let client = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        let otherUser = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        let otherClient = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.mutableSetValueForKey(UserClientsKey).addObject(client)
        otherUser.mutableSetValueForKey(UserClientsKey).addObject(otherClient)

        // when
        self.uiMOC.saveOrRollback()
        XCTAssert(self.waitForAllGroupsToBeEmptyWithTimeout(0.5))

        // then
        self.checkThatItNotifiesTheObserverOfAChange(otherUser,
            modifier: { _ in client.trustClient(otherClient) },
            expectedChangedField: .TrustLevel)

        XCTAssertTrue(otherClient.trustedByClients.contains(client))
    }

    func testThatItNotifiesUserForClientStartsIgnoring() {

        // given
        let user = ZMUser.selfUserInContext(self.uiMOC)
        let client = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        let otherUser = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        let otherClient = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.mutableSetValueForKey(UserClientsKey).addObject(client)
        otherUser.mutableSetValueForKey(UserClientsKey).addObject(otherClient)

        // when
        client.trustClient(otherClient)
        self.uiMOC.saveOrRollback()
        XCTAssert(self.waitForAllGroupsToBeEmptyWithTimeout(0.5))

        // then
        self.checkThatItNotifiesTheObserverOfAChange(otherUser,
            modifier: { _ in client.ignoreClient(otherClient) },
            expectedChangedField: .TrustLevel)

        XCTAssertFalse(otherClient.trustedByClients.contains(client))
        XCTAssertTrue(otherClient.ignoredByClients.contains(client))
    }

    func testThatItUpdatesClientObserversWhenClientIsAdded() {

        // given
        let selfUser = ZMUser.selfUserInContext(self.uiMOC)
        let selfClient = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        selfUser.mutableSetValueForKey(UserClientsKey).addObject(selfClient)
        self.uiMOC.saveOrRollback()
        let observer = UserChangeObserver(user: selfUser)

        // when
        let otherClient = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        selfUser.mutableSetValueForKey(UserClientsKey).addObject(otherClient)
        self.uiMOC.saveOrRollback()
        XCTAssert(self.waitForAllGroupsToBeEmptyWithTimeout(0.5))

        // then
        guard let changeInfo = observer.notifications.firstObject as? UserChangeInfo else { return XCTFail("Should receive a changeInfo for the added client") }
        XCTAssertTrue(changeInfo.clientsChanged)
        XCTAssertTrue(changeInfo.changedKeysAndOldValues.keys.contains(UserClientsKey))

        // after
        observer.tearDown()
    }


    func testThatItUpdatesClientObserversWhenClientIsRemoved() {

        // given
        let selfUser = ZMUser.selfUserInContext(self.uiMOC)
        let selfClient = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        let otherClient = UserClient.insertNewObjectInManagedObjectContext(self.uiMOC)
        selfUser.mutableSetValueForKey(UserClientsKey).addObject(selfClient)
        selfUser.mutableSetValueForKey(UserClientsKey).addObject(otherClient)
        self.uiMOC.saveOrRollback()
        XCTAssertEqual(selfUser.clients.count, 2)
        
        let observer = UserChangeObserver(user: selfUser)

        // when
        selfUser.mutableSetValueForKey(UserClientsKey).removeObject(otherClient)
        self.uiMOC.saveOrRollback()
        XCTAssert(self.waitForAllGroupsToBeEmptyWithTimeout(0.5))

        // then
        guard let changeInfo = observer.notifications.firstObject as? UserChangeInfo else { return XCTFail("Should receive a changeInfo for the added client") }
        XCTAssertTrue(changeInfo.clientsChanged)
        XCTAssertTrue(changeInfo.changedKeysAndOldValues.keys.contains(UserClientsKey))
        XCTAssertEqual(selfUser.clients, Set(arrayLiteral: selfClient))
        XCTAssertEqual(selfUser.clients.count, 1)

        observer.tearDown()
    }
    
    func testThatItUpdatesClientObserversWhenClientsAreFaultedAndNewClientIsAdded() {
        
        // given
        var objectID: NSManagedObjectID!
        var syncMOCUser: ZMUser!
        
        syncMOC.performGroupedBlockAndWait {
            syncMOCUser = ZMUser.insertNewObjectInManagedObjectContext(self.syncMOC)
            self.syncMOC.saveOrRollback()
            objectID = syncMOCUser.objectID
            XCTAssertEqual(syncMOCUser.clients.count, 0)
        }
        spinMainQueueWithTimeout(0.5)
        
        guard let object = try? uiMOC.existingObjectWithID(objectID), uiMOCUser = object as? ZMUser else {
            return XCTFail("Unable to get user with objectID in uiMOC")
        }
        
        let observer = UserChangeObserver(user: uiMOCUser)
        
        // we register for notifications to merge the two contexts
        let notificationCenterToken = NSNotificationCenter.defaultCenter().addObserverForName(
            NSManagedObjectContextDidSaveNotification,
            object: syncMOC,
            queue: .mainQueue()) { note in
                
            self.uiMOC.mergeChangesFromContextDidSaveNotification(note)
            self.uiMOC.saveOrRollback()
        }
        
        // when adding a new client on the syncMOC
        syncMOC.performGroupedBlockAndWait {
            let client = UserClient.insertNewObjectInManagedObjectContext(self.syncMOC)
            syncMOCUser.mutableSetValueForKey(self.UserClientsKey).addObject(client)
            self.syncMOC.saveOrRollback()
            XCTAssertTrue(syncMOCUser.fault)
        }
        
        spinMainQueueWithTimeout(0.5)
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))
        
        // then we should receive a changeInfo with clientsChanged on the uiMOC
        let changeInfo = observer.notifications.firstObject as? UserChangeInfo
        XCTAssertEqual(observer.notifications.count, 1)
        XCTAssertEqual(changeInfo?.clientsChanged, true)
        XCTAssertEqual(uiMOCUser.clients.count, 1)
        
        observer.tearDown()
        NSNotificationCenter.defaultCenter().removeObserver(notificationCenterToken)
    }

    func testThatItUpdatesClientObserversWhenClientsAreFaultedAndNewClientIsAddedSameContext() {
        
        // given
        let user = ZMUser.insertNewObjectInManagedObjectContext(uiMOC)
        XCTAssertEqual(user.clients.count, 0)
        XCTAssertFalse(user.clients.first?.user?.fault == .Some(true))

        uiMOC.saveOrRollback()
        uiMOC.refreshObject(user, mergeChanges: true)
        XCTAssertTrue(user.fault)
        let observer = UserChangeObserver(user: user)

        // when
        let client = UserClient.insertNewObjectInManagedObjectContext(uiMOC)
        user.mutableSetValueForKey(UserClientsKey).addObject(client)

        uiMOC.saveOrRollback()
        uiMOC.refreshObject(user, mergeChanges: true)
        uiMOC.refreshObject(client, mergeChanges: true)
        
        XCTAssertTrue(user.fault)
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))
        
        // then
        let changeInfo = observer.notifications.firstObject as? UserChangeInfo
        XCTAssertEqual(changeInfo?.clientsChanged, true)
        XCTAssertEqual(user.clients.count, 1)
        
        observer.tearDown()
    }

    func testThatItNotifiesTrustChangeForClientsAddedAfterSubscribing() {

        // given
        let selfUser = ZMUser.selfUserInContext(uiMOC)
        let selfClient = UserClient.insertNewObjectInManagedObjectContext(uiMOC)
        selfUser.mutableSetValueForKey(UserClientsKey).addObject(selfClient)
        
        let observedUser = ZMUser.insertNewObjectInManagedObjectContext(uiMOC)
        let otherClient = UserClient.insertNewObjectInManagedObjectContext(uiMOC)
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))
        let observer : UserChangeObserver = UserChangeObserver(user: observedUser)

        // when
        observedUser.mutableSetValueForKey(UserClientsKey).addObject(otherClient)
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))
        
        //then
        XCTAssertEqual(observer.notifications.count, 1)
        let note : UserChangeInfo = observer.notifications.firstObject! as! UserChangeInfo
        let clientsChanged : Bool = note.clientsChanged
        XCTAssertEqual(clientsChanged, true)

        // when
        selfClient.trustClient(otherClient)
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))

        // then
        let userChangeInfos = observer.notifications.asArray() as! [UserChangeInfo]
        
        XCTAssertEqual(observedUser.clients.count, 1)
        XCTAssertEqual(userChangeInfos.count, 2)
        XCTAssertEqual(userChangeInfos.map { $0.trustLevelChanged }, [false, true])
        XCTAssertEqual(userChangeInfos.map { $0.clientsChanged }, [true, false])

        observer.tearDown()
    }
    
}

