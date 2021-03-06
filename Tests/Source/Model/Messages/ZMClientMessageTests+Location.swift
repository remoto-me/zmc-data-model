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
import CoreLocation
@testable import ZMCDataModel

class ClientMessageTests_Location: BaseZMMessageTests {
 
    func testThatItReturnsLocationMessageDataWhenPresent() {
        // given
        let (longitude, latitude): (Float, Float) = (9.041169, 48.53775)
        let (name, zoom) = ("Tuebingen, Deutschland", Int32(3))
        let message = ZMGenericMessage.genericMessage(
            withLocation: .location(
                withLatitude: latitude,
                longitude: longitude,
                name: name,
                zoomLevel: zoom),
            messageID: NSUUID.createUUID().transportString()
        )
        
        // when
        let clientMessage = ZMClientMessage.insertNewObjectInManagedObjectContext(syncMOC)
        clientMessage.addData(message.data())
        
        // then
        let locationMessageData = clientMessage.locationMessageData
        XCTAssertNotNil(locationMessageData)
        XCTAssertEqual(locationMessageData?.latitude, latitude)
        XCTAssertEqual(locationMessageData?.longitude, longitude)
        XCTAssertEqual(locationMessageData?.name, name)
        XCTAssertEqual(locationMessageData?.zoomLevel, zoom)
    }
    
    func testThatItDoesNotReturnLocationMessageDataWhenNotPresent() {
        // given
        let clientMessage = ZMClientMessage.insertNewObjectInManagedObjectContext(syncMOC)
        
        // then
        XCTAssertNil(clientMessage.locationMessageData)
    }
    
}
