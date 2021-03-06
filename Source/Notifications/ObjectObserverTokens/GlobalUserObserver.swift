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

public protocol DisplayNameObserver : NSObjectProtocol {
    var conversation : ZMConversation? { get }
    func displayNameMightChange(users: Set<NSObject>)
    func tearDown()
}

final class GlobalUserObserver : NSObject, ObjectsDidChangeDelegate, ZMUserObserver {
    
    private var userTokens : [ZMUser : GenericUserObserverToken<ZMUser>] = [:]
    private var searchUserTokens : [NSObject : GenericUserObserverToken<ZMSearchUser>] = [:]
    private var userObserverTokens : TokenCollection<UserObserverToken> = TokenCollection()
    private var displayNameObservers : [DisplayNameObserver] = []
    
    private let managedObjectContext : NSManagedObjectContext
    private var needsToRecalculateNames : Bool = false
    var isTornDown : Bool = false
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init()
    }
    
    private func removeTokensForUsers(users: [ZMUser]) {
        for user in users {
            self.userTokens[user]?.tearDown()
            self.userTokens.removeValueForKey(user)
            self.userObserverTokens.removeTokensForObject(user)
        }
    }
    
    // handling object changes
    func objectsDidChange(changes: ManagedObjectChanges) {
        if let updated = changes.updated as? [ZMConnection] where updated.count > 0 ,
           let inserted = changes.inserted as? [ZMConnection] where inserted.count > 0
        {
            let users = (inserted + updated).flatMap{$0.to}
            userTokens.values.forEach{$0.connectionDidChange(users)}
            return
        }
        
        self.removeTokensForUsers(changes.deleted as? [ZMUser] ?? [])
    }
    
    func displayNameMightChange(users: Set<NSObject>) {
        displayNameObservers.forEach{$0.displayNameMightChange(users)}
    }
    
    func userDidChange(note: UserChangeInfo!) {
        if let user =  note.user as? NSObject {
            userObserverTokens[user]?.forEach{ $0.notifyObserver(note) }
        }
    }
    
    func tearDown() {
        userTokens.values.forEach{$0.tearDown()}
        userTokens = [:]
        searchUserTokens.values.forEach{$0.tearDown()}
        searchUserTokens = [:]
        userObserverTokens = TokenCollection()
        displayNameObservers.forEach{$0.tearDown()}
        displayNameObservers = []
        isTornDown = true
    }
}




extension GlobalUserObserver {
    
    func addUserObserver(observer: ZMUserObserver, user: ZMBareUser) -> UserObserverToken? {
        switch (user) {
        case let user as ZMUser:
            if userTokens[user] == nil {
                userTokens[user] = GenericUserObserverToken<ZMUser>(observer: self, user: user, managedObjectContext:managedObjectContext, keyForDirectoryInUserInfo: "user")
            }
            return userObserverTokens.addObserver(observer, object: user, globalObserver: self)
        case let user as ZMSearchUser:
            if searchUserTokens[user] == nil {
                searchUserTokens[user] = GenericUserObserverToken<ZMSearchUser>(observer: self, user: user, managedObjectContext:managedObjectContext, keyForDirectoryInUserInfo: "searchuser")
            }
            return userObserverTokens.addObserver(observer, object: user, globalObserver: self)
        default:
            return nil
        }
    }
    
    func addDisplayNameObserver(observer: DisplayNameObserver) {
        displayNameObservers.append(observer)
    }

    func removeUserObserverForToken(token: UserObserverToken) {
        let user = userObserverTokens.objectCanBeUnobservedAfterRemovingObserverForToken(token)
        if let user = user as? ZMUser {
            (userTokens[user])?.tearDown()
            userTokens.removeValueForKey(user)
        }
        if let user = user as? ZMSearchUser {
            (searchUserTokens[user])?.tearDown()
            searchUserTokens.removeValueForKey(user)
        }
    }
    
    func removeDisplayNameObserver(observer: DisplayNameObserver) {
        displayNameObservers = displayNameObservers.filter{
            if let lObj = $0.conversation, let rObj = observer.conversation {
                return lObj != rObj
            }
            return false
        }
    }
}

