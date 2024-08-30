//
//  MessageActionCodableTests.swift
//  Proton Mail
//
//
//  Copyright (c) 2021 Proton AG
//
//  This file is part of Proton Mail.
//
//  Proton Mail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton Mail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton Mail.  If not, see <https://www.gnu.org/licenses/>.

@testable import ProtonMail
import XCTest

class MessageActionCodableTests: XCTestCase {
    func checkIfAllCasesAreTested() {
        let action: MessageAction = Bool.random() ? .emptySpam : .emptyTrash
        switch action {
        case .saveDraft, .uploadAtt, .uploadPubkey, .deleteAtt, .read, .unread, .delete, .send, .emptyTrash,
             .emptySpam, .empty, .label, .unlabel, .folder, .updateLabel, .createLabel, .deleteLabel, .signout,
             .signin, .fetchMessageDetail, .updateAttKeyPacket, .updateContact, .deleteContact, .addContact,
             .addContactGroup, .updateContactGroup, .deleteContactGroup, .notificationAction:
            break
        }
    }

    func testSaveDraft() throws {
        let action: MessageAction = .saveDraft(messageObjectID: "aDraft")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testUploadAtt() throws {
        let action: MessageAction = .uploadAtt(attachmentObjectID: "AnAttachment")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testUploadPubkey() throws {
        let action: MessageAction = .uploadPubkey(attachmentObjectID: "PubKeyAttachment")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testUpdate() throws {
        let action: MessageAction = .updateAttKeyPacket(messageObjectID: "AObjectID", addressID: "AnAddressID")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testDeleteAtt() throws {
        let action: MessageAction = .deleteAtt(attachmentObjectID: "DeleteAtt", attachmentID: nil)
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)

        let actionWithAttID: MessageAction = .deleteAtt(attachmentObjectID: "DeleteAtt", attachmentID: "attachmentID")
        let encoded2 = try JSONEncoder().encode(actionWithAttID)
        let decoded2 = try JSONDecoder().decode(MessageAction.self, from: encoded2)
        XCTAssertEqual(actionWithAttID, decoded2)
    }

    func testRead() throws {
        let action: MessageAction = .read(itemIDs: ["item1", "item2"], objectIDs: ["object1", "object2"])
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
        let action2: MessageAction = .read(itemIDs: [], objectIDs: [])
        let encoded2 = try JSONEncoder().encode(action2)
        let decoded2 = try JSONDecoder().decode(MessageAction.self, from: encoded2)
        XCTAssertEqual(action2, decoded2)
    }

    func testUnread() throws {
        let action: MessageAction = .unread(currentLabelID: "aLabelID", itemIDs: ["item1", "item2"], objectIDs: ["object1", "object2"])
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
        let action2: MessageAction = .unread(currentLabelID: "aLabelID", itemIDs: [], objectIDs: [])
        let encoded2 = try JSONEncoder().encode(action2)
        let decoded2 = try JSONDecoder().decode(MessageAction.self, from: encoded2)
        XCTAssertEqual(action2, decoded2)
    }

    func testDelete() throws {
        let action: MessageAction = .delete(currentLabelID: "anID", itemIDs: ["object1", "object2"])
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
        let action2: MessageAction = .delete(currentLabelID: nil, itemIDs: [])
        let encoded2 = try JSONEncoder().encode(action2)
        let decoded2 = try JSONDecoder().decode(MessageAction.self, from: encoded2)
        XCTAssertEqual(action2, decoded2)
    }

    func testSend() throws {
        let action: MessageAction = .send(messageObjectID: "sendID", deliveryTime: nil)
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testEmptyTrash() throws {
        let action: MessageAction = .emptyTrash
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testEmptySpam() throws {
        let action: MessageAction = .emptySpam
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testEmpty() throws {
        let action: MessageAction = .empty(currentLabelID: "anID")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testLabel() throws {
        let action: MessageAction = .label(currentLabelID: "label", shouldFetch: true, isSwipeAction: false, itemIDs: ["bla"], objectIDs: ["foo"])
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
        let action2: MessageAction = .label(currentLabelID: "label", shouldFetch: nil, isSwipeAction: true, itemIDs: [], objectIDs: [])
        let encoded2 = try JSONEncoder().encode(action2)
        let decoded2 = try JSONDecoder().decode(MessageAction.self, from: encoded2)
        XCTAssertEqual(action2, decoded2)
    }

    func testUnlabel() throws {
        let action: MessageAction = .unlabel(currentLabelID: "label", shouldFetch: true, isSwipeAction: false, itemIDs: ["bla"], objectIDs: ["foo"])
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
        let action2: MessageAction = .unlabel(currentLabelID: "label", shouldFetch: nil, isSwipeAction: true, itemIDs: [], objectIDs: [])
        let encoded2 = try JSONEncoder().encode(action2)
        let decoded2 = try JSONDecoder().decode(MessageAction.self, from: encoded2)
        XCTAssertEqual(action2, decoded2)
    }

    func testFolder() throws {
        let action: MessageAction = .folder(nextLabelID: "next", shouldFetch: false, isSwipeAction: false, itemIDs: ["items"], objectIDs: ["objects"])
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
        let action2: MessageAction = .folder(nextLabelID: "next", shouldFetch: true, isSwipeAction: true, itemIDs: [], objectIDs: [])
        let encoded2 = try JSONEncoder().encode(action2)
        let decoded2 = try JSONDecoder().decode(MessageAction.self, from: encoded2)
        XCTAssertEqual(action2, decoded2)
    }

    func testUpdateLabel() throws {
        let action: MessageAction = .updateLabel(labelID: "labelID", name: "name", color: "color")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testCreateLabel() throws {
        let action: MessageAction = .createLabel(name: "name", color: "color", isFolder: true)
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testDeleteLabel() throws {
        let action: MessageAction = .deleteLabel(labelID: "label")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testSignout() throws {
        let action: MessageAction = .signout
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testSignin() throws {
        let action: MessageAction = .signin
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testFetchMessageDetail() throws {
        let action: MessageAction = .fetchMessageDetail
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testUpdateContact() throws {
        let cardDatas: [CardData] = [.init(type: .PlainText, data: "data", signature: "sign")]
        let action: MessageAction = .updateContact(objectID: "objectID",
                                                   cardDatas: cardDatas)
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testDeleteContact() throws {
        let action: MessageAction = .deleteContactGroup(objectID: "deleteObjectID")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testAddContact() throws {
        let cardDatas: [CardData] = [.init(type: .PlainText, data: "data", signature: "sign")]
        let action: MessageAction = .addContact(objectID: "addObjectID",
                                                cardDatas: cardDatas,
                                                importFromDevice: Bool.random())
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testAddContactGroup() throws {
        let emailIDs = ["id 1", "id 2"]
        let action: MessageAction = .addContactGroup(objectID: "addGroupObjectID", name: "group name", color: "group color", emailIDs: emailIDs)
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testUpdateContactGroup() throws {
        let addedEmailIDs = ["add id 1", "add id 2"]
        let removedEmailIDs = ["removed id 1", "removed id 2"]
        let action: MessageAction = .updateContactGroup(objectID: "updateGroupobjectID", name: "a name", color: "a color", addedEmailList: addedEmailIDs, removedEmailList: removedEmailIDs)
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }

    func testDeleteContactGroup() throws {
        let action: MessageAction = .deleteContactGroup(objectID: "delete group objectID")
        let encoded = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(MessageAction.self, from: encoded)
        XCTAssertEqual(action, decoded)
    }
}
