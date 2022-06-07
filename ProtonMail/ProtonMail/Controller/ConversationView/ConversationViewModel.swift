import CoreData
import ProtonCore_UIFoundations

enum MessageDisplayRule {
    case showNonTrashedOnly
    case showTrashedOnly
    case showAll
}

// swiftlint:disable type_body_length
class ConversationViewModel {
    var headerSectionDataSource: [ConversationViewItemType] = []
    var messagesDataSource: [ConversationViewItemType] = [] {
        didSet {
            guard messagesDataSource != oldValue else {
                return
            }
            refreshView?()
        }
    }
    private(set) var displayRule = MessageDisplayRule.showNonTrashedOnly
    var refreshView: (() -> Void)?
    var dismissView: (() -> Void)?
    var reloadRows: (([IndexPath]) -> Void)?
    var leaveFocusedMode: (() -> Void)?
    var dismissDeletedMessageActionSheet: ((String) -> Void)?
    var viewModeIsChanged: ((ViewMode) -> Void)?

    var showNewMessageArrivedFloaty: ((String) -> Void)?

    var messagesTitle: String {
        .localizedStringWithFormat(LocalString._general_message, conversation.numMessages.intValue)
    }

    var simpleNavigationViewType: NavigationViewType {
        .simple(numberOfMessages: messagesTitle.apply(style: FontManager.body3RegularWeak))
    }

    var detailedNavigationViewType: NavigationViewType {
        .detailed(
            subject: conversation.subject.apply(style: FontManager.DefaultSmallStrong.lineBreakMode(.byTruncatingTail)),
            numberOfMessages: messagesTitle.apply(style: FontManager.OverlineRegularTextWeak)
        )
    }

    let conversation: Conversation
    let labelId: String
    let user: UserManager
    let messageService: MessageDataService
    /// MessageID that want to expand at the begining
    let targetID: String?
    private let conversationMessagesProvider: ConversationMessagesProvider
    private let conversationUpdateProvider: ConversationUpdateProvider
    private let conversationService: ConversationProvider
    private let eventsService: EventsFetching
    private let contactService: ContactDataService
    private let contextProvider: CoreDataContextProviderProtocol
    private let sharedReplacingEmails: [Email]
    private(set) weak var tableView: UITableView?
    var selectedMoveToFolder: MenuLabel?
    var selectedLabelAsLabels: Set<LabelLocation> = Set()
    var shouldIgnoreUpdateOnce = false
    var isTrashFolder: Bool { self.labelId == LabelLocation.trash.labelID }
    weak var conversationViewController: ConversationViewController?

    /// Used to decide if there is any new messages coming
    private var recordNumOfMessages = 0
    private(set) var isExpandedAtLaunch = false

    /// Focused mode means that the messages above the first expanded one are hidden from view.
    private(set) var focusedMode = true

    var firstExpandedMessageIndex: Int? {
        messagesDataSource.firstIndex(where: { $0.messageViewModel?.state.isExpanded ?? false })
    }

    var shouldDisplayConversationNoticeView: Bool {
        return conversationNoticeViewStatusProvider
            .conversationNoticeIsOpened == false
        // Check if the account is logged-in on the app with version before 3.1.6.
        && conversationNoticeViewStatusProvider.initialUserLoggedInVersion == nil
        && messagesDataSource.count > 1
    }

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    let isDarkModeEnableClosure: () -> Bool
    let connectionStatusProvider: InternetConnectionStatusProvider
    private var conversationNoticeViewStatusProvider: ConversationNoticeViewStatusProvider
    var isInitialDataFetchCalled = false
    private let conversationStateProvider: ConversationStateProviderProtocol
    /// This is used to restore the message status when the view mode is changed.
    var messageIDsOfMarkedAsRead: [String] = []

    init(labelId: String,
         conversation: Conversation,
         user: UserManager,
         contextProvider: CoreDataContextProviderProtocol,
         internetStatusProvider: InternetConnectionStatusProvider,
         isDarkModeEnableClosure: @escaping () -> Bool,
         conversationNoticeViewStatusProvider: ConversationNoticeViewStatusProvider,
         conversationStateProvider: ConversationStateProviderProtocol,
         targetID: String? = nil) {
        self.labelId = labelId
        self.conversation = conversation
        self.messageService = user.messageService
        self.conversationService = user.conversationService
        self.contactService = user.contactService
        self.eventsService = user.eventsService
        self.contextProvider = contextProvider
        self.user = user
        self.conversationMessagesProvider = ConversationMessagesProvider(conversation: conversation,
                                                                         contextProvider: contextProvider)
        self.conversationUpdateProvider = ConversationUpdateProvider(conversationID: conversation.conversationID,
                                                                     contextProvider: contextProvider)
        self.sharedReplacingEmails = contactService.allAccountEmails()
        self.targetID = targetID
        self.isDarkModeEnableClosure = isDarkModeEnableClosure
        self.conversationNoticeViewStatusProvider = conversationNoticeViewStatusProvider
        self.conversationStateProvider = conversationStateProvider
        headerSectionDataSource = [.header(subject: conversation.subject)]

        recordNumOfMessages = conversation.numMessages.intValue
        self.connectionStatusProvider = internetStatusProvider
        self.displayRule = self.isTrashFolder ? .showTrashedOnly: .showNonTrashedOnly
        self.conversationStateProvider.add(delegate: self)
    }

    func scrollViewDidScroll() {
        if focusedMode {
            focusedMode = false

            leaveFocusedMode?()
        }
    }

    func fetchConversationDetails(completion: (() -> Void)?) {
        conversationService.fetchConversation(
            with: conversation.conversationID,
            includeBodyOf: nil,
            callOrigin: "ConversationViewModel"
        ) { _ in
            completion?()
        }
    }

    func message(by objectID: NSManagedObjectID) -> Message? {
        conversationMessagesProvider.message(by: objectID)
    }

    func observeConversationUpdate() {
        conversationUpdateProvider.observe { [weak self] in
            self?.refreshView?()
        }
    }

    func observeConversationMessages(tableView: UITableView) {
        self.tableView = tableView
        conversationMessagesProvider.observe { [weak self] update in
            self?.perform(update: update, on: tableView)
            self?.checkTrashedHintBanner()
            if case .didUpdate = update {
                self?.reloadRowsIfNeeded()
            }
        } storedMessages: { [weak self] messages in
            self?.checkTrashedHintBanner()
            var messageDataModels = messages.compactMap { self?.messageType(with: $0) }

            if messages.count == self?.conversation.numMessages.intValue {
                _ = self?.expandSpecificMessage(dataModels: &messageDataModels)
            }
            self?.messagesDataSource = messageDataModels
        }
    }

    func setCellIsExpandedAtLaunch() {
        self.isExpandedAtLaunch = true
    }

    func messageType(with message: Message) -> ConversationViewItemType {
        let viewModel = ConversationMessageViewModel(labelId: labelId,
                                                     message: message,
                                                     user: user,
                                                     replacingEmails: sharedReplacingEmails,
                                                     internetStatusProvider: connectionStatusProvider,
                                                     isDarkModeEnableClosure: isDarkModeEnableClosure)
        return .message(viewModel: viewModel)
    }

    func getMessageHeaderUrl(message: Message) -> URL? {
        let time = dateFormatter.string(from: message.time ?? Date())
        let title = message.title.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let filename = "headers-" + time + "-" + title.joined(separator: "-")
        guard let header = message.header else {
            assert(false, "No header in message")
            return nil
        }
        return try? self.writeToTemporaryUrl(header, filename: filename)
    }

    func getMessageBodyUrl(message: Message) -> URL? {
        let time = dateFormatter.string(from: message.time ?? Date())
        let title = message.title.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let filename = "body-" + time + "-" + title.joined(separator: "-")
        guard let body = try? messageService.messageDecrypter.decrypt(message: message) else {
            return nil
        }
        return try? self.writeToTemporaryUrl(body, filename: filename)
    }

    func shouldTrashedHintBannerUseShowButton() -> Bool {
        if self.isTrashFolder {
            return self.displayRule == .showTrashedOnly ? true: false
        } else {
            return self.displayRule == .showNonTrashedOnly ? true: false
        }
    }

    func startMonitorConnectionStatus(isApplicationActive: @escaping () -> Bool,
                                      reloadWhenAppIsActive: @escaping (Bool) -> Void) {
        connectionStatusProvider.registerConnectionStatus { [weak self] networkStatus in
            guard self?.isInitialDataFetchCalled == true else {
                return
            }
            let isApplicationActive = isApplicationActive()
            switch isApplicationActive {
            case true where networkStatus == .notConnected:
                break
            case true:
                self?.fetchConversationDetails(completion: nil)
            default:
                reloadWhenAppIsActive(true)
            }
        }
    }

    func conversationNoticeViewIsOpened() {
        conversationNoticeViewStatusProvider.conversationNoticeIsOpened = true
    }

    /// Add trashed hint banner if the messages contain trashed message
    private func checkTrashedHintBanner() {
        let hasMessages = !self.messagesDataSource.isEmpty
        guard hasMessages else { return }
        let trashed = self.messagesDataSource
            .filter { $0.messageViewModel?.isTrashed ?? false }
        let hasTrashed = !trashed.isEmpty
        let isAllTrashed = trashed.count == self.messagesDataSource.count
        if self.isTrashFolder {
            self.checkTrashedHintBannerForTrashFolder(hasTrashed: hasTrashed,
                                                      isAllTrashed: isAllTrashed)
        } else {
            self.checkTrashedHintBannerForNonTrashFolder(hasTrashed: hasTrashed,
                                                         isAllTrashed: isAllTrashed)
        }
    }

    private func checkTrashedHintBannerForTrashFolder(hasTrashed: Bool, isAllTrashed: Bool) {
        guard hasTrashed else {
            self.removeTrashedHintBanner()
            // In trash folder, without trashed message
            // Should show non trashed messages
            self.displayRule = .showNonTrashedOnly
            self.removeTrashedHintBanner()
            return
        }
        if self.displayRule == .showNonTrashedOnly {
            self.displayRule = .showTrashedOnly
        }
        isAllTrashed ? self.removeTrashedHintBanner(): self.showTrashedHintBanner()
    }

    private func checkTrashedHintBannerForNonTrashFolder(hasTrashed: Bool, isAllTrashed: Bool) {
        if isAllTrashed {
            // In non trash folder, without trashed message
            // Should show trashed messages
            self.displayRule = .showTrashedOnly
            self.removeTrashedHintBanner()
            return
        }
        if self.displayRule == .showTrashedOnly {
            self.displayRule = .showNonTrashedOnly
        }
        hasTrashed ? self.showTrashedHintBanner(): self.removeTrashedHintBanner()
    }

    private func removeTrashedHintBanner() {
        guard let index = self.headerSectionDataSource.firstIndex(of: .trashedHint) else { return }
        self.headerSectionDataSource.remove(at: index)
        let visible = self.tableView?.visibleCells.count ?? 0
        if visible > 0 {
            let row = IndexPath(row: 1, section: 0)
            self.tableView?.deleteRows(at: [row], with: .automatic)
        }
    }

    private func showTrashedHintBanner() {
        if self.headerSectionDataSource.contains(.trashedHint) { return }
        self.headerSectionDataSource.append(.trashedHint)
        let visible = self.tableView?.visibleCells.count ?? 0
        if visible > 0 {
            let row = IndexPath(row: 1, section: 0)
            self.tableView?.insertRows(at: [row], with: .automatic)
        }
    }

    private func writeToTemporaryUrl(_ content: String, filename: String) throws -> URL {
        let tempFileUri = FileManager.default.temporaryDirectoryUrl
            .appendingPathComponent(filename, isDirectory: false).appendingPathExtension("txt")
        try? FileManager.default.removeItem(at: tempFileUri)
        try content.write(to: tempFileUri, atomically: true, encoding: .utf8)
        return tempFileUri
    }

    private func observeNewMessages() {
        if messagesDataSource.count > recordNumOfMessages && messagesDataSource.last?.message?.draft == false {
            showNewMessageArrivedFloaty?(messagesDataSource.newestMessage?.messageID ?? "")
        }
        recordNumOfMessages = messagesDataSource.count
    }

    private func updateDataSource(with messages: [Message]) {
        messagesDataSource = messages.map { newMessage -> ConversationViewItemType in
            if let viewModel = messagesDataSource.first(where: { $0.message?.messageID == newMessage.messageID }) {
                return viewModel
            }
            return messageType(with: newMessage)
        }
        if self.messagesDataSource.isEmpty {
            let context = contextProvider.rootSavingContext
            context.perform { [weak self] in
                guard let self = self,
                      let object = try? context.existingObject(with: self.conversation.objectID) else {
                          self?.dismissView?()
                    return
                }
                context.delete(object)
                self.dismissView?()
            }
        }
    }
}

// MARK: - Actions
extension ConversationViewModel {
    private func perform(update: ConversationUpdateType, on tableView: UITableView) {
        switch update {
        case .willUpdate:
            tableView.beginUpdates()
        case let .didUpdate(messages):
            updateDataSource(with: messages)
            tableView.endUpdates()

            observeNewMessages()

            if !isExpandedAtLaunch && recordNumOfMessages == messagesDataSource.count && !shouldIgnoreUpdateOnce {
                if let path = self.expandSpecificMessage(dataModels: &self.messagesDataSource) {
                    tableView.reloadRows(at: [path], with: .automatic)
                    self.conversationViewController?.attemptAutoScroll(to: path, position: .top)
                    setCellIsExpandedAtLaunch()
                }
            }
            shouldIgnoreUpdateOnce = false

            refreshView?()
        case let .insert(row):
            tableView.insertRows(at: [.init(row: row, section: 1)], with: .automatic)
        case let .update(message, _, _):
            let messageId = message.messageID
            guard let index = messagesDataSource.firstIndex(where: { $0.message?.messageID == messageId }),
                  let viewModel = messagesDataSource[index].messageViewModel else {
                      return
                  }
            viewModel.messageHasChanged(message: message)

            guard viewModel.state.isExpanded else {
                viewModel.state.collapsedViewModel?.messageHasChanged(message: message)
                return
            }
            viewModel.state.expandedViewModel?.message = message
        case let .delete(row, messageID):
            tableView.deleteRows(at: [.init(row: row, section: 1)], with: .automatic)
            dismissDeletedMessageActionSheet?(messageID)
        case let .move(fromRow, toRow):
            guard fromRow != toRow else { return }
            tableView.moveRow(at: .init(row: fromRow, section: 1), to: .init(row: toRow, section: 1))
        }
    }

    func starTapped(completion: @escaping (Result<Bool, Error>) -> Void) {
        if conversation.starred {
            conversationService.unlabel(conversationIDs: [conversation.conversationID],
                                        as: Message.Location.starred.rawValue,
                                        isSwipeAction: false) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    completion(.success(false))
                    self.eventsService.fetchEvents(labelID: self.labelId)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            conversationService.label(conversationIDs: [conversation.conversationID],
                                      as: Message.Location.starred.rawValue,
                                      isSwipeAction: false) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success:
                    completion(.success(true))
                    self.eventsService.fetchEvents(labelID: self.labelId)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

    func handleToolBarAction(_ action: MailboxViewModel.ActionTypes) {
        switch action {
        case .delete:
            conversationService.deleteConversations(with: [conversation.conversationID],
                                                    labelID: labelId) { [weak self] result in
                guard let self = self else { return }
                if (try? result.get()) != nil {
                    self.eventsService.fetchEvents(labelID: self.labelId)
                }
            }
        case .readUnread:
            if conversation.isUnread(labelID: labelId) {
                conversationService.markAsRead(
                    conversationIDs: [conversation.conversationID],
                    labelID: labelId
                ) { [weak self] result in
                    guard let self = self else { return }
                    if (try? result.get()) != nil {
                        self.eventsService.fetchEvents(labelID: self.labelId)
                    }
                }
            } else {
                conversationService.markAsUnread(conversationIDs: [conversation.conversationID],
                                                 labelID: labelId) { [weak self] result in
                    guard let self = self else { return }
                    if (try? result.get()) != nil {
                        self.eventsService.fetchEvents(labelID: self.labelId)
                    }
                }
            }
        case .trash:
            conversationService.move(conversationIDs: [conversation.conversationID],
                                     from: labelId,
                                     to: Message.Location.trash.rawValue,
                                     isSwipeAction: false) { [weak self] result in
                guard let self = self else { return }
                if (try? result.get()) != nil {
                    self.eventsService.fetchEvents(labelID: self.labelId)
                }
            }
        default:
            return
        }
    }

    func handleActionSheetAction(_ action: MessageViewActionSheetAction, completion: @escaping () -> Void) {
        let fetchEvents = { [weak self] (result: Result<Void, Error>) in
            guard let self = self else { return }
            if (try? result.get()) != nil { self.eventsService.fetchEvents(labelID: self.labelId) }
        }
        let moveAction = { [weak self] (destination: Message.Location) in
            guard let self = self else { return }
            self.conversationService.move(conversationIDs: [self.conversation.conversationID],
                                          from: self.labelId,
                                          to: destination.rawValue,
                                          isSwipeAction: false,
                                          completion: fetchEvents)
        }
        switch action {
        case .markUnread:
            conversationService.markAsUnread(conversationIDs: [conversation.conversationID],
                                             labelID: labelId,
                                             completion: fetchEvents)
        case .markRead:
            conversationService.markAsRead(conversationIDs: [conversation.conversationID],
                                           labelID: labelId,
                                           completion: fetchEvents)
        case .trash:
            moveAction(Message.Location.trash)
        case .archive:
            moveAction(Message.Location.archive)
        case .spam:
            moveAction(Message.Location.spam)
        case .delete:
            conversationService.deleteConversations(with: [conversation.conversationID],
                                                    labelID: labelId,
                                                    completion: fetchEvents)
        case .inbox, .spamMoveToInbox:
            moveAction(Message.Location.inbox)
        default:
            break
        }
        completion()
    }
}

// MARK: - Label As Action Sheet Implementation
extension ConversationViewModel: LabelAsActionSheetProtocol {
    func handleLabelAsAction(messages: [Message],
                             shouldArchive: Bool,
                             currentOptionsStatus: [MenuLabel: PMActionSheetPlainItem.MarkType]) {
        guard let message = messages.first else { return }
        for (label, status) in currentOptionsStatus {
            guard status != .dash else { continue } // Ignore the option in dash
            if selectedLabelAsLabels
                .contains(where: { $0.labelID == label.location.labelID }) {
                // Add to message which does not have this label
                if !message.contains(label: label.location.labelID) {
                    messageService.label(messages: messages,
                                         label: label.location.labelID,
                                         apply: true)
                }
            } else {
                if message.contains(label: label.location.labelID) {
                    messageService.label(messages: messages,
                                         label: label.location.labelID,
                                         apply: false)
                }
            }
        }

        selectedLabelAsLabels.removeAll()

        if shouldArchive {
            if let fLabel = message.firstValidFolder() {
                messageService.move(messages: messages,
                                    from: [fLabel],
                                    to: Message.Location.archive.rawValue)
            }
        }
    }

    func handleLabelAsAction(conversations: [Conversation],
                             shouldArchive: Bool,
                             currentOptionsStatus: [MenuLabel: PMActionSheetPlainItem.MarkType],
                             completion: (() -> Void)?) {
        let group = DispatchGroup()
        let fetchEvents = { [weak self] (result: Result<Void, Error>) in
            defer {
                group.leave()
            }
            guard let self = self else { return }
            if (try? result.get()) != nil {
                self.eventsService.fetchEvents(labelID: self.labelId)
            }
        }
        for (label, status) in currentOptionsStatus {
            guard status != .dash else { continue } // Ignore the option in dash
            if selectedLabelAsLabels
                .contains(where: { $0.labelID == label.location.labelID }) {
                group.enter()
                let conversationIDsToApply = findConversationIDsToApplyLabels(conversations: conversations,
                                                                              labelID: label.location.labelID)
                conversationService.label(conversationIDs: conversationIDsToApply,
                                          as: label.location.labelID,
                                          isSwipeAction: false,
                                          completion: fetchEvents)
            } else {
                group.enter()
                let conversationIDsToRemove = findConversationIDSToRemoveLables(conversations: conversations,
                                                                                labelID: label.location.labelID)
                conversationService.unlabel(conversationIDs: conversationIDsToRemove,
                                            as: label.location.labelID,
                                            isSwipeAction: false,
                                            completion: fetchEvents)
            }
        }

        selectedLabelAsLabels.removeAll()

        if shouldArchive {
            if let fLabel = conversation.firstValidFolder() {
                group.enter()
                conversationService.move(conversationIDs: conversations.map(\.conversationID),
                                         from: fLabel,
                                         to: Message.Location.archive.rawValue,
                                         isSwipeAction: false,
                                         completion: fetchEvents)
            }
        }
        group.notify(queue: .main) {
            completion?()
        }
    }

    private func findConversationIDsToApplyLabels(conversations: [Conversation], labelID: String) -> [String] {
        var conversationIDsToApplyLabel: [String] = []
        conversations.forEach { conversaion in
            if let context = conversaion.managedObjectContext {
                context.performAndWait {
                    let messages = Message.messagesForConversationID(conversaion.conversationID,
                                                                     inManagedObjectContext: context)
                    let needToUpdate = messages?
                        .allSatisfy({ $0.contains(label: labelID) }) == false
                    if needToUpdate {
                        conversationIDsToApplyLabel.append(conversaion.conversationID)
                    }
                }
            }
        }
        return conversationIDsToApplyLabel
    }

    private func findConversationIDSToRemoveLables(conversations: [Conversation], labelID: String) -> [String] {
        var conversationIDsToRemove: [String] = []
        conversations.forEach { conversation in
            if let context = conversation.managedObjectContext {
                context.performAndWait {
                    let messages = Message.messagesForConversationID(conversation.conversationID,
                                                                     inManagedObjectContext: context)
                    let needToUpdate = messages?
                        .allSatisfy({ !$0.contains(label: labelID) }) == false
                    if needToUpdate {
                        conversationIDsToRemove.append(conversation.conversationID)
                    }
                }
            }
        }
        return conversationIDsToRemove
    }

    private func expandSpecificMessage(dataModels: inout [ConversationViewItemType]) -> IndexPath? {
        var indexToOpen: Int?

        guard dataModels.count == recordNumOfMessages else {
            return nil
        }
        guard !dataModels
                .contains(where: { $0.messageViewModel?.state.isExpanded ?? false }) else { return nil }

        if let targetID = self.targetID,
           let index = dataModels.lastIndex(where: { $0.message?.messageID == targetID }) {
            if dataModels[index].messageViewModel?.isDraft ?? false {
                // The draft can't expand
                return nil
            }
            dataModels[index].messageViewModel?.toggleState()
            return IndexPath(row: index, section: 1)
        }

        // open the latest message if it contains all_sent label and is read.
        if let latestMessageIndex = dataModels.lastIndex(where: { $0.message?.draft == false }),
           let latestMessage = dataModels[safe: latestMessageIndex]?.message,
           latestMessage.contains(label: Message.HiddenLocation.sent.rawValue),
           latestMessage.unRead == false {
            dataModels[latestMessageIndex].messageViewModel?.toggleState()
            return IndexPath(row: latestMessageIndex, section: 1)
        }

        let isLatestMessageUnread = dataModels.isLatestMessageUnread(location: labelId)

        switch labelId {
        case Message.Location.allmail.rawValue, Message.Location.spam.rawValue:
            indexToOpen = getIndexOfMessageToExpandInSpamOrAllMail(dataModels: dataModels,
                                                                   isLatestMessageUnread: isLatestMessageUnread)
        case Message.Location.trash.rawValue:
            indexToOpen = getIndexOfMessageToExpandInTrashFolder(dataModels: dataModels,
                                                                 isLatestMessageUnread: isLatestMessageUnread)
        default:
            indexToOpen = getIndexOfMessageToExpand(dataModels: dataModels,
                                                    isLatestMessageUnread: isLatestMessageUnread)
        }

        if let index = indexToOpen {
            dataModels[index].messageViewModel?.toggleState()
            return IndexPath(row: index, section: 1)
        } else {
            return nil
        }
    }

    private func getIndexOfMessageToExpand(dataModels: [ConversationViewItemType],
                                           isLatestMessageUnread: Bool) -> Int? {
        if isLatestMessageUnread {
            // latest message of current location is unread, open the oldest of the unread messages
            // of the latest chunk of unread messages (excluding trash, draft).
            return getTheOldestIndexOfTheLatestChunckOfUnreadMessages(dataModels: dataModels,
                                                                      targetLabelID: labelId,
                                                                      shouldExcludeTrash: true)
        } else {
            // latest message of current location is read, open that message (excluding draft, trash)
            return getLatestMessageIndex(of: labelId, dataModels: dataModels)
        }
    }

    private func getIndexOfMessageToExpandInSpamOrAllMail(dataModels: [ConversationViewItemType],
                                                          isLatestMessageUnread: Bool) -> Int? {
        if isLatestMessageUnread {
            // latest message is unread, open the oldest of the unread messages
            // of the latest chunk of unread messages (excluding trash, draft).
            return getTheOldestIndexOfTheLatestChunckOfUnreadMessages(dataModels: dataModels,
                                                                      shouldExcludeTrash: true)
        } else {
            return getLatestMessageIndex(of: nil, dataModels: dataModels, excludeTrash: false)
        }
    }

    private func getIndexOfMessageToExpandInTrashFolder(dataModels: [ConversationViewItemType],
                                                        isLatestMessageUnread: Bool) -> Int? {
        if isLatestMessageUnread {
            // latest message of trashed is unread, open the oldest of the unread messages
            // of the latest chunk of unread messages (excluding draft).
            return getTheOldestIndexOfTheLatestChunckOfUnreadMessages(dataModels: dataModels)
        } else {
            // latest message of trashed is read, open that message
            return getLatestMessageIndex(of: labelId, dataModels: dataModels, excludeTrash: false)
        }
    }

    private func getLatestMessageIndex(of labelID: String?,
                                       dataModels: [ConversationViewItemType],
                                       excludeDraft: Bool = true,
                                       excludeTrash: Bool = true) -> Int? {
        let shouldCheckLabelId = labelID != nil
        if let latestMessageModelIndex = dataModels.lastIndex(where: {
            ($0.message?.contains(label: labelId) == true || !shouldCheckLabelId) &&
            ($0.message?.draft == false || !excludeDraft) &&
            ($0.message?.contains(label: Message.Location.trash.rawValue) == false || !excludeTrash)
        }) {
            return latestMessageModelIndex
        } else {
            return nil
        }
    }

    private func getTheOldestIndexOfTheLatestChunckOfUnreadMessages(dataModels: [ConversationViewItemType],
                                                                    targetLabelID: String? = nil,
                                                                    shouldExcludeTrash: Bool = false) -> Int? {
        // find the oldeset message of latest chunk of unread messages
        if let latestIndex = getLatestMessageIndex(of: targetLabelID,
                                                   dataModels: dataModels,
                                                   excludeTrash: shouldExcludeTrash) {
            var indexOfOldestUnreadMessage: Int?
            for index in (0...latestIndex).reversed() {
                if dataModels[index].message?.unRead != true || dataModels[index].message?.draft == true {
                    break
                }
                if shouldExcludeTrash && (dataModels[index].message?.contains(label: .trash) == true) {
                    break
                }
                if let labelToCheck = targetLabelID, dataModels[index].message?.contains(label: labelToCheck) == false {
                    break
                }
                indexOfOldestUnreadMessage = index
            }
            return indexOfOldestUnreadMessage
        }
        return nil
    }
}

// MARK: - Move TO Action Sheet Implementation
extension ConversationViewModel: MoveToActionSheetProtocol {
    func handleMoveToAction(messages: [Message], isFromSwipeAction: Bool) {
        guard let destination = selectedMoveToFolder else { return }
        user.messageService.move(messages: messages, to: destination.location.labelID, isSwipeAction: isFromSwipeAction)
    }

    func handleMoveToAction(conversations: [Conversation], isFromSwipeAction: Bool, completion: (() -> Void)? = nil) {
        guard let destination = selectedMoveToFolder else { return }
        conversationService.move(conversationIDs: conversations.map(\.conversationID),
                                 from: "",
                                 to: destination.location.labelID,
                                 isSwipeAction: isFromSwipeAction) { [weak self] result in
            guard let self = self else { return }
            if (try? result.get()) != nil {
                self.eventsService.fetchEvents(labelID: self.labelId)
            }
        }
    }
}

extension ConversationViewModel: ConversationViewTrashedHintDelegate {
    func clickTrashedMessageSettingButton() {
        switch self.displayRule {
        case .showTrashedOnly:
            self.displayRule = .showAll
        case .showNonTrashedOnly:
            self.displayRule = .showAll
        case .showAll:
            self.displayRule = self.isTrashFolder ? .showTrashedOnly: .showNonTrashedOnly
        }
        let row = IndexPath(row: 1, section: 0)
        self.reloadRowsIfNeeded(additional: row)
    }

    private func reloadRowsIfNeeded(additional: IndexPath? = nil) {
        guard self.messagesDataSource.isEmpty == false else {
            if let additional = additional {
                self.reloadRows?([additional])
            }
            return
        }
        let messagePaths = Array([Int](0..<self.messagesDataSource.count)).map { IndexPath(row: $0, section: 1) }

        var indexPaths: [IndexPath] = messagePaths.filter { [weak self] indexPath in
            guard let self = self,
                  indexPath.section == 1 else { return false }
            let row = indexPath.row
            guard let cell = self.tableView?.cellForRow(at: indexPath),
                  let item = self.messagesDataSource[safe: row],
                  let viewModel = item.messageViewModel else {
                      return false
                  }
            let cellClass = String(describing: cell.classForCoder)
            let defaultClass = String(describing: UITableViewCell.self)
            switch self.displayRule {
            case .showAll:
                return cell.bounds.height == 0
            case .showTrashedOnly:
                if viewModel.isTrashed && cellClass == defaultClass {
                    return true
                } else if !viewModel.isTrashed && cellClass != defaultClass {
                    return true
                }
                return false
            case .showNonTrashedOnly:
                if viewModel.isTrashed && cellClass != defaultClass {
                    return true
                } else if !viewModel.isTrashed && cellClass == defaultClass {
                    return true
                }
                return false
            }
        }
        if let additional = additional {
            indexPaths.append(additional)
        }
        if indexPaths.isEmpty { return }
        self.reloadRows?(indexPaths)
    }
}

extension ConversationViewModel: ConversationStateServiceDelegate {
    func viewModeHasChanged(viewMode: ViewMode) {
        viewModeIsChanged?(viewMode)
    }

    func conversationModeFeatureFlagHasChanged(isFeatureEnabled: Bool) {

    }
}