//
//  ComposingViewController.swift
//  Proton Mail - Created on 12/04/2019.
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
import LifetimeTracker
#endif
import MBProgressHUD
import PromiseKit
import ProtonCore_DataModel
import ProtonCore_Foundations
import ProtonCore_UIFoundations
import UIKit

protocol ComposeContainerUIProtocol: AnyObject {
    func updateSendButton()
}

class ComposeContainerViewController: TableContainerViewController<ComposeContainerViewModel, ComposeContainerViewCoordinator> {
    #if !APP_EXTENSION
    class var lifetimeConfiguration: LifetimeConfiguration {
        .init(maxCount: 1)
    }
    #endif
    private var childrenHeightObservations: [NSKeyValueObservation] = []
    private var cancelButton: UIBarButtonItem!
    private var sendButton: UIBarButtonItem!
    private var scheduledSendButton: UIBarButtonItem!
    private var bottomPadding: NSLayoutConstraint!
    private var dropLandingZone: UIView? // drag and drop session items dropped on this view will be added as attachments
    private let timerInterval: TimeInterval = 30
    private let toolBarHeight: CGFloat = 48
    private var syncTimer: Timer?
    private var toolbarBottom: NSLayoutConstraint!
    private var toolbar: ComposeToolbar!
    private var isAddingAttachment: Bool = false
    private var attachmentsReloaded = false
    private var scheduledSendHelper: ScheduledSendHelper!
    // MARK: Attachment variables
    let kDefaultAttachmentFileSize: Int = 25 * 1_000 * 1_000 // 25 mb
    private(set) var currentAttachmentSize: Int = 0
    lazy private(set) var attachmentProcessQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    lazy private(set) var attachmentProviders: [AttachmentProvider] = { [unowned self] in
        // There is no access to camera in AppExtensions, so should not include it into menu
        #if APP_EXTENSION
            return [PhotoAttachmentProvider(for: self),
                    DocumentAttachmentProvider(for: self)]
        #else
            return [PhotoAttachmentProvider(for: self),
                    CameraAttachmentProvider(for: self),
                    DocumentAttachmentProvider(for: self)]
        #endif
    }()
    private lazy var separatorView: UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = ColorProvider.Shade20
        return view
    }()

    var isUploadingAttachments: Bool = false {
        didSet {
            setupTopRightBarButton()
            setUpTitleView()
        }
    }

    private var isSendButtonTapped = false

    override init(
        viewModel: ComposeContainerViewModel,
        coordinator: ComposeContainerViewCoordinator
    ) {
        super.init(viewModel: viewModel, coordinator: coordinator)
        #if !APP_EXTENSION
        trackLifetime()
        #endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.childrenHeightObservations.forEach({ $0.invalidate() })
        NotificationCenter.default.removeKeyboardObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    private lazy var scheduleSendIntroView = ScheduledSendSpotlightView()

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        self.tableView.dropDelegate = self

        view.backgroundColor = ColorProvider.BackgroundNorm

        NotificationCenter.default.addKeyboardObserver(self)

        self.scheduledSendHelper = ScheduledSendHelper(viewController: self,
                                                       delegate: self,
                                                       originalScheduledTime: viewModel.childViewModel.originalScheduledTime)
        self.setupBottomPadding()
        self.configureNavigationBar()
        self.setupChildViewModel()
        self.setupToolbar()
        self.setupTopSeparatorView()
        self.emptyBackButtonTitleForNextView()
        let childVM = self.viewModel.childViewModel
        if childVM.shareOverLimitationAttachment {
            self.sizeError()
        }

        // accessibility
        generateAccessibilityIdentifiers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let attachmentView = self.coordinator.attachmentView {
            attachmentView.addNotificationObserver()
        }
        updateCurrentAttachmentSize(completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.startAutoSync()
        #if !APP_EXTENSION
        if #available(iOS 13.0, *) {
            self.view.window?.windowScene?.title = LocalString._general_draft_action
        }
        #endif

        generateAccessibilityIdentifiers()
        showScheduleSendIntroViewIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.stopAutoSync()

        guard let vcCounts = self.navigationController?.viewControllers.count else {
            return
        }
        if vcCounts == 1 {
            // Composer dismiss
            self.coordinator.attachmentView?.removeNotificationObserver()
        }
    }

    override func configureNavigationBar() {
        super.configureNavigationBar()

        self.navigationController?.navigationBar.barTintColor = ColorProvider.BackgroundNorm
        self.navigationController?.navigationBar.isTranslucent = false

        self.setupTopRightBarButton()
        self.setupCancelButton()
    }

    // tableView
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.backgroundColor = .white
        return cell
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)

        if let headerCell = tableView.cellForRow(at: .init(row: 0, section: 0)) {
            separatorView.isHidden = tableView.visibleCells.contains(headerCell)
        } else {
            separatorView.isHidden = false
        }
        guard let cell = tableView.cellForRow(at: .init(row: 2, section: 0)) else { return }

        let areAttachmentsVisibleOnScreen = cell.frame.minY < (scrollView.contentOffset.y + scrollView.frame.height)

        if !attachmentsReloaded && areAttachmentsVisibleOnScreen {
            attachmentsReloaded = true
            children.compactMap { $0 as? ComposerAttachmentVC }.first?.refreshAttachmentsLoadingState()
        }

        if attachmentsReloaded == true && areAttachmentsVisibleOnScreen == false {
            attachmentsReloaded = false
        }
    }

    // MARK: IBAction
    @objc
    func cancelAction(_ sender: UIBarButtonItem) {
        // FIXME: that logic should be in VM of EditorViewController
        self.coordinator.cancelAction(sender)
    }

    @objc
    func sendAction(_ sender: UIBarButtonItem) {
        // FIXME: that logic should be in VM of EditorViewController
        isSendButtonTapped = true
        self.coordinator.sendAction(sender)
    }

    #if APP_EXTENSION
    func getSharedFiles() {
        self.isAddingAttachment = true
    }
    #endif
}

// MARK: UI related
extension ComposeContainerViewController {
    private func setupBottomPadding() {
        self.bottomPadding = self.view.bottomAnchor.constraint(equalTo: self.tableView.bottomAnchor)
        self.bottomPadding.constant = UIDevice.safeGuide.bottom + toolBarHeight
        self.bottomPadding.isActive = true
    }

    private func setupChildViewModel() {
        let childViewModel = self.viewModel.childViewModel
        let header = self.coordinator.createHeader()
        self.coordinator.createEditor(childViewModel)
        let attachmentView = self.coordinator.createAttachmentView(childViewModel: childViewModel)

        self.childrenHeightObservations = [
            childViewModel.observe(\.contentHeight) { [weak self] _, _ in
                UIView.animate(withDuration: 0.001, animations: {
                    self?.saveOffset()
                    self?.tableView.beginUpdates()
                    self?.tableView.endUpdates()
                    self?.restoreOffset()
                })
            },
            header.observe(\.size) { [weak self] _, _ in
                self?.tableView.beginUpdates()
                self?.tableView.endUpdates()
            },
            attachmentView.observe(\.tableHeight) { [weak self] _, _ in
                DispatchQueue.main.async {
                    let path = IndexPath(row: 0, section: 0)
                    self?.tableView.beginUpdates()
                    if self?.tableView.cellForRow(at: path) == nil {
                        self?.tableView.reloadRows(at: [path], with: .none)
                    }
                    self?.tableView.endUpdates()
                    guard self?.isAddingAttachment ?? false else { return }
                    self?.isAddingAttachment = false
                    // A bit of delay can get real contentSize
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        var yOffset: CGFloat = 0
                        let contentHeight = self?.tableView.contentSize.height ?? 0
                        let sizeHeight = self?.tableView.bounds.size.height ?? 0
                        if contentHeight > sizeHeight {
                            yOffset = contentHeight - sizeHeight
                        }
                        self?.tableView.setContentOffset(CGPoint(x: 0, y: yOffset), animated: false)
                    }
                }
            }
        ]
    }

    private func setupTopRightBarButton() {
        self.setupSendButton()
        self.setupScheduledSendButton()
        var items: [UIBarButtonItem] = [self.sendButton]
        if viewModel.isScheduleSendEnable {
            items.append(self.scheduledSendButton)
        }
        self.navigationItem.rightBarButtonItems = items
    }

    private func setupSendButton() {
        let isEnabled = viewModel.hasRecipients() && !isUploadingAttachments
        self.sendButton = Self.makeBarButtonItem(
            isEnabled: isEnabled,
            icon: IconProvider.paperPlaneHorizontal,
            target: self,
            action: #selector(sendAction)
        )

        self.sendButton.accessibilityLabel = LocalString._general_send_action
        self.sendButton.accessibilityIdentifier = "ComposeContainerViewController.sendButton"
    }

    private func setupScheduledSendButton() {
        guard viewModel.isScheduleSendEnable else { return }
        let icon = IconProvider.clockPaperPlane
        let isEnabled = viewModel.hasRecipients() && !isUploadingAttachments
        self.scheduledSendButton = Self.makeBarButtonItem(
            isEnabled: isEnabled,
            icon: icon,
            target: self,
            action: #selector(self.presentScheduleSendActionSheetIfDraftIsReady)
        )
        self.scheduledSendButton.accessibilityLabel = LocalString._general_schedule_send_action
        self.scheduledSendButton.accessibilityIdentifier = "ComposeContainerViewController.scheduledSend"
    }

    private static func makeBarButtonItem(
        isEnabled: Bool,
        icon: UIImage,
        target: Any?,
        action: Selector
    ) -> UIBarButtonItem {
        let tintColor: UIColor = isEnabled ? ColorProvider.IconNorm : ColorProvider.IconDisabled
        let item = icon.toUIBarButtonItem(
            target: target,
            action: isEnabled ? action : nil,
            style: .plain,
            tintColor: tintColor,
            squareSize: 22,
            backgroundColor: .clear,
            backgroundSquareSize: 35,
            isRound: true,
            imageInsets: .zero
        )
        return item
    }

    private func setUpTitleView() {
        guard !isSendButtonTapped else {
            navigationItem.titleView = nil
            return
        }
        navigationItem.titleView = isUploadingAttachments ? ComposeAttachmentsAreUploadingTitleView() : nil
    }

    private func setupCancelButton() {
        self.cancelButton = UIBarButtonItem(image: IconProvider.cross, style: .plain, target: self, action: #selector(cancelAction))
        self.cancelButton.accessibilityIdentifier = "ComposeContainerViewController.cancelButton"
        self.navigationItem.leftBarButtonItem = self.cancelButton
    }

    private func setupToolbar() {
        let bar = ComposeToolbar(delegate: self)
        bar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(bar)
        [
            bar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 48)
        ].activate()
        self.toolbarBottom = bar.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -1 * UIDevice.safeGuide.bottom)
        self.toolbarBottom.isActive = true
        self.toolbar = bar
    }

    private func setupTopSeparatorView() {
        view.addSubview(separatorView)
        [
            separatorView.topAnchor.constraint(equalTo: view.topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 2)
        ].activate()
        separatorView.isHidden = true
    }

    private func startAutoSync() {
        self.stopAutoSync()
        self.syncTimer = Timer.scheduledTimer(withTimeInterval: self.timerInterval, repeats: true, block: { [weak self](_) in
            self?.viewModel.syncMailSetting()
        })
    }

    private func stopAutoSync() {
        self.syncTimer?.invalidate()
        self.syncTimer = nil
    }

    private func showScheduleSendIntroViewIfNeeded() {
        guard viewModel.isScheduleSendEnable,
              !viewModel.isScheduleSendIntroViewShown else {
            return
        }
        viewModel.userHasSeenScheduledSendSpotlight()

        guard let navView = self.navigationController?.view,
              let scheduleItemView = self.scheduledSendButton.value(forKey: "view") as? UIView,
              let targetView = scheduleItemView.subviews.first else {
                  return
              }
        let barFrame = targetView.frame
        let rect = scheduleItemView.convert(barFrame, to: navView)
        scheduleSendIntroView.presentOn(view: navView,
                                        targetFrame: rect)
    }

    @objc
    private func presentScheduleSendActionSheetIfDraftIsReady() {
        // Check draft is valid or not.
        coordinator.checkIfDraftIsValidToBeSent { [weak self] in
            self?.showScheduleSendActionSheet()
        }
    }
}

extension ComposeContainerViewController: ComposeContainerUIProtocol {
    func updateSendButton() {
        self.setupTopRightBarButton()
    }

    func setLockStatus(isLock: Bool) {
        self.toolbar.setLockStatus(isLock: isLock)
    }

    func setExpirationStatus(isSetting: Bool) {
        self.toolbar.setExpirationStatus(isSetting: isSetting)
    }

    func updateAttachmentCount(number: Int) {
        DispatchQueue.main.async {
            self.toolbar.setAttachment(number: number)
        }
    }

    func updateCurrentAttachmentSize(completion: (() -> Void)?) {
        self.coordinator.getAttachmentSize() { [weak self] size in
            self?.currentAttachmentSize = size
            completion?()
        }
    }

    func showScheduleSendActionSheet() {
        scheduledSendHelper.presentActionSheet()
    }
}

extension ComposeContainerViewController: NSNotificationCenterKeyboardObserverProtocol {
    func keyboardWillHideNotification(_ notification: Notification) {
        self.bottomPadding.constant = UIDevice.safeGuide.bottom + toolBarHeight
        self.toolbarBottom.constant = -1 * UIDevice.safeGuide.bottom
    }

    func keyboardWillShowNotification(_ notification: Notification) {
        updateLayoutWithKeyboard(notification)
    }

    func keyboardDidShowNotification(_ notification: Notification) {
        updateLayoutWithKeyboard(notification)
    }

    private func updateLayoutWithKeyboard(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let window = view.window else {
            return
        }
        let bottomLeftPoint = CGPoint(x: 0, y: view.frame.height)
        let convertedPoint = view.convert(bottomLeftPoint, to: window)
        let screenHeight = window.screen.bounds.height
        let presentedVCToBottom = screenHeight - convertedPoint.y
        let heightToAddForKeyboard = keyboardFrame.cgRectValue.height - presentedVCToBottom

        self.bottomPadding.constant = heightToAddForKeyboard + toolBarHeight
        self.toolbarBottom.constant = -1 * heightToAddForKeyboard
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }
}

extension ComposeContainerViewController: UITableViewDropDelegate {
    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView,
                   canHandle session: UIDropSession) -> Bool {
        // return true only if all the files are supported
        let itemProviders = session.items.map { $0.itemProvider }
        return self.viewModel.filesAreSupported(from: itemProviders)
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView,
                   dropSessionDidUpdate session: UIDropSession,
                   withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return UITableViewDropProposal(operation: .copy, intent: .insertIntoDestinationIndexPath)
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, dropSessionDidEnter session: UIDropSession) {
        if self.dropLandingZone == nil {
            var dropFrame = self.tableView.frame
            dropFrame.size.height = self.coordinator.headerFrame().size.height
            let dropZone = DropLandingZone(frame: dropFrame)
            dropZone.alpha = 0.0
            self.tableView.addSubview(dropZone)
            self.dropLandingZone = dropZone
        }

        UIView.animate(withDuration: 0.3) {
            self.dropLandingZone?.alpha = 1.0
        }
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, dropSessionDidExit session: UIDropSession) {
        UIView.animate(withDuration: 0.3, animations: {
            self.dropLandingZone?.alpha = 0.0
        })
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView, dropSessionDidEnd session: UIDropSession) {
        UIView.animate(withDuration: 0.3, animations: {
            self.dropLandingZone?.alpha = 0.0
        }) { _ in
            self.dropLandingZone?.removeFromSuperview()
            self.dropLandingZone = nil
        }
    }

    @available(iOS 11.0, *)
    func tableView(_ tableView: UITableView,
                   performDropWith coordinator: UITableViewDropCoordinator) {
        DispatchQueue.main.async {
            LocalString._importing_drop.alertToastBottom(view: self.view)
        }

        let itemProviders = coordinator.items.map { $0.dragItem.itemProvider }
        self.viewModel.importFiles(from: itemProviders, errorHandler: self.error) {
            DispatchQueue.main.async {
                LocalString._drop_finished.alertToastBottom(view: self.view)
            }
        }
    }
}

extension ComposeContainerViewController: ComposeToolbarDelegate {
    func showEncryptOutsideView() {
        self.view.endEditing(true)
        self.coordinator.navigateToPassword()
    }

    func showExpireView() {
        self.view.endEditing(true)
        self.coordinator.navigateToExpiration()
    }

    func showAttachmentView() {
        if self.viewModel.user.isStorageExceeded {
            LocalString._storage_exceeded.alertToast(withTitle: false, view: self.view)
            return
        }
        self.coordinator.header.view.endEditing(true)
        self.coordinator.editor?.view.endEditing(true)
        self.coordinator.attachmentView?.view.endEditing(true)
        self.view.endEditing(true)

        var sheet: PMActionSheet!

        let left = PMActionSheetPlainItem(title: nil, icon: IconProvider.cross) { (_) -> Void in
            sheet.dismiss(animated: true)
        }

        let header = PMActionSheetHeaderView(title: LocalString._menu_add_attachment, subtitle: nil, leftItem: left, rightItem: nil, hasSeparator: false)
        let itemGroup = self.getActionSheetItemGroup()
        sheet = PMActionSheet(headerView: header, itemGroups: [itemGroup], showDragBar: false)
        let viewController = self.navigationController ?? self
        sheet.presentAt(viewController, animated: true)
    }

    private func getActionSheetItemGroup() -> PMActionSheetItemGroup {
        let items: [PMActionSheetItem] = self.attachmentProviders.map(\.actionSheetItem)
        let itemGroup = PMActionSheetItemGroup(items: items, style: .clickable)
        return itemGroup
    }
}

extension ComposeContainerViewController: AttachmentController {
    func error(title: String, description: String) {
        let alert = description.alertController(title)
        alert.addOKAction()
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }

    func fileSuccessfullyImported(as fileData: FileData) -> Promise<Void> {
        return Promise { [weak self] seal in
            guard let self = self else {
                seal.fulfill_()
                return
            }
            self.attachmentProcessQueue.addOperation { [weak self] in
                guard let self = self else {
                    seal.fulfill_()
                    return
                }
                if self.viewModel.user.isStorageExceeded {
                    DispatchQueue.main.async {
                        LocalString._storage_exceeded.alertToast()
                    }
                    seal.fulfill_()
                    return
                }
                let size = fileData.contents.dataSize

                let remainingSize = (self.kDefaultAttachmentFileSize - self.currentAttachmentSize)
                guard size < remainingSize else {
                    self.sizeError()
                    seal.fulfill_()
                    return
                }

                guard let message = self.coordinator.editor?.viewModel.composerMessageHelper.message,
                      message.managedObjectContext != nil else {
                    self.error(LocalString._system_cant_copy_the_file)
                    seal.fulfill_()
                    return
                }

                let stripMetadata = userCachedStatus.metadataStripping == .stripMetadata

                let attachment = `await`(fileData.contents.toAttachment(message, fileName: fileData.name, type: fileData.ext, stripMetadata: stripMetadata, isInline: false))
                guard let att = attachment else {
                    self.error(LocalString._cant_copy_the_file)
                    return
                }
                self.isAddingAttachment = true
                self.coordinator.addAttachment(att)
                self.viewModel.user.usedSpace(plus: Int64(size))

                let group = DispatchGroup()
                group.enter()
                self.updateCurrentAttachmentSize(completion: {
                    seal.fulfill_()
                    group.leave()
                })
                // This prevents the current block is returned before the attachment size is updated.
                group.wait()
            }
        }
    }

    func error(_ description: String) {
        let alert = description.alertController()
        alert.addOKAction()
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func sizeError() {
        DispatchQueue.main.async {
            let title = LocalString._attachment_limit
            let message = LocalString._the_total_attachment_size_cant_be_bigger_than_25mb
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addOKAction()
            self.present(alert, animated: true, completion: nil)
        }
    }
}

// MARK: Scheduled send related
extension ComposeContainerViewController: ScheduledSendHelperDelegate {
    func showScheduleSendPromotionView() {
        coordinator.presentScheduleSendPromotionView()
    }

    func isItAPaidUser() -> Bool {
        return viewModel.user.isPaid
    }

    func showSendInTheFutureAlert() {
        let alert = LocalString._schedule_send_future_warning.alertController()
        alert.addOKAction()
        present(alert, animated: true)
    }

    func scheduledTimeIsSet(date: Date?) {
        MBProgressHUD.showAdded(to: self.view, animated: true)
        self.viewModel.allowScheduledSend { [weak self] isAllowed in
            guard let self = self else { return }
            MBProgressHUD.hide(for: self.view, animated: true)
            guard isAllowed else {
                NotificationCenter.default.post(name: .showScheduleSendUnavailable, object: nil)
                return
            }
            self.coordinator.sendAction(deliveryTime: date)
        }
    }
}
