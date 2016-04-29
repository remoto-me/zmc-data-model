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
// along with this program. If not, see <http://www.gnu.org/licenses/>.
// 


#import "ZMBaseManagedObjectTest.h"

#import "ZMUser+Internal.h"
#import "NSManagedObjectContext+zmessaging.h"
#import "NSManagedObjectContext+tests.h"
#import "MockEntity.h"



@interface ManagedObjectContextTests : ZMBaseManagedObjectTest

@end



@implementation ManagedObjectContextTests

- (void)testThatWeCanCreateTheUserInterfaceContext
{
    XCTAssertNotNil(self.uiMOC.persistentStoreCoordinator);
    XCTAssertEqual(self.uiMOC.persistentStoreCoordinator.persistentStores.count, (NSUInteger) 1);
    
    NSManagedObjectModel *mom = self.uiMOC.persistentStoreCoordinator.managedObjectModel;
    XCTAssertNotEqual(mom.entities.count, (NSUInteger) 0);
    for (NSString *name in @[@"Connection",
                             @"Conversation",
                             @"ImageMessage",
                             @"KnockMessage",
                             @"Message",
                             @"SystemMessage",
                             @"TextMessage",
                             @"User"])
    {
        XCTAssertNotNil(mom.entitiesByName[name], @"Could not find entity \"%@\"", name);
    }
}

- (void)testThatWeCanGetTheSelfUser;
{
    ZMUser *selfUser = [ZMUser selfUserInContext:self.uiMOC];
    XCTAssertNotNil([ZMUser selfUserInContext:self.uiMOC]);
    
    XCTAssertTrue(selfUser.needsToBeUpdatedFromBackend);
    XCTAssertEqual([selfUser class], [ZMUser class]);
    XCTAssertEqual(selfUser.entity, self.uiMOC.persistentStoreCoordinator.managedObjectModel.entitiesByName[[ZMUser entityName]]);
    XCTAssertEqual(selfUser, [ZMUser selfUserInContext:self.uiMOC]);
    __block ZMUser *syncUser;
    [self.syncMOC performGroupedBlockAndWait:^{
        syncUser = [ZMUser selfUserInContext:self.syncMOC];
    }];
    XCTAssertEqualObjects([ZMUser selfUserInContext:self.uiMOC].objectID, syncUser.objectID);
}

- (void)testThatWeCanStoreMetadataInStore
{
    XCTAssertNil([self.uiMOC persistentStoreMetadataForKey:@"TestKey"]);
    [self.uiMOC setPersistentStoreMetadata:@"value_172653" forKey:@"TestKey"];
    XCTAssertEqualObjects([self.uiMOC persistentStoreMetadataForKey:@"TestKey"], @"value_172653");
}

- (void)testThatItIgnoresNilValuesWhenStoringMetadata
{
    XCTAssertNil([self.uiMOC persistentStoreMetadataForKey:nil]);
    XCTAssertNoThrow([self.uiMOC setPersistentStoreMetadata:nil forKey:@"TestKey"]);
    [self performIgnoringZMLogError:^{
        XCTAssertNoThrow([self.uiMOC setPersistentStoreMetadata:@"dummy" forKey:nil]);
    }];
}

- (void)testThatItSavesMetadataWhenSaveIsSuccessfull;
{
    //given
    NSManagedObjectContext *sut = self.alternativeTestMOC;
    NSString *key = @"Good stuff", *value = @"Jambon";
    [sut setPersistentStoreMetadata:value forKey:key];
    
    //when
    [sut saveOrRollback]; //will save
    
    //then
    XCTAssertNil(sut.userInfo[@"ZMMetadataKey"]);
    XCTAssertNotNil([sut persistentStoreMetadataForKey:key]);
    XCTAssertEqualObjects([sut persistentStoreMetadataForKey:key], value);
}

- (void)testThatItRevertsMetadataWhenRollback;
{
    //given
    NSManagedObjectContext *sut = self.alternativeTestMOC;
    NSString *key = @"Good stuff", *value = @"Jambon";
    [sut setPersistentStoreMetadata:value forKey:key];
    [sut enableForceRollback];
    
    //when
    [sut saveOrRollback]; // will rollback
    
    //then
    XCTAssertNil(sut.userInfo[@"ZMMetadataKey"]);
    XCTAssertNil([sut persistentStoreMetadataForKey:key]);
}


- (void)testThatUserInterfaceContextIsMarkedAsSuch;
{
    __block BOOL isUI = NO;
    __block BOOL isSync = NO;
    [self.uiMOC performGroupedBlock:^{
        isUI = self.uiMOC.zm_isUserInterfaceContext;
        isSync = self.uiMOC.zm_isSyncContext;
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertTrue(isUI);
    XCTAssertFalse(isSync);
}

- (void)testThatSyncContextIsMarkedAsSuch;
{
    [self.syncMOC performGroupedBlock:^{
        XCTAssertFalse(self.syncMOC.zm_isUserInterfaceContext);
        XCTAssertTrue(self.syncMOC.zm_isSyncContext);
    }];
    WaitForAllGroupsToBeEmpty(0.5);
}

- (void)testThatItCanSaveWhenItHasChanges;
{
    // given
    id saveObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:saveObserver name:NSManagedObjectContextDidSaveNotification object:self.uiMOC];
    [self verifyMockLater:saveObserver];
    
    // expect
    [[saveObserver expect] notificationWithName:NSManagedObjectContextDidSaveNotification object:self.uiMOC userInfo:[OCMArg any]];
    
    // when
    [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    [self.uiMOC saveOrRollback];
    WaitForAllGroupsToBeEmpty(0.5);
    [[NSNotificationCenter defaultCenter] removeObserver:saveObserver];
}

- (void)testThatItDoesNotSaveWhenItHasNoChanges;
{
    // given
    id saveObserver = [OCMockObject observerMock];
    [[NSNotificationCenter defaultCenter] addMockObserver:saveObserver name:NSManagedObjectContextDidSaveNotification object:self.uiMOC];
    [self verifyMockLater:saveObserver];
    
    // expect
    //
    // (that no notifications are sent.
    // -reject doesn't work on observer mocks.
    
    // when
    [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    [self.uiMOC rollback];
    [self.uiMOC saveOrRollback];
    [[NSNotificationCenter defaultCenter] removeObserver:saveObserver];
}

- (void)testThatItRollsBackWhenSaveFails;
{
    // given
    id contextMock = [OCMockObject partialMockForObject:self.uiMOC];
    [self verifyMockLater:contextMock];
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSManagedObjectValidationError userInfo:nil];
    [(NSManagedObjectContext *)[[contextMock stub] andReturnValue:@NO] save:[OCMArg setTo:error]];
    
    // expect
    [[contextMock expect] rollback];
    
    // when
    [ZMUser insertNewObjectInManagedObjectContext:self.uiMOC];
    [self performIgnoringZMLogError:^{
        [self.uiMOC saveOrRollback];
    }];
}

@end



@implementation ManagedObjectContextTests (Queue)

- (void)testThatTheGroupIsNotified;
{
    // when
    __block BOOL didRunA = NO;
    __block BOOL didRunB = NO;
    __block BOOL didRunC = NO;
    __block BOOL didRunABeforeB = NO;
    __block BOOL didRunCBeforeB = NO;
    [self.uiMOC performGroupedBlock:^{
        didRunA = YES;
    }];
    [self.uiMOC notifyWhenGroupIsEmpty:^{
        didRunB = YES;
        didRunABeforeB = didRunA;
        didRunCBeforeB = didRunC;
    }];
    [self.uiMOC performGroupedBlock:^{
        didRunC = YES;
    }];
    
    // Need this twice, since the group will be empty, and only then
    // the notifyWhenGroupIsEmpty will get enqueued.
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertTrue([self waitOnMainLoopUntilBlock:^BOOL{
        return didRunB;
    } timeout:0.5]);
    WaitForAllGroupsToBeEmpty(0.5);

    // then
    XCTAssertTrue(didRunA);
    XCTAssertTrue(didRunB);
    XCTAssertTrue(didRunC);
    XCTAssertTrue(didRunABeforeB);
    XCTAssertTrue(didRunCBeforeB);
}

- (void)testThatTheGroupIsNotifiedOnlyAfterAdditionallyEnqueuedBlocksAreDone;
{
    // when
    __block BOOL didRunA = NO;
    __block BOOL didRunB = NO;
    __block BOOL didRunC = NO;
    __block BOOL didRunD = NO;
    __block BOOL didRunABeforeB = NO;
    __block BOOL didRunCBeforeB = NO;
    __block BOOL didRunDBeforeB = NO;
    [self.uiMOC performGroupedBlock:^{
        didRunA = YES;
    }];
    [self.uiMOC notifyWhenGroupIsEmpty:^{
        didRunB = YES;
        didRunABeforeB = didRunA;
        didRunCBeforeB = didRunC;
        didRunDBeforeB = didRunD;
    }];
    [self.uiMOC performGroupedBlock:^{
        didRunC = YES;
        [self.uiMOC performGroupedBlock:^{
            didRunD = YES;
        }];
    }];
    
    // Need this twice, since the group will be empty, and only then
    // the notifyWhenGroupIsEmpty will get enqueued.
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertTrue([self waitOnMainLoopUntilBlock:^BOOL{
        return didRunB;
    } timeout:0.5]);
    WaitForAllGroupsToBeEmpty(0.5);
    
    // then
    XCTAssertTrue(didRunA);
    XCTAssertTrue(didRunB);
    XCTAssertTrue(didRunC);
    XCTAssertTrue(didRunABeforeB);
    XCTAssertTrue(didRunCBeforeB);
}

@end



@implementation ManagedObjectContextTests (DelayedSave)

- (void)testThatItPerformsADelayedSaveWhenEnqueuedFromTheSameQueue;
{
    // We enqueue on the main queue, and the blocks run on the main queue.
    
    // given
    NSManagedObjectContext *sut = self.testMOC;
    MockEntity *mo = [MockEntity insertNewObjectInManagedObjectContext:sut];
    NSError *error;
    XCTAssert([sut save:&error], @"Failed to save: %@", error);
    NSMutableArray *events = [NSMutableArray array];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Did save"];
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:sut queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NOT_USED(note);
        [events addObject:@"save"];
        [expectation fulfill];
    }];
    
    // when
    [sut performGroupedBlock:^{
        [events addObject:@"A"];
        mo.field2 = @"A";
        [sut enqueueDelayedSave];
    }];

    [sut performGroupedBlock:^{
        [events addObject:@"B"];
        mo.field2 = @"B";
        [sut enqueueDelayedSave];
    }];
    
    [sut performGroupedBlock:^{
        [events addObject:@"C"];
        mo.field2 = @"C";
        [sut enqueueDelayedSave];
    }];
    
    // then
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssert([self waitForCustomExpectationsWithTimeout:0.5]);
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    
    XCTAssertEqualObjects([events componentsJoinedByString:@" "], @"A B C save");
}

- (void)testThatItPerformsADelayedSaveWhenEnqueuedFromAnotherQueue;
{
    // We enqueue on the main queue, and the blocks run on the main queue.
    
    // given
    NSManagedObjectContext *sut = self.alternativeTestMOC;
    MockEntity *mo = [MockEntity insertNewObjectInManagedObjectContext:sut];
    NSError *error;
    XCTAssert([sut save:&error], @"Failed to save: %@", error);
    NSMutableArray *events = [NSMutableArray array];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Did save"];
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:sut queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NOT_USED(note);
        [events addObject:@"save"];
        [expectation fulfill];
    }];
    
    // when
    [sut performGroupedBlock:^{
        [events addObject:@"A"];
        mo.field2 = @"A";
        [sut enqueueDelayedSave];
    }];
    
    [sut performGroupedBlock:^{
        [events addObject:@"B"];
        mo.field2 = @"B";
        [sut enqueueDelayedSave];
    }];
    
    [sut performGroupedBlock:^{
        [events addObject:@"C"];
        mo.field2 = @"C";
        [sut enqueueDelayedSave];
    }];
    
    // then
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssert([self waitForCustomExpectationsWithTimeout:0.5]);
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    
    XCTAssertEqualObjects([events componentsJoinedByString:@" "], @"A B C save");
}

@end
