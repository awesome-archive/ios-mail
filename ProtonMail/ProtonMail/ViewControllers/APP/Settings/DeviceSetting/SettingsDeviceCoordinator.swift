//
//  SettingsDeviceCoordinator.swift
//  Proton Mail - Created on 12/12/18.
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

import UIKit
import ProtonCore_Common

class SettingsDeviceCoordinator {
    enum Destination: String {
        case accountSetting = "settings_account_settings"
        case autoLock       = "settings_auto_lock"
        case combineContact = "settings_combine_contact"
        case alternativeRouting = "settings_alternative_routing"
        case swipeAction = "settings_swipe_action"
        case darkMode = "settings_dark_mode"
    }

    private let usersManager: UsersManager
    private let userManager: UserManager
    private let services: ServiceFactory

    private weak var navigationController: UINavigationController?

    init(navigationController: UINavigationController?,
         user: UserManager,
         usersManager: UsersManager,
         services: ServiceFactory) {
        self.navigationController = navigationController
        self.userManager = user
        self.usersManager = usersManager
        self.services = services
    }

    func start() {
        let viewModel = SettingsDeviceViewModel(user: userManager,
                                                users: usersManager,
                                                dohSetting: DoHMail.default,
                                                biometricStatus: UIDevice.current)

        let viewController = SettingsDeviceViewController(viewModel: viewModel, coordinator: self)
        navigationController?.pushViewController(viewController, animated: false)
    }

    func go(to dest: Destination, deepLink: DeepLink? = nil) {
        switch dest {
        case .accountSetting:
            openAccount(deepLink: deepLink)
        case .autoLock:
            openAutoLock()
        case .combineContact:
            openCombineContacts()
        case .alternativeRouting:
            openAlternativeRouting()
        case .swipeAction:
            openGesture()
        case .darkMode:
            openDarkMode()
        }
    }

    func follow(deepLink: DeepLink?) {
        guard let link = deepLink, let node = link.popFirst else {
            return
        }
        guard let destination = Destination(rawValue: node.name) else {
            return
        }
        go(to: destination, deepLink: link)
    }

    private func openAccount(deepLink: DeepLink?) {
        let accountSettings = SettingsAccountCoordinator(navigationController: self.navigationController, services: self.services)
        accountSettings.start(animated: deepLink == nil)
        accountSettings.follow(deepLink: deepLink)
    }

    private func openAutoLock() {
        let lockSetting = SettingsLockCoordinator(navigationController: self.navigationController)
        lockSetting.start()
    }

    private func openCombineContacts() {
        let viewModel = ContactCombineViewModel(combineContactCache: userCachedStatus)
        let viewController = SwitchToggleViewController(viewModel: viewModel)
        navigationController?.show(viewController, sender: nil)
    }

    private func openAlternativeRouting() {
        let controller = SettingsNetworkTableViewController(nibName: "SettingsNetworkTableViewController", bundle: nil)
        controller.viewModel = SettingsNetworkViewModel(userCache: userCachedStatus, dohSetting: DoHMail.default)
        controller.coordinator = self
        self.navigationController?.pushViewController(controller, animated: true)
    }

    private func openGesture() {
        let apiServices = usersManager.users.map(\.apiService)
        guard !apiServices.isEmpty else {
            return
        }
        let coordinator = SettingsGesturesCoordinator(navigationController: self.navigationController,
                                                      userInfo: userManager.userInfo,
                                                      apiServices: apiServices)
        coordinator.start()
    }

    private func openDarkMode() {
        let viewModel = DarkModeSettingViewModel(darkModeCache: userCachedStatus)
        let viewController = SettingsSingleCheckMarkViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(viewController, animated: true)
    }

    func openToolbarCustomizationView() {
        let viewModel = ToolbarSettingViewModel(
            viewMode: userManager.getCurrentViewMode(),
            infoBubbleViewStatusProvider: userCachedStatus,
            toolbarActionProvider: userManager,
            saveToolbarActionUseCase: SaveToolbarActionSettings(
                dependencies: .init(user: userManager)
            )
        )
        let viewController = ToolbarSettingViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

extension DeepLink.Node {
    static let accountSetting = DeepLink.Node.init(name: "settings_account_settings")
}
