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


#import "ModelObjectsTests.h"
#import "ZMManagedObject+Internal.h"
#import "ZMUser+Internal.h"
#import "MockEntity.h"
#import "MockEntity2.h"
#import "MockModelObjectContextFactory.h"
#import "NSManagedObjectContext+zmessaging.h"
#import "NSManagedObjectContext+tests.h"


@interface TestEntityWithPredicate : ZMManagedObject

@end



@implementation TestEntityWithPredicate

+(NSString *)sortKey {
    return @"test-sort-key-predicate";
}

+(NSString *)entityName {
    return @"test-entity-name-predicate";
}

+ (NSFetchRequest *) sortedFetchRequest
{
    NSFetchRequest *request = [super sortedFetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"original_condition == 0"];
    return request;
}

@end


@interface ZMManagedObjectTests : ZMBaseManagedObjectTest

@end


@implementation ZMManagedObjectTests
{
    NSPredicate *OriginalPredicate;
}

- (void)setUp
{
    [super setUp];
    OriginalPredicate = [NSPredicate predicateWithFormat:@"original_condition == 0"];
    [self.testMOC markAsUIContext];
}

- (void)tearDown
{
    [self.testMOC resetContextType];
    [super tearDown];
}

- (void)testThatItCreatesASortedFetchRequest
{

    // when
    NSFetchRequest *fetchRequest = [MockEntity sortedFetchRequest];
    
    // then
    XCTAssertEqualObjects(fetchRequest.entityName, [MockEntity entityName]);
    XCTAssertEqualObjects([(NSSortDescriptor *) fetchRequest.sortDescriptors[0] key], [MockEntity sortKey]);
}


- (void)testThatItAddsAPredicateToARequest
{
    
    // given
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"test_predicate == 1"];
    
    // when
    NSFetchRequest *fetchRequest = [MockEntity sortedFetchRequestWithPredicate:predicate];
    
    // then
    XCTAssertEqualObjects(fetchRequest.predicate, predicate);
    
}

- (void)testThatItAddsAPredicateToARequestWithAPredicate
{
    
    // given
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"test_predicate == 1"];
    NSPredicate *compound = [NSCompoundPredicate andPredicateWithSubpredicates:@[OriginalPredicate, predicate]];
    
    // when
    NSFetchRequest *fetchRequest = [TestEntityWithPredicate sortedFetchRequestWithPredicate:predicate];
    
    // then
    XCTAssertEqualObjects(fetchRequest.predicate, compound);
    
}

- (void)testThatItEnumeratesAllManagedObjectsInTheContext
{
    // given
    [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    
    __block NSUInteger found = 0;
    
    // when
    [MockEntity enumerateObjectsInContext:self.testMOC withBlock:^(ZMManagedObject *mo, BOOL *stop ZM_UNUSED) {
        XCTAssert([mo isKindOfClass:[MockEntity class]]);
        ++found;
    }];
    
    // then
    XCTAssertEqual(2u, found);
}

- (void)testThatItStopsWhileEnumeratingManagedObjectsInTheContext
{
    // given
    [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    
    __block NSUInteger found = 0;
    
    // when
    [MockEntity enumerateObjectsInContext:self.testMOC withBlock:^(ZMManagedObject *mo, BOOL *stop ZM_UNUSED) {
        XCTAssert([mo isKindOfClass:[MockEntity class]]);
        *stop = YES;
        ++found;
    }];
    
    // then
    XCTAssertEqual(1u, found);
}

- (void)testThatItDoesNotFetcheAnObjectIfNoRemoteIdentifiersMatch;
{
    // given
    MockEntity *entity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    entity.testUUID = NSUUID.createUUID;

    XCTAssert([self.testMOC saveOrRollback]);
    
    // when
    MockEntity *found = [MockEntity fetchObjectWithRemoteIdentifier:NSUUID.createUUID inManagedObjectContext:self.testMOC];
    
    // then
    XCTAssertNil(found);
}

- (void)testThatItFetchesUsingUUIDWhenTheObjectIsRegisteredWithTheContext;
{
    // given
    MockEntity *entity;
    for(int i = 0; i < 4; ++i) {
        entity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        entity.testUUID = NSUUID.createUUID;
    }
    XCTAssert([self.testMOC saveOrRollback]);
    
    // when
    MockEntity *found = [MockEntity fetchObjectWithRemoteIdentifier:entity.testUUID inManagedObjectContext:self.testMOC];
    
    // then
    XCTAssertEqualObjects(found.objectID, entity.objectID);
}

- (void)testPerformanceOfFetchingObjectByRemoteIDWhenTheObjectIsRegisteredWithTheContext;
{
    // given
    NSUUID *idToSearchFor;
    MockEntity *entity;
    for(int i = 0; i < 400; ++i) {
        entity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        entity.testUUID = NSUUID.createUUID;
        if (i == 200) {
            idToSearchFor = entity.testUUID;
        }
    }
    XCTAssert([self.testMOC saveOrRollback]);
    
    [self measureBlock:^{
        for(int i = 0; i < 1000; ++i) {
            MockEntity *found = [MockEntity fetchObjectWithRemoteIdentifier:idToSearchFor inManagedObjectContext:self.testMOC];
            XCTAssertNotNil(found);
        }
    }];
}

- (void)testThatItDoesNotFetcheAnObjectOfADifferentEntity;
{
    // given
    MockEntity2 *entity = [MockEntity2 insertNewObjectInManagedObjectContext:self.testMOC];
    entity.testUUID = NSUUID.createUUID;
    XCTAssert([self.testMOC saveOrRollback]);
    
    // when
    MockEntity *found = [MockEntity fetchObjectWithRemoteIdentifier:entity.testUUID inManagedObjectContext:self.testMOC];
    
    // then
    XCTAssertNil(found);
}

- (void)testThatItFetchesUsingUUIDWhenTheObjectIsNotRegisteredWithTheContext;
{
    // given
    MockEntity *entity;
    for(int i = 0; i < 4; ++i) {
        entity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        entity.testUUID = NSUUID.createUUID;
    }
    XCTAssert([self.testMOC saveOrRollback]);
    
    // when
    MockEntity *found = [MockEntity fetchObjectWithRemoteIdentifier:entity.testUUID inManagedObjectContext:self.alternativeTestMOC];
    
    // then
    XCTAssertEqualObjects(found.objectID, entity.objectID);
}


- (void)testThatNoKeysAreModifiedRightAfterCreation
{
    // given
    [self.testMOC markAsUIContext];

    MockEntity *user = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];

    // when
    NSSet *keysWithLocalModifications = user.keysThatHaveLocalModifications;

    // then
    XCTAssertEqual(keysWithLocalModifications.count, 0u);
}


- (void)testThatItSetsSomeLocalChanges
{
    // given
    [self.testMOC markAsUIContext];
    
    // when
    __block NSSet *keysWithLocalModifications;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        MockEntity *mockEntity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];

        // when
        mockEntity.field = 2;
        mockEntity.field2 = @"Joe Doe";
        [self.testMOC save:nil];
        
        keysWithLocalModifications = mockEntity.keysThatHaveLocalModifications;
    }];
    
    
    // then
    NSSet *expectedKeys = [NSSet setWithObjects:@"field", @"field2", nil];
    XCTAssertEqualObjects(expectedKeys, keysWithLocalModifications);
}


- (void)testThatItSetsAllLocalChanges
{
    // given
    [self.testMOC markAsUIContext];
    __block MockEntity *mockEntity;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        mockEntity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        
        // when
        mockEntity.field = 6;
        mockEntity.field2 = @"Joe Doe";
        mockEntity.field3 = @"someemail@example.com";
        
        [self.testMOC save:nil];
    }];

    __block NSSet *keysThatHaveLocalModifications;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        keysThatHaveLocalModifications = mockEntity.keysThatHaveLocalModifications;
    }];
    
    // then
    NSSet *expectedKeys = [NSSet setWithObjects:
        @"field",
        @"field2",
        @"field3",
        nil];
    XCTAssertEqualObjects(expectedKeys, keysThatHaveLocalModifications);
}



- (void)testThatItPersistsLocalChanges
{
    // given
    NSUUID *entityUUID = [NSUUID createUUID];
    [self.testMOC markAsUIContext];
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        MockEntity *mockEntity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        mockEntity.testUUID = entityUUID;
        mockEntity.field = 99;
        //user.field2 = NOT SET
        mockEntity.field3 = @"Joe Doe";
        [self.testMOC save:nil];
    }];

    // when
    __block NSSet *keysWithLocalModifications;
    [self.syncMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        MockEntity *fetchedEntity = [self mockEntityWithUUID:entityUUID inMoc:self.alternativeTestMOC];
        keysWithLocalModifications = fetchedEntity.keysThatHaveLocalModifications;
    }];
    
    // then
    NSSet *expectedKeys = [NSSet setWithObjects:
        @"testUUID_data",
        @"field",
        @"field3",
        nil];
    XCTAssertEqualObjects(expectedKeys, keysWithLocalModifications);
}

- (void)testThatChangesInSyncContextAreNotPersisted
{
    // given
    NSSet *expectedKeys = [NSSet set];
    // not a UI moc
    MockEntity *mockEntity = [MockEntity insertNewObjectInManagedObjectContext:self.alternativeTestMOC];

    // when
    mockEntity.field2 = @"someemail@example.com";
    mockEntity.field3 = @"Joe Doe";
    [self.testMOC save:nil];

    // then

    NSSet *keysWithLocalModifications = mockEntity.keysThatHaveLocalModifications;
    XCTAssertEqualObjects(expectedKeys, keysWithLocalModifications);
}


- (void)testThatLocalChangesAreReset
{
    // given
    [self.testMOC markAsUIContext];

    MockEntity *mockEntity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    mockEntity.field2 = @"someemail@example.com";
    mockEntity.field3 = @"Joe Doe";
    [self.testMOC save:nil];

    // when
    [mockEntity resetLocallyModifiedKeys:mockEntity.keysThatHaveLocalModifications];

    // then
    NSSet *expectedKeys = [NSSet set];
    NSSet *keysWithLocalModifications = mockEntity.keysThatHaveLocalModifications;
    XCTAssertEqualObjects(expectedKeys, keysWithLocalModifications);
}


- (void)testThatOnlySomeLocalChangesAreReset
{
    // given
    [self.testMOC markAsUIContext];
    __block MockEntity *mockEntity;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        mockEntity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        mockEntity.testUUID = [NSUUID createUUID];
        mockEntity.field = 5;
        mockEntity.field2 = @"someemail@example.com";
        mockEntity.field3 = @"Joe Doe";
        NSError *error;
        XCTAssertTrue([self.testMOC save:&error], @"Error insaving: %@", error);
    }];
    
    // when
    NSSet *keysToReset = [NSSet setWithObjects:@"field2", @"testUUID_data", @"bogus_unknown_attr", nil];
    __block NSSet *keysWithLocalModifications;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        [mockEntity resetLocallyModifiedKeys:keysToReset];
        keysWithLocalModifications = mockEntity.keysThatHaveLocalModifications;
    }];
    
    // then
    NSSet *expectedKeys = [NSSet setWithObjects:@"field", @"field3", nil];
    XCTAssertEqualObjects(expectedKeys, keysWithLocalModifications);
}


- (void)testThatItUpdatesLocalChangesForReferences
{
    // given
    [self.testMOC markAsUIContext];
    __block MockEntity *mockEntity;
    __block MockEntity *otherMockEntity1;
    __block MockEntity *otherMockEntity2;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        mockEntity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        otherMockEntity1 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        otherMockEntity2 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    }];
    
    // when
    __block NSSet *keysWithLocalModifications;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        mockEntity.field = 2;
        mockEntity.field2 = @"Joe Doe";
        [mockEntity.mockEntities addObjectsFromArray:@[otherMockEntity1, otherMockEntity2]];
        [self.testMOC save:nil];
        keysWithLocalModifications = mockEntity.keysThatHaveLocalModifications;
    }];
    
    // then
    NSSet *expectedKeys = [NSSet setWithObjects:@"field", @"field2", @"mockEntities", nil];
    XCTAssertEqualObjects(expectedKeys, keysWithLocalModifications);
}

- (void)testObjectIDForURIRepresentation
{
    // given
    __block MockEntity *entity1;
    __block MockEntity *entity2;
    __block MockEntity *entity3;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        entity1 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        entity2 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        entity3 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    }];
    
    id mockUserSession = [OCMockObject mockForProtocol:@protocol(ZMManagedObjectContextProvider)];
    [[[(id)mockUserSession stub] andReturn:self.testMOC] managedObjectContext];
    
    // when
    NSManagedObjectID *fetchedID = [MockEntity objectIDForURIRepresentation:entity2.objectID.URIRepresentation inUserSession:mockUserSession];
    
    // then
    XCTAssertNotEqualObjects(entity1.objectID, fetchedID);
    XCTAssertEqualObjects(entity2.objectID, fetchedID);
    XCTAssertNotEqualObjects(entity3.objectID, fetchedID);
    
}

- (void)testExistingObjectWithID
{
    // given
    __block MockEntity *entity1;
    __block MockEntity *entity2;
    __block MockEntity *entity3;
    [self.testMOC performGroupedBlockAndWaitWithReasonableTimeout:^{
        entity1 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        entity2 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
        entity3 = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    }];
    
    id mockUserSession = [OCMockObject mockForProtocol:@protocol(ZMManagedObjectContextProvider)];
    [[[(id)mockUserSession stub] andReturn:self.testMOC] managedObjectContext];
    
    // when
    MockEntity *fetchedEntity = [MockEntity existingObjectWithID:entity2.objectID inUserSession:mockUserSession];
    
    // then
    XCTAssertNotEqualObjects(entity1, fetchedEntity);
    XCTAssertEqualObjects(entity2, fetchedEntity);
    XCTAssertNotEqualObjects(entity3, fetchedEntity);
}

- (MockEntity *)mockEntityWithUUID:(NSUUID *)UUID inMoc:(NSManagedObjectContext *)moc
{
    NSPredicate *p = [NSPredicate predicateWithFormat:@"testUUID_data == %@", [UUID data]];
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"MockEntity"];
    request.predicate = p;
    NSArray *users = [moc executeFetchRequestOrAssert:request];
    return users[0];
}

- (void)testThatNormalObjectsAreNotZombie
{
    // given
    MockEntity *entity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    
    // then
    XCTAssertFalse(entity.isZombieObject);
}

- (void)testThatDeletedObjectsAreZombiesBeforeASave
{
    // given
    MockEntity *entity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    
    // when
    [self.testMOC deleteObject:entity];
    
    // then
    XCTAssertTrue(entity.isZombieObject);
}

- (void)testThatDeletedObjectsAreZombiesAfterASave
{
    // given
    MockEntity *entity = [MockEntity insertNewObjectInManagedObjectContext:self.testMOC];
    
    // when
    [self.testMOC deleteObject:entity];
    
    // then
    XCTAssertTrue(entity.isZombieObject);
}

@end


@implementation ZMManagedObjectTests (NonpersistedObjectIdentifer)

- (void)testThatItReturnsTheSameIdentifierForTemporaryAndSavedObjects;
{
    // given
    ZMConversation *mo = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    
    // when
    NSString *s1 = [[mo nonpersistedObjectIdentifer] copy];
    XCTAssert([self.uiMOC saveOrRollback]);
    NSString *s2 = [[mo nonpersistedObjectIdentifer] copy];
    
    // then
    XCTAssertNotNil(s1);
    XCTAssertEqualObjects(s1, s2);
}

- (void)testThatItReturnsAnObjectForANonpersistedObjectIdentifier
{
    // given
    id mockUserSession = [OCMockObject mockForProtocol:@protocol(ZMManagedObjectContextProvider)];
    [[[(id)mockUserSession stub] andReturn:self.uiMOC] managedObjectContext];
    
    ZMConversation *mo = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    NSString *identifier = [[mo nonpersistedObjectIdentifer] copy];
    
    // when
    ZMConversation *mo2 = (id)[ZMManagedObject existingObjectWithNonpersistedObjectIdentifer:identifier inUserSession:mockUserSession];
    
    // then
    XCTAssertEqual(mo, mo2);
}

- (void)testThatItReturnsAnObjectForANonpersistedObjectIdentifierAfterASave
{
    // given
    id mockUserSession = [OCMockObject mockForProtocol:@protocol(ZMManagedObjectContextProvider)];
    [[[(id)mockUserSession stub] andReturn:self.uiMOC] managedObjectContext];
    
    ZMConversation *mo = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    NSString *identifier = [[mo nonpersistedObjectIdentifer] copy];
    
    // when
    XCTAssert([self.uiMOC saveOrRollback]);
    ZMConversation *mo2 = (id)[ZMManagedObject existingObjectWithNonpersistedObjectIdentifer:identifier inUserSession:mockUserSession];
    
    // then
    XCTAssertEqual(mo, mo2);
}

- (void)testThatItReturnsNilForANilIdentifier;
{
    // given
    id mockUserSession = [OCMockObject mockForProtocol:@protocol(ZMManagedObjectContextProvider)];
    [[[(id)mockUserSession stub] andReturn:self.uiMOC] managedObjectContext];
    
    // then
    [self performIgnoringZMLogError:^{
        XCTAssertNil([ZMManagedObject existingObjectWithNonpersistedObjectIdentifer:nil inUserSession:mockUserSession]);
    }];
}

- (void)testThatItReturnsNilForANonExistingIdentifier;
{
    // given
    id mockUserSession = [OCMockObject mockForProtocol:@protocol(ZMManagedObjectContextProvider)];
    [[[(id)mockUserSession stub] andReturn:self.uiMOC] managedObjectContext];
    __block NSString *identifier;
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *mo = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        identifier = [[mo nonpersistedObjectIdentifer] copy];
    }];
    
    // then
    XCTAssertNil([ZMManagedObject existingObjectWithNonpersistedObjectIdentifer:identifier inUserSession:mockUserSession]);
}

- (void)testThatItReturnsNilForAnInvalidExistingIdentifier;
{
    // given
    id mockUserSession = [OCMockObject mockForProtocol:@protocol(ZMManagedObjectContextProvider)];
    [[[(id)mockUserSession stub] andReturn:self.uiMOC] managedObjectContext];
    
    // then
    XCTAssertNil([ZMManagedObject existingObjectWithNonpersistedObjectIdentifer:@"foo" inUserSession:mockUserSession]);
    XCTAssertNil([ZMManagedObject existingObjectWithNonpersistedObjectIdentifer:@"Zfoo" inUserSession:mockUserSession]);
}

@end
