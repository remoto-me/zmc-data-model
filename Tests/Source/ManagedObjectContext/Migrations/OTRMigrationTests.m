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


@import ZMCDataModel;
#import <XCTest/XCTest.h>
#import <CoreData/CoreData.h>
#import <ZMTesting/ZMTesting.h>
#import <OCMock/OCMock.h>



static NSString * const DataBaseFileExtensionName = @"wiredatabase";


@interface OTRMigrationTests : ZMTBaseTest

@end

@implementation OTRMigrationTests

- (void)setUp
{
    [self cleanUp];
    [NSManagedObjectContext setUseInMemoryStore:NO];
    [super setUp];
}

- (void)tearDown
{
    [self cleanUp];
    [super tearDown];
}

- (void)cleanUp
{
    [NSManagedObjectContext resetSharedPersistentStoreCoordinator];
}

- (void)testThatItDoesNotMigrateFromANonE2EEVersionAndWipesTheDB {
    
    // given
    NSManagedObjectModel *currentMom = [NSManagedObjectContext loadManagedObjectModel];
    __block NSManagedObjectContext *syncContext;
    __block NSMutableArray *managedObjects = [[NSMutableArray alloc] init];
    
    // when
    [self performMockingStoreURLWithVersion:@"1.24" block:^{

        [self performIgnoringZMLogError:^{
            syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        }];
        
        XCTestExpectation *migrationExpectation = [self expectationWithDescription:@"It should not migrate from non E2EE version"];
        
        [syncContext performGroupedBlockAndWait:^{
            for (NSEntityDescription *entity in currentMom.entities) {
                NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity.name];
                [managedObjects addObjectsFromArray:[syncContext executeFetchRequestOrAssert:request]];
            }
            [migrationExpectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    // then
    WaitForAllGroupsToBeEmpty(0.5);
    XCTAssertEqual(managedObjects.count, 2lu); // ZMUserSession and SelfUser
}

- (void)testThatItPerformsMigrationFrom_1_25_ToCurrentModelVersion {
    
    // given
    __block NSManagedObjectContext *syncContext;
    __block NSUInteger conversationCount;
    __block NSUInteger messageCount;
    __block NSUInteger systemMessageCount;
    __block NSUInteger connectionCount;
    __block NSArray *userDictionaries;
    __block ZMTextMessage *message;
    __block NSUInteger helloWorldMessageCount;
    __block NSUInteger userClientCount;
    
    // when
    [self performMockingStoreURLWithVersion:@"1.25" block:^{
        
        syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        
        XCTestExpectation *migrationExpectation = [self expectationWithDescription:@"It should migrate from 1.25 to 1.27"];
        
        [syncContext performGroupedBlockAndWait:^{
            conversationCount = [syncContext countForFetchRequest:[ZMConversation sortedFetchRequest] error:nil];
            messageCount = [syncContext countForFetchRequest:[ZMTextMessage sortedFetchRequest] error:nil];
            systemMessageCount = [syncContext countForFetchRequest:[ZMSystemMessage sortedFetchRequest] error:nil];
            connectionCount = [syncContext countForFetchRequest:[ZMConnection sortedFetchRequest] error:nil];
            userClientCount = [syncContext countForFetchRequest:[UserClient sortedFetchRequest] error:nil];
            
            NSFetchRequest *helloWorldFetchRequest = [ZMTextMessage sortedFetchRequestWithPredicateFormat:@"%K BEGINSWITH[c] %@", @"text", @"Hello World"];
            helloWorldMessageCount = [syncContext countForFetchRequest:helloWorldFetchRequest error:nil];
            
            NSFetchRequest *messageFetchRequest = [ZMTextMessage sortedFetchRequestWithPredicateFormat:@"%K == %@", @"text", @"You are the best Burno"];
            message = [syncContext executeFetchRequestOrAssert:messageFetchRequest].firstObject;
            
            NSFetchRequest *userFetchRequest = [ZMUser sortedFetchRequest];
            userFetchRequest.resultType = NSDictionaryResultType;
            userFetchRequest.propertiesToFetch = self.userPropertiesToFetch;
            userDictionaries = [syncContext executeFetchRequestOrAssert:userFetchRequest];
            [migrationExpectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    WaitForAllGroupsToBeEmpty(15);
    
    // then
    XCTAssertEqual(conversationCount, 13lu);
    XCTAssertEqual(messageCount, 1681lu);
    XCTAssertEqual(systemMessageCount, 53lu);
    XCTAssertEqual(connectionCount, 5lu);
    XCTAssertEqual(userClientCount, 7lu);
    XCTAssertEqual(helloWorldMessageCount, 1515lu);
    
    XCTAssertNotNil(message);
    XCTAssertEqualObjects(message.serverTimestamp.transportString, @"2015-12-18T16:57:06.836Z");
    
    XCTAssertNotNil(userDictionaries);
    XCTAssertEqual(userDictionaries.count, 7lu);
    XCTAssertEqualObjects(userDictionaries, self.userDictionaryFixture1_25);
}

- (void)testThatItPerformsMigrationFrom_1_27_ToCurrentModelVersion {
    // given
    __block NSManagedObjectContext *syncContext;
    __block NSUInteger conversationCount;
    __block NSUInteger messageCount;
    __block NSUInteger systemMessageCount;
    __block NSUInteger connectionCount;
    __block NSArray *userDictionaries;
    __block NSUInteger userClientCount;
    
    // when
    [self performMockingStoreURLWithVersion:@"1.27" block:^{
        
        syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        
        XCTestExpectation *migrationExpectation = [self expectationWithDescription:@"It should migrate from 1.27 to current mom version"];
        
        [syncContext performGroupedBlockAndWait:^{
            conversationCount = [syncContext countForFetchRequest:ZMConversation.sortedFetchRequest error:nil];
            messageCount = [syncContext countForFetchRequest:ZMClientMessage.sortedFetchRequest error:nil];
            systemMessageCount = [syncContext countForFetchRequest:ZMSystemMessage.sortedFetchRequest error:nil];
            connectionCount = [syncContext countForFetchRequest:ZMConnection.sortedFetchRequest error:nil];
            userClientCount = [syncContext countForFetchRequest:UserClient.sortedFetchRequest error:nil];
            
            NSFetchRequest *userFetchRequest = ZMUser.sortedFetchRequest;
            userFetchRequest.resultType = NSDictionaryResultType;
            userFetchRequest.propertiesToFetch = self.userPropertiesToFetch;
            userDictionaries = [syncContext executeFetchRequestOrAssert:userFetchRequest];
            [migrationExpectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    WaitForAllGroupsToBeEmpty(15);
    
    // then
    XCTAssertEqual(conversationCount, 18lu);
    XCTAssertEqual(messageCount, 27lu);
    XCTAssertEqual(systemMessageCount, 18lu);
    XCTAssertEqual(connectionCount, 9lu);
    XCTAssertEqual(userClientCount, 25lu);
    
    XCTAssertNotNil(userDictionaries);
    XCTAssertEqual(userDictionaries.count, 7lu);
    XCTAssertEqualObjects(userDictionaries, self.userDictionaryFixture1_27);
}

- (void)testThatItPerformsMigrationFrom_1_28_ToCurrentModelVersion {
    // given
    __block NSManagedObjectContext *syncContext;
    __block NSUInteger conversationCount;
    __block NSUInteger messageCount;
    __block NSUInteger systemMessageCount;
    __block NSUInteger connectionCount;
    __block NSArray *userDictionaries;
    __block NSUInteger userClientCount;
    
    // when
    [self performMockingStoreURLWithVersion:@"1.28" block:^{
        
        syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        
        XCTestExpectation *migrationExpectation = [self expectationWithDescription:@"It should migrate from 1.28 to current mom version"];
        
        [syncContext performGroupedBlockAndWait:^{
            conversationCount = [syncContext countForFetchRequest:ZMConversation.sortedFetchRequest error:nil];
            messageCount = [syncContext countForFetchRequest:ZMClientMessage.sortedFetchRequest error:nil];
            systemMessageCount = [syncContext countForFetchRequest:ZMSystemMessage.sortedFetchRequest error:nil];
            connectionCount = [syncContext countForFetchRequest:ZMConnection.sortedFetchRequest error:nil];
            userClientCount = [syncContext countForFetchRequest:UserClient.sortedFetchRequest error:nil];
            
            NSFetchRequest *userFetchRequest = ZMUser.sortedFetchRequest;
            userFetchRequest.resultType = NSDictionaryResultType;
            userFetchRequest.propertiesToFetch = self.userPropertiesToFetch;
            userDictionaries = [syncContext executeFetchRequestOrAssert:userFetchRequest];
            [migrationExpectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    WaitForAllGroupsToBeEmpty(15);
    
    // then
    XCTAssertEqual(conversationCount, 3lu);
    XCTAssertEqual(messageCount, 17lu);
    XCTAssertEqual(systemMessageCount, 1lu);
    XCTAssertEqual(connectionCount, 2lu);
    XCTAssertEqual(userClientCount, 3lu);
    
    XCTAssertNotNil(userDictionaries);
    XCTAssertEqual(userDictionaries.count, 3lu);
    XCTAssertEqualObjects(userDictionaries, self.userDictionaryFixture1_28);
}

- (void)testThatItPerformsMigrationFrom_2_3_ToCurrentModelVersion {
    // given
    __block NSManagedObjectContext *syncContext;
    __block NSUInteger conversationCount;
    __block NSUInteger messageCount;
    __block NSUInteger systemMessageCount;
    __block NSUInteger connectionCount;
    __block NSArray *userDictionaries;
    __block NSUInteger userClientCount;
    
    // when
    [self performMockingStoreURLWithVersion:@"2.3" block:^{
        
        syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"It should migrate from 2.3 to the current mom"];
        
        [syncContext performGroupedBlockAndWait:^{
            NSError *error = nil;
            conversationCount = [syncContext countForFetchRequest:ZMConversation.sortedFetchRequest error:&error];
            messageCount = [syncContext countForFetchRequest:ZMClientMessage.sortedFetchRequest error:&error];
            systemMessageCount = [syncContext countForFetchRequest:ZMSystemMessage.sortedFetchRequest error:&error];
            connectionCount = [syncContext countForFetchRequest:ZMConnection.sortedFetchRequest error:&error];
            userClientCount = [syncContext countForFetchRequest:UserClient.sortedFetchRequest error:&error];
            XCTAssertNil(error);
            
            NSFetchRequest *userFetchRequest = ZMUser.sortedFetchRequest;
            userFetchRequest.resultType = NSDictionaryResultType;
            userFetchRequest.propertiesToFetch = self.userPropertiesToFetch;
            userDictionaries = [syncContext executeFetchRequestOrAssert:userFetchRequest];
            [expectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    WaitForAllGroupsToBeEmpty(15);
    
    // then
    XCTAssertEqual(conversationCount, 2lu);
    XCTAssertEqual(messageCount, 5lu);
    XCTAssertEqual(systemMessageCount, 0lu);
    XCTAssertEqual(connectionCount, 2lu);
    XCTAssertEqual(userClientCount, 8lu);
    
    XCTAssertNotNil(userDictionaries);
    XCTAssertEqual(userDictionaries.count, 3lu);
    XCTAssertEqualObjects(userDictionaries, self.userDictionaryFixture2_3);
}

- (void)testThatItPerformsMigrationFrom_2_4_ToCurrentModelVersion {
    // given
    __block NSManagedObjectContext *syncContext;
    __block NSUInteger conversationCount;
    __block NSUInteger messageCount;
    __block NSUInteger systemMessageCount;
    __block NSUInteger connectionCount;
    __block NSArray *userDictionaries;
    __block NSUInteger userClientCount;
    
    // when
    [self performMockingStoreURLWithVersion:@"2.4" block:^{
        
        syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"It should migrate from 2.4 to the current mom"];
        
        [syncContext performGroupedBlockAndWait:^{
            NSError *error = nil;
            conversationCount = [syncContext countForFetchRequest:ZMConversation.sortedFetchRequest error:&error];
            messageCount = [syncContext countForFetchRequest:ZMClientMessage.sortedFetchRequest error:&error];
            systemMessageCount = [syncContext countForFetchRequest:ZMSystemMessage.sortedFetchRequest error:&error];
            connectionCount = [syncContext countForFetchRequest:ZMConnection.sortedFetchRequest error:&error];
            userClientCount = [syncContext countForFetchRequest:UserClient.sortedFetchRequest error:&error];
            XCTAssertNil(error);
            
            NSFetchRequest *userFetchRequest = ZMUser.sortedFetchRequest;
            userFetchRequest.resultType = NSDictionaryResultType;
            userFetchRequest.propertiesToFetch = self.userPropertiesToFetch;
            userDictionaries = [syncContext executeFetchRequestOrAssert:userFetchRequest];
            [expectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    WaitForAllGroupsToBeEmpty(15);
    
    // then
    XCTAssertEqual(conversationCount, 2lu);
    XCTAssertEqual(messageCount, 15lu);
    XCTAssertEqual(systemMessageCount, 4lu);
    XCTAssertEqual(connectionCount, 2lu);
    XCTAssertEqual(userClientCount, 9lu);
    
    XCTAssertNotNil(userDictionaries);
    XCTAssertEqual(userDictionaries.count, 3lu);
    XCTAssertEqualObjects(userDictionaries, [self userDictionaryFixture_2_45_modifiedDataFields:4]);
}

- (void)testThatItPerformsMigrationFrom_2_5_ToCurrentModelVersion {
    // given
    __block NSManagedObjectContext *syncContext;
    __block NSUInteger conversationCount;
    __block NSUInteger messageCount;
    __block NSUInteger systemMessageCount;
    __block NSUInteger connectionCount;
    __block NSArray *userDictionaries;
    __block NSUInteger userClientCount;
    __block NSArray *assetClientMessages;
    
    // when
    [self performMockingStoreURLWithVersion:@"2.5" block:^{
        
        syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"It should migrate from 2.5 to the current mom"];
        
        [syncContext performGroupedBlockAndWait:^{
            NSError *error = nil;
            conversationCount = [syncContext countForFetchRequest:ZMConversation.sortedFetchRequest error:&error];
            messageCount = [syncContext countForFetchRequest:ZMClientMessage.sortedFetchRequest error:&error];
            systemMessageCount = [syncContext countForFetchRequest:ZMSystemMessage.sortedFetchRequest error:&error];
            connectionCount = [syncContext countForFetchRequest:ZMConnection.sortedFetchRequest error:&error];
            userClientCount = [syncContext countForFetchRequest:UserClient.sortedFetchRequest error:&error];
            assetClientMessages = [syncContext executeFetchRequestOrAssert:ZMAssetClientMessage.sortedFetchRequest];
            
            XCTAssertNil(error);
            
            NSFetchRequest *userFetchRequest = ZMUser.sortedFetchRequest;
            userFetchRequest.resultType = NSDictionaryResultType;
            userFetchRequest.propertiesToFetch = self.userPropertiesToFetch;
            userDictionaries = [syncContext executeFetchRequestOrAssert:userFetchRequest];
            [expectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    WaitForAllGroupsToBeEmpty(15);
    
    // then
    XCTAssertEqual(assetClientMessages.count, 5lu);
    
    for (ZMAssetClientMessage *message in assetClientMessages) {
        XCTAssertEqual(message.uploadState, ZMAssetUploadStateDone);
    }
    
    XCTAssertEqual(conversationCount, 2lu);
    XCTAssertEqual(messageCount, 13lu);
    XCTAssertEqual(systemMessageCount, 1lu);
    XCTAssertEqual(connectionCount, 2lu);
    XCTAssertEqual(userClientCount, 10lu);
    
    XCTAssertNotNil(userDictionaries);
    XCTAssertEqual(userDictionaries.count, 3lu);
    
    XCTAssertEqualObjects(userDictionaries, [self userDictionaryFixture_2_45_modifiedDataFields:0]);
}

- (void)testThatItPerformsMigrationFrom_2_6_ToCurrentModelVersion {
    // given
    __block NSManagedObjectContext *syncContext;
    __block NSUInteger conversationCount;
    __block NSUInteger messageCount;
    __block NSUInteger systemMessageCount;
    __block NSUInteger connectionCount;
    __block NSArray *userDictionaries;
    __block NSUInteger userClientCount;
    __block NSArray *assetClientMessages;
    
    // when
    [self performMockingStoreURLWithVersion:@"2.6" block:^{
        
        syncContext = [self checkThatItCreatesSyncContextAndPreparesLocalStore];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"It should migrate from 2.6 to the current mom"];
        
        [syncContext performGroupedBlockAndWait:^{
            NSError *error = nil;
            conversationCount = [syncContext countForFetchRequest:ZMConversation.sortedFetchRequest error:&error];
            messageCount = [syncContext countForFetchRequest:ZMClientMessage.sortedFetchRequest error:&error];
            systemMessageCount = [syncContext countForFetchRequest:ZMSystemMessage.sortedFetchRequest error:&error];
            connectionCount = [syncContext countForFetchRequest:ZMConnection.sortedFetchRequest error:&error];
            userClientCount = [syncContext countForFetchRequest:UserClient.sortedFetchRequest error:&error];
            assetClientMessages = [syncContext executeFetchRequestOrAssert:ZMAssetClientMessage.sortedFetchRequest];
            
            XCTAssertNil(error);
            
            NSFetchRequest *userFetchRequest = ZMUser.sortedFetchRequest;
            userFetchRequest.resultType = NSDictionaryResultType;
            userFetchRequest.propertiesToFetch = self.userPropertiesToFetch;
            userDictionaries = [syncContext executeFetchRequestOrAssert:userFetchRequest];
            [expectation fulfill];
        }];
        
        XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    }];
    
    WaitForAllGroupsToBeEmpty(15);
    
    // then
    XCTAssertEqual(assetClientMessages.count, 0lu);
    XCTAssertEqual(conversationCount, 20lu);
    XCTAssertEqual(messageCount, 3lu);
    XCTAssertEqual(systemMessageCount, 21lu);
    XCTAssertEqual(connectionCount, 16lu);
    XCTAssertEqual(userClientCount, 12lu);
    
    XCTAssertNotNil(userDictionaries);
    XCTAssertEqual(userDictionaries.count, 22lu);
    
    XCTAssertEqualObjects([userDictionaries subarrayWithRange:NSMakeRange(0, 3)], [self userDictionaryFixture2_6]);
}

#pragma mark - Helper

- (NSManagedObjectContext *)checkThatItCreatesSyncContextAndPreparesLocalStore
{
    __block NSManagedObjectContext *syncContext;
    
    XCTestExpectation *contextExpectation = [self expectationWithDescription:@"It should create context"];
    [NSManagedObjectContext prepareLocalStoreSync:NO backingUpCorruptedDatabase:NO completionHandler:^{
        syncContext = [NSManagedObjectContext createSyncContext];
        [contextExpectation fulfill];
    }];
    
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:10]);
    XCTAssertNotNil(syncContext);
    
    return syncContext;
}

- (NSArray <NSString *>*)userPropertiesToFetch
{
    return @[
             @"accentColorValue",
             @"emailAddress",
             @"modifiedDataFields",
             @"name",
             @"normalizedEmailAddress",
             @"normalizedName"
             ];
}

- (NSArray <NSString *>*)fileExtensions
{
    return @[@"", @"-wal", @"-shm"];
}

- (NSArray *)testBundleDataBaseURLsWithSuffix:(NSString *)suffix
{
    NSString *ressourceName = [@"store" stringByAppendingString:suffix];
    NSMutableArray *urls = [[NSMutableArray alloc] init];
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    for (NSString *extension in self.fileExtensions) {
        NSURL *url = [bundle URLForResource:ressourceName withExtension:[DataBaseFileExtensionName stringByAppendingString:extension]];
        if (url) {
            [urls addObject:url];
        }
    }
    
    XCTAssertGreaterThan(urls.count, 0lu); // We should at least have the url to the SQL store
    return urls;
}

- (NSArray <NSURL *>*)generateMockURLsWithBaseURL:(NSURL *)url
{
    NSUUID *pathUUID = NSUUID.UUID;
    NSURL *baseURL = [url URLByAppendingPathComponent:pathUUID.transportString];
    NSMutableArray *urls = [[NSMutableArray alloc] init];
    for (NSString *extension in self.fileExtensions) {
        [urls addObject:[baseURL URLByAppendingPathExtension:[DataBaseFileExtensionName stringByAppendingString:extension]]];
    }
    return urls;
}

- (void)performMockingStoreURLWithVersion:(NSString *)version block:(dispatch_block_t)block;
{
    // 1.25 and 1.26 share the same model version of 1.25
    if (! [@[@"1.24", @"1.25", @"1.27", @"1.28", @"2.3", @"2.4", @"2.5", @"2.6"] containsObject:version]) {
        XCTFail(@"Can only copy a database version with an existing SQL fixture in the test target");
    }
    
    NSString *suffix = [version stringByReplacingOccurrencesOfString:@"." withString:@""];
    NSArray <NSURL *>*databaseURLs = [self testBundleDataBaseURLsWithSuffix:suffix];
    NSArray <NSURL *>*mockURLs = [self generateMockURLsWithBaseURL:databaseURLs.firstObject.URLByDeletingLastPathComponent];
    
    // We want to make sure the version in the .sql file actually matches the one we want to test the migration from
    NSError *error = nil;
    NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                                                 URL:databaseURLs.firstObject
                                                                                               error:&error];
    XCTAssertNil(error);
    NSArray <NSString *>* versionIdentifiers = metadata[NSStoreModelVersionIdentifiersKey];
    XCTAssertEqual(versionIdentifiers.count, 1lu);
    
    // Unfortunately the model version of the app store version 1.24 was 1.3
    if (! [versionIdentifiers.firstObject isEqualToString:@"1.3"]) {
        XCTAssertEqualObjects(versionIdentifiers.firstObject, version);
    }
    
    // Move the old database from the ressources to a unique path
    NSFileManager *fm = NSFileManager.defaultManager;
    
    for (NSUInteger idx = 0; idx < databaseURLs.count; idx++) {
        XCTAssertTrue([fm copyItemAtURL:databaseURLs[idx] toURL:mockURLs[idx] error:&error]);
        XCTAssertNil(error);
    }
    
    // Mock the storeURL to return the unique path
    id mock = [OCMockObject mockForClass:[NSManagedObjectContext class]];
    [[[[mock stub] classMethod] andReturn:mockURLs.firstObject] storeURL];
    
    // Perform the migration test
    block();
    
    // Clean up & remove the database
    [mock stopMocking];
    for (NSUInteger idx = 0; idx < databaseURLs.count; idx++) {
        XCTAssertTrue([fm removeItemAtURL:mockURLs[idx] error:&error]);
        XCTAssertNil(error);
    }
}

#pragma mark - Fixtures

- (NSArray <NSDictionary *>*)userDictionaryFixture1_25
{
    return @[
             @{
                 @"accentColorValue": @1,
                 @"emailAddress": @"hello@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"awesome test user",
                 @"normalizedEmailAddress": @"hello@example.com",
                 @"normalizedName": @"awesome test user",
                 },
             @{
                 @"accentColorValue": @1,
                 @"emailAddress": @"censored@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"Bruno",
                 @"normalizedEmailAddress": @"censored@example.com",
                 @"normalizedName": @"bruno"
                 },
             @{
                 @"accentColorValue": @6,
                 @"modifiedDataFields": @0,
                 @"name": @"Florian",
                 @"normalizedName": @"florian"
                 },
             @{
                 @"accentColorValue": @4,
                 @"modifiedDataFields": @0,
                 @"name": @"Heinzelmann",
                 @"normalizedName": @"heinzelmann"
                 },
             @{
                 @"accentColorValue": @3,
                 @"emailAddress": @"migrationtest@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"MIGRATION TEST",
                 @"normalizedEmailAddress": @"migrationtest@example.com",
                 @"normalizedName": @"migration test"
                 },
             @{
                 @"accentColorValue": @3,
                 @"emailAddress": @"welcome+23@example.com",
                 @"modifiedDataFields": @0,
                 @"name" : @"Otto the Bot",
                 @"normalizedEmailAddress": @"welcome+23@example.com",
                 @"normalizedName": @"otto the bot",
                 },
             @{
                 @"accentColorValue": @6,
                 @"modifiedDataFields": @0,
                 @"name": @"Pierre-Joris",
                 @"normalizedName": @"pierrejoris"
                 }
             ];
}

- (NSArray <NSDictionary *>*)userDictionaryFixture1_27
{
    return @[
             @{
                 @"accentColorValue" : @(1),
                 @"emailAddress" : @"email@example.com",
                 @"modifiedDataFields" : @(0),
                 @"name" : @"Bruno",
                 @"normalizedEmailAddress" : @"email@example.com",
                 @"normalizedName" : @"bruno",
                 },
             @{
                 @"accentColorValue" : @(6),
                 @"emailAddress" : @"secret@example.com",
                 @"modifiedDataFields" : @(0),
                 @"name" : @"Florian",
                 @"normalizedEmailAddress" : @"secret@example.com",
                 @"normalizedName" : @"florian",
                 },
             @{
                 @"accentColorValue" : @(4),
                 @"emailAddress" : @"hidden@example.com",
                 @"modifiedDataFields" : @(0),
                 @"name" : @"Heinzelmann",
                 @"normalizedEmailAddress" : @"hidden@example.com",
                 @"normalizedName" : @"heinzelmann",
                 },
             @{
                 @"accentColorValue" : @(1),
                 @"emailAddress" : @"censored@example.com",
                 @"modifiedDataFields" : @(0),
                 @"name" : @"It is me",
                 @"normalizedEmailAddress" : @"censored@example.com",
                 @"normalizedName" : @"it is me",
                 },
             @{
                 @"accentColorValue" : @(3),
                 @"emailAddress" : @"welcome+23@example.com",
                 @"modifiedDataFields" : @(0),
                 @"name" : @"Otto the Bot",
                 @"normalizedEmailAddress" : @"welcome+23@example.com",
                 @"normalizedName" : @"otto the bot",
                 },
             @{
                 @"accentColorValue" : @(3),
                 @"modifiedDataFields" : @(0),
                 @"name" : @"Pierre-Joris",
                 @"normalizedName" : @"pierrejoris",
                 },
             @{
                 @"accentColorValue" : @(3),
                 @"emailAddress" : @"secret2@example.com",
                 @"modifiedDataFields" : @(0),
                 @"name" : @"Test User",
                 @"normalizedEmailAddress" : @"secret2@example.com",
                 @"normalizedName" : @"test user",
                 }
             ];
}

- (NSArray <NSDictionary *>*)userDictionaryFixture1_28
{
    return @[
             @{
                 @"accentColorValue": @1,
                 @"emailAddress": @"user1@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"user1",
                 @"normalizedEmailAddress": @"user1@example.com",
                 @"normalizedName": @"user1"
                 },
             @{
                 @"accentColorValue": @6,
                 @"emailAddress": @"user2@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"user2",
                 @"normalizedEmailAddress": @"user2@example.com",
                 @"normalizedName": @"user2"
                 },
             @{
                 @"accentColorValue": @1,
                 @"emailAddress": @"user3@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"user3",
                 @"normalizedEmailAddress": @"user3@example.com",
                 @"normalizedName": @"user3",
                 },
             ];
}

- (NSArray <NSDictionary *>*)userDictionaryFixture2_3
{
    return @[
             @{
                 @"accentColorValue": @1,
                 @"emailAddress": @"user1@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"Example User 1",
                 @"normalizedEmailAddress": @"user1@example.com",
                 @"normalizedName": @"example user 1"
                 },
             @{
                 @"accentColorValue": @6,
                 @"modifiedDataFields": @0,
                 @"name": @"Example User 2",
                 @"normalizedName": @"example user 2"
                 },
             @{
                 @"accentColorValue": @3,
                 @"emailAddress": @"user3@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"Example User 3",
                 @"normalizedEmailAddress": @"user3@example.com",
                 @"normalizedName": @"example user 3",
                 },
             ];
}

- (NSArray <NSDictionary *>*)userDictionaryFixture_2_45_modifiedDataFields:(NSInteger)modifiedFields
{
    return @[
             @{
                 @"accentColorValue": @4,
                 @"emailAddress": @"user1@example.com",
                 @"modifiedDataFields": @(modifiedFields),
                 @"name": @"User 1",
                 @"normalizedEmailAddress": @"user1@example.com",
                 @"normalizedName": @"user 1"
                 },
             @{
                 @"accentColorValue": @6,
                 @"modifiedDataFields": @0,
                 @"name": @"User 2",
                 @"normalizedName": @"user 2"
                 },
             @{
                 @"accentColorValue": @1,
                 @"emailAddress": @"user3@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"User 3",
                 @"normalizedEmailAddress": @"user3@example.com",
                 @"normalizedName": @"user 3",
                 },
             ];
}

- (NSArray <NSDictionary *>*)userDictionaryFixture2_6
{
    return @[
             @{
                 @"accentColorValue": @3,
                 @"modifiedDataFields": @0,
                 @"name": @"Andreas",
                 @"normalizedName": @"Andreas"
                 },
             @{
                 @"accentColorValue": @3,
                 @"emailAddress": @"574@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"Chad",
                 @"normalizedEmailAddress": @"574@example.com",
                 @"normalizedName": @"Chad"
                 },
             @{
                 @"accentColorValue": @5,
                 @"emailAddress": @"183@example.com",
                 @"modifiedDataFields": @0,
                 @"name": @"Daniel",
                 @"normalizedEmailAddress": @"183@example.com",
                 @"normalizedName": @"Daniel",
                 },
             ];
}

@end
