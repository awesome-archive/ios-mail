//
//  ComposeContainerViewCoordinator.swift
//  Proton Mail - Created on 15/04/2019.
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

#if !APP_EXTENSION
import ProtonCore_PaymentsUI
#endif
import ProtonCore_UIFoundations

class ComposeContainerViewCoordinator: TableContainerViewCoordinator {
    private weak var controller: ComposeContainerViewController!
    private weak var services: ServiceFactory!
    private let editorViewModel: ContainableComposeViewModel

    private(set) var header: ComposeHeaderViewController!
    var editor: ContainableComposeViewController?
    private var editorCoordinator: ComposeCoordinator?
    private(set) var attachmentView: ComposerAttachmentVC?
    private var attachmentsObservation: NSKeyValueObservation!
    private var messageObservation: NSKeyValueObservation!


#if !APP_EXTENSION
    private var paymentsUI: PaymentsUI?
    private weak var presentingViewController: UIViewController?

    init(presentingViewController: UIViewController?, editorViewModel: ContainableComposeViewModel, services: ServiceFactory = sharedServices) {
        self.presentingViewController = presentingViewController
        self.editorViewModel = editorViewModel
        self.services = services
    }
#else
    private weak var embeddingController: UINavigationController?

    init(embeddingController: UINavigationController?, editorViewModel: ContainableComposeViewModel, services: ServiceFactory = sharedServices) {
        self.embeddingController = embeddingController
        self.editorViewModel = editorViewModel
        self.services = services
    }
#endif

    deinit {
        self.attachmentsObservation = nil
        self.messageObservation = nil
    }

    #if !APP_EXTENSION
    func follow(_ deeplink: DeepLink) {
        // TODO
    }
    #endif

    func start() {
        let viewModel = ComposeContainerViewModel(
            editorViewModel: editorViewModel,
            uiDelegate: nil,
            userIntroductionProgressProvider: userCachedStatus,
            scheduleSendStatusProvider: userCachedStatus
        )
        let viewController = ComposeContainerViewController(viewModel: viewModel, coordinator: self)
        viewModel.uiDelegate = viewController

        self.controller = viewController

#if !APP_EXTENSION
        let navigationController = UINavigationController(rootViewController: viewController)
        presentingViewController?.present(navigationController, animated: true)
        if editorViewModel.isOpenedFromShare {
            presentPaymentView()
        }
#else
        embeddingController?.setViewControllers([viewController], animated: true)
#endif
    }

    internal func cancelAction(_ sender: UIBarButtonItem) {
        self.editor?.cancelAction()
    }
    @IBAction func sendAction(_ sender: UIBarButtonItem) {
        self.editor?.sendAction(sender)
    }

    func sendAction(deliveryTime: Date?) {
        self.editor?.sendAction(deliveryTime: deliveryTime)
    }

    internal func headerFrame() -> CGRect {
        return self.header.view.frame
    }

    internal func createEditor(_ childViewModel: ContainableComposeViewModel) {
        let coordinator = ComposeCoordinator(viewModel: childViewModel)
        let child = coordinator.start()
        child.injectHeader(self.header)
        child.enclosingScroller = self.controller
        coordinator.openScheduleSendActionSheet = { [weak self] in
            self?.controller.showScheduleSendActionSheet()
        }
        self.editorCoordinator = coordinator
        self.editor = child
    }

    internal func createHeader() -> ComposeHeaderViewController {
        self.header = ComposeHeaderViewController(nibName: String(describing: ComposeHeaderViewController.self), bundle: nil)
        return self.header
    }

    func createAttachmentView(childViewModel: ContainableComposeViewModel) -> ComposerAttachmentVC {

        // Mainly for inline attachment update
        // The inline attachment comes from `htmlEditor` and `ComposeViewController` can't access `ComposeContainerViewCoordinator`
        self.messageObservation = childViewModel.composerMessageHelper.observe(\.message, options: [.initial]) { [weak self] helper, _ in
            self?.attachmentsObservation = helper.message?.observe(\.attachments, options: [.new, .old]) { [weak self] message, change in
                let attachments = message.attachments.allObjects.compactMap { $0 as? Attachment }
                // Make the newly added attachment to the bottom of the attachment list.
                attachments.forEach {
                    if $0.order == -1 {
                        $0.order = Int32.max
                    }
                }
                let sortedAttachments = attachments.sorted(by: { $0.order < $1.order })
                self?.setAttachments(sortedAttachments, shouldUpload: false)
                #if APP_EXTENSION
                self?.controller.getSharedFiles()
                #endif
            }
        }

        let attachments = childViewModel.getAttachments() ?? []
        let dataService: CoreDataService = self.services.get(by: CoreDataService.self)
        let component = ComposerAttachmentVC(attachments: attachments, coreDataService: dataService, delegate: self)
        self.attachmentView = component
        self.controller.updateAttachmentCount(number: component.attachmentCount)
        component.addNotificationObserver()
        component.isUploading = { [weak self] in
            self?.controller.isUploadingAttachments = $0
        }
        return component
    }

    func getAttachmentSize(completion: @escaping ((Int) -> Void)) {
        guard let attachmentView = self.attachmentView else {
            completion(0)
            return
        }

        attachmentView.getSize(completeHandler: completion)
    }

    override func embedChild(indexPath: IndexPath, onto cell: UITableViewCell) {
        switch indexPath.row {
        case 0:
            self.embed(self.header, onto: cell.contentView, ownedBy: self.controller)
        case 1:
            cell.contentView.backgroundColor = ColorProvider.BackgroundNorm
            if let editor = editor {
                self.embed(editor, onto: cell.contentView, layoutGuide: cell.contentView.layoutMarginsGuide, ownedBy: self.controller)
            } else {
                assertionFailure("Child view is not initialized")
            }
        case 2:
            guard let component = self.attachmentView else { return }
            self.embed(component, onto: cell.contentView, ownedBy: self.controller)
        default:
            assert(false, "Children number misalignment")
            return
        }
    }

    func navigateToPassword() {
        self.editor?.autoSaveTimer()

        guard let password = self.editor?.encryptionPassword,
              let confirm = self.editor?.encryptionConfirmPassword,
              let hint = self.editor?.encryptionPasswordHint else {
            return
        }
        let passwordVC = ComposePasswordVC.instance(password: password,
                                                    confirmPassword: confirm,
                                                    hint: hint,
                                                    delegate: self)
        guard let navigationController = self.controller.navigationController else {
            return
        }
        navigationController.show(passwordVC, sender: nil)
    }

    func navigateToExpiration() {
        self.editor?.autoSaveTimer()

        let time = self.header.expirationTimeInterval
        let expirationVC = ComposeExpirationVC(expiration: time, delegate: self)
        guard let navigationController = self.controller.navigationController else {
            return
        }
        navigationController.show(expirationVC, sender: nil)
    }

    func addAttachment(_ attachment: Attachment, shouldUpload: Bool = true) {
        guard let message = self.editor?.viewModel.composerMessageHelper.message,
              let context = message.managedObjectContext else { return }
        context.performAndWait {
            attachment.message = message
            _ = context.saveUpstreamIfNeeded()
        }
        guard let component = self.attachmentView else { return }
        component.add(attachments: [attachment]) { [weak self] in
            DispatchQueue.main.async {
                let number = component.attachmentCount
                self?.controller.updateAttachmentCount(number: number)
            }
        }

        guard shouldUpload else { return }
        _ = self.editor?.attachments(pickup: attachment).done { [weak self] in
            let number = self?.attachmentView?.attachmentCount ?? 0
            self?.controller.updateAttachmentCount(number: number)
        }
    }

    private func setAttachments(_ attachments: [Attachment], shouldUpload: Bool) {
        guard let message = self.editor?.viewModel.composerMessageHelper.message,
              let context = message.managedObjectContext else { return }
        context.performAndWait {
            attachments.forEach { $0.message = message }
            _ = context.saveUpstreamIfNeeded()
        }
        guard let component = self.attachmentView else { return }
        component.set(attachments: attachments, context: context) { [weak self] in
            DispatchQueue.main.async {
                let number = component.attachmentCount
                self?.controller.updateAttachmentCount(number: number)
            }
        }

        guard shouldUpload else { return }
        attachments.forEach { [weak self] attachment in
            _ = self?.editor?.attachments(pickup: attachment).done { [weak self] in
                let number = self?.attachmentView?.attachmentCount ?? 0
                self?.controller.updateAttachmentCount(number: number)
            }
        }
    }

    func checkIfDraftIsValidToBeSent(continueAction: @escaping () -> Void) {
        editor?.displayDraftNotValidAlertIfNeeded(isTriggeredFromScheduleButton: true) {
            continueAction()
        }
    }

    func presentScheduleSendPromotionView() {
        editor?.collectDraftData().ensure { [weak self] in
            self?.editorViewModel.updateDraft()
            guard let nav = self?.controller.navigationController?.view else {
                return
            }
            let promotion = ScheduleSendPromotionView()
            promotion.presentPaymentUpgradeView = { [weak self] in
#if !APP_EXTENSION
                self?.presentPaymentView()
#else
                // Close the share extension and open the draft in main app.
                if let msgID = self?.editorViewModel.composerMessageHelper.messageID,
                   let url = URL(string: "protonmail://\(msgID)") {
                    self?.editor?.cancelAction()
                    _ = self?.editor?.openURL(url)
                }
#endif
            }
            promotion.viewWasDismissed = { [weak self] in
                self?.controller.showScheduleSendActionSheet()
            }
            promotion.present(on: nav)
        }.cauterize()
    }

#if !APP_EXTENSION
    private func presentPaymentView() {
        paymentsUI = PaymentsUI(
            payments: editorViewModel.getUser().payments,
            clientApp: .mail,
            shownPlanNames: Constants.shownPlanNames
        )
        paymentsUI?.showUpgradePlan(
            presentationType: .modal,
            backendFetch: true
        ) { _ in }
    }
#endif
}

extension ComposeContainerViewCoordinator: ComposePasswordDelegate {
    func apply(password: String, confirmPassword: String, hint: String) {
        self.editor?.encryptionPassword = password
        self.editor?.encryptionConfirmPassword = confirmPassword
        self.editor?.encryptionPasswordHint = hint
        self.editor?.updateEO()
        self.controller.setLockStatus(isLock: true)
    }

    func removedPassword() {
        self.editor?.encryptionPassword = ""
        self.editor?.encryptionConfirmPassword = ""
        self.editor?.encryptionPasswordHint = ""
        self.editor?.updateEO()
        self.controller.setLockStatus(isLock: false)
    }
}

extension ComposeContainerViewCoordinator: ComposeExpirationDelegate {
    func update(expiration: TimeInterval) {
        self.header.expirationTimeInterval = expiration
        self.controller.setExpirationStatus(isSetting: expiration > 0)
    }
}

extension ComposeContainerViewCoordinator: ComposerAttachmentVCDelegate {
    func composerAttachmentViewController(_ composerVC: ComposerAttachmentVC, didDelete attachment: Attachment) {
        self.editor?.view.endEditing(true)
        self.header.view.endEditing(true)
        self.controller.view.endEditing(true)
        _ = self.editor?.attachments(deleted: attachment).done { [weak self] in
            let number = composerVC.attachmentCount
            self?.controller.updateAttachmentCount(number: number)
            self?.controller.updateCurrentAttachmentSize(completion: nil)
        }
    }
}
