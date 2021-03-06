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


import XCTest

class ObserverTokenDirectoryTests: ZMBaseManagedObjectTest {
    
    class TestObserver: NSObject, ZMUserObserver {
        var changes : [UserChangeInfo] = []
        
        func userDidChange(note: UserChangeInfo!) {
            changes.append(note)
        }
    }
    
    override func setUp() {
        super.setUp()
        self.setUpCaches()
        self.uiMOC.globalManagedObjectContextObserver.syncCompleted(NSNotification(name: "fake", object: nil))
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))
    }

    
    func testThatCreatesOnlyOneTokenForTheSameObject() {
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.name = "Hans"
        self.uiMOC.saveOrRollback()
        
        let testObserver = TestObserver()
        
        let token1 = ZMUser.addUserObserver(testObserver, forUsers: [user], managedObjectContext:self.uiMOC)
        let token2 = ZMUser.addUserObserver(testObserver, forUsers: [user], managedObjectContext:self.uiMOC)
        
        // when
        user.name = "Horst"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(testObserver.changes.count, 2)
        XCTAssert(testObserver.changes.first === testObserver.changes.last)
        
        ZMUser.removeUserObserverForToken(token1)
        ZMUser.removeUserObserverForToken(token2)
        
    }
    
    
    func testThatCreatesTwoTokensForDifferentObjects() {
        let user1 = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user1.name = "Hans"
        
        let user2 = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user2.name = "Heinrich"
        
        self.uiMOC.saveOrRollback()
        
        let testObserver = TestObserver()
        
        let token1 = ZMUser.addUserObserver(testObserver, forUsers: [user1], managedObjectContext:self.uiMOC)
        let token2 = ZMUser.addUserObserver(testObserver, forUsers: [user2], managedObjectContext:self.uiMOC)
        
        // when
        user1.name = "Horst"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(testObserver.changes.count, 1)
        
        ZMUser.removeUserObserverForToken(token1)
        ZMUser.removeUserObserverForToken(token2)
    }
}