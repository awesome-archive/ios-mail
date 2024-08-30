//
//  ComposeViewModel.swift
//  Proton Mail - Created on 6/18/15.
//
//
//  Copyright (c) 2019 Proton AG
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

import Foundation
import PromiseKit
import CoreData
import ProtonCore_DataModel
import ProtonCore_Networking

protocol FileData {
    var name: String { get set }
    var ext: String { get set }
    var contents: AttachmentConvertible { get set }
}

struct ConcreteFileData: FileData {
    var name: String
    var ext: String
    var contents: AttachmentConvertible

    init(name: String, ext: String, contents: AttachmentConvertible) {
        self.name = name
        self.ext = ext
        self.contents = contents
    }
}

class ComposeViewModel: NSObject {
    let composerMessageHelper: ComposerMessageHelper
    let messageService: MessageDataService
    let coreDataContextProvider: CoreDataContextProviderProtocol
    let isEditingScheduleMsg: Bool
    let isOpenedFromShare: Bool
    let originalScheduledTime: OriginalScheduleDate?
    // we can't use `dependencies` as name bc it clashes with the subclass attribute of the same name
    let deps: Dependencies

    init(
        msgDataService: MessageDataService,
        contextProvider: CoreDataContextProviderProtocol,
        user: UserManager,
        isEditingScheduleMsg: Bool = false,
        isOpenedFromShare: Bool = false,
        originalScheduledTime: OriginalScheduleDate? = nil,
        dependencies: Dependencies
    ) {
        self.messageService = msgDataService
        self.coreDataContextProvider = contextProvider
        self.composerMessageHelper = ComposerMessageHelper(
            msgDataService: msgDataService,
            contextProvider: contextProvider,
            user: user,
            cacheService: user.cacheService
        )
        self.isEditingScheduleMsg = isEditingScheduleMsg
        self.isOpenedFromShare = isOpenedFromShare
        self.originalScheduledTime = originalScheduledTime
        self.deps = dependencies
    }

    /// Only to notify ComposeContainerViewModel that contacts changed
    @objc dynamic private(set) var contactsChange: Int = 0
    var messageAction : ComposeMessageAction = .newDraft
    var toSelectedContacts: [ContactPickerModelProtocol] = [] {
        didSet { self.contactsChange += 1 }
    }
    var ccSelectedContacts: [ContactPickerModelProtocol] = [] {
        didSet { self.contactsChange += 1 }
    }
    var bccSelectedContacts: [ContactPickerModelProtocol] = [] {
        didSet { self.contactsChange += 1 }
    }

    var showError: ((String) -> Void)?
    
    private var _subject : String! = ""
    var body : String! = ""
    var deliveryTime: Date?

    func getSubject() -> String {
        return self._subject
    }

    func setSubject(_ sub: String) {
        self._subject = sub
    }

    func setBody(_ body: String) {
        self.body = body
    }

     func addToContacts(_ contacts: ContactPickerModelProtocol! ) {
        toSelectedContacts.append(contacts)
    }

     func addCcContacts(_ contacts: ContactPickerModelProtocol! ) {
        ccSelectedContacts.append(contacts)
    }

     func addBccContacts(_ contacts: ContactPickerModelProtocol! ) {
        bccSelectedContacts.append(contacts)
    }

    func getActionType() -> ComposeMessageAction {
        return messageAction
    }

    func uploadMimeAttachments() {

    }

    func getUser() -> UserManager {
          fatalError("This method must be overridden")
    }

    func sendMessage(deliveryTime: Date?) {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
    }

    func updateDraft() {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
    }

    func deleteDraft() {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
    }

    func uploadAtt(_ att: Attachment!) {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
    }

    func deleteAtt(_ att: Attachment!) -> Promise<Void> {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
        return Promise()
    }

    func markAsRead() {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
    }

    func getHtmlBody() -> WebContents {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
        return WebContents(body: "", remoteContentMode: .lockdown)
    }

    func collectDraft(_ title: String, body: String, expir: TimeInterval, pwd: String, pwdHit: String) {
         NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
    }

    func updateEO(expirationTime: TimeInterval, pwd: String, pwdHint: String, completion: @escaping () -> Void) {
        NSException(name: NSExceptionName(rawValue: "name"), reason: "reason", userInfo: nil).raise()
        return completion()
    }

    func getAttachments() -> [Attachment]? {
        fatalError("This method must be overridden")
    }

    func updateAddressID (_ address_id: String) -> Promise<Void> {
        fatalError("This method must be overridden")
    }

    func getAddresses () -> [Address] {
        fatalError("This method must be overridden")
    }

    func getDefaultSendAddress() -> Address? {
        fatalError("This method must be overridden")
    }

    func fromAddress() -> Address? {
        fatalError("This method must be overridden")
    }

    func getCurrrentSignature(_ addr_id: String) -> String? {
        fatalError("This method must be overridden")
    }

    func lockerCheck(model: ContactPickerModelProtocol, progress: () -> Void, complete: ((UIImage?, Int) -> Void)?) {
        fatalError("This method must be overridden")
    }

    func checkMails(in contactGroup: ContactGroupVO, progress: () -> Void, complete: LockCheckComplete?) {
        fatalError("This method must be overridden")
    }

    func shouldShowExpirationWarning(havingPGPPinned: Bool,
                                     isPasswordSet: Bool,
                                     havingNonPMEmail: Bool) -> Bool {
        let helper = ComposeViewControllerHelper()
        return helper.shouldShowExpirationWarning(havingPGPPinned: havingPGPPinned,
                                                  isPasswordSet: isPasswordSet,
                                                  havingNonPMEmail: havingNonPMEmail)
    }

    func needAttachRemindAlert(subject: String, body: String) -> Bool {
        fatalError("This method must be overridden")
    }

    func isEmptyDraft() -> Bool {
        fatalError("This method must be overridden")
    }

    func embedInlineAttachments(in htmlEditor: HtmlEditorBehaviour) {
        guard let attachments = getAttachments() else { return }
        let inlineAttachments = attachments
            .filter({ attachment in
                guard let contentId = attachment.contentID() else { return false }
                return !contentId.isEmpty && attachment.inline()
            })
        let userKeys = getUser().toUserKeys()

        for att in inlineAttachments {
            guard let contentId = att.contentID() else { continue }
            deps.fetchAttachment.callbackOn(.main).execute(
                params: .init(
                    attachmentID: AttachmentID(att.attachmentID),
                    attachmentKeyPacket: att.keyPacket,
                    purpose: .decryptAndEncodeAttachment,
                    userKeys: userKeys
                )
            ) { result in
                guard let base64Att = try? result.get().encoded, !base64Att.isEmpty else {
                    return
                }
                htmlEditor.update(embedImage: "cid:\(contentId)", encoded:"data:\(att.mimeType);base64,\(base64Att)")
            }
        }
    }

	func isDraftHavingEmptyRecipient() -> Bool {
        return toSelectedContacts.isEmpty &&
        ccSelectedContacts.isEmpty &&
        bccSelectedContacts.isEmpty
    }

    func doesInvalidAddressExist() -> Bool {
        let allContacts = toSelectedContacts + ccSelectedContacts + bccSelectedContacts
        let invalidEmails = allContacts
            .filter { $0.modelType == .contact }
            .compactMap { $0 as? ContactVO }
            .filter {
                $0.encryptionIconStatus?.nonExisting == true ||
                $0.encryptionIconStatus?.isInvalid == true
            }
        return !invalidEmails.isEmpty
    }

    func shouldShowScheduleSendConfirmationAlert() -> Bool {
        return isEditingScheduleMsg && deliveryTime == nil
	}
}

extension ComposeViewModel {
    struct Dependencies {
        let fetchAttachment: FetchAttachmentUseCase
    }
}
