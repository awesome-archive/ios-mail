//
//  SettingsTableViewController.swift
//  ProtonMail - Created on 3/17/15.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.


import UIKit
import MBProgressHUD
import Keymaker

class SettingsTableViewController: ProtonMailTableViewController, ViewModelProtocol, CoordinatedNew {
    internal var viewModel : SettingsViewModel!
    internal var coordinator : SettingsCoordinator?
    
    func set(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    func set(coordinator: SettingsCoordinator) {
        self.coordinator = coordinator
    }
    
    func getCoordinator() -> CoordinatorNew? {
        return self.coordinator
    }
    
    ///
    var setting_headers : [SettingSections]              = [.general,
                                                            .protection,
                                                            .labels,
                                                            .multiDomain,
                                                            .swipeAction,
                                                            .language,
                                                            .storage,
                                                            .version] //.Debug,
    
    var setting_general_items : [SGItems]                = [.notifyEmail, .loginPWD,
                                                            .mbp, .autoLoadImage, .linkOpeningMode, .browser, .metadataStripping, .cleanCache, .notificationsSnooze]
    var setting_debug_items : [SDebugItem]               = [.queue, .errorLogs]
    
    var setting_swipe_action_items : [SSwipeActionItems] = [.left, .right]
    var setting_swipe_actions : [MessageSwipeAction]     = [.trash, .spam,
                                                            .star, .archive, .unread]
    
    var setting_protection_items : [SProtectionItems]    = [] // [.touchID, .pinCode] // [.TouchID, .PinCode, .UpdatePin, .AutoLogout, .EnterTime]
    var setting_addresses_items : [SAddressItems]        = [.addresses,
                                                            .displayName,
                                                            .signature,
                                                            .defaultMobilSign]
    
    var setting_labels_items : [SLabelsItems]            = [.labelFolderManager]
    
    var setting_languages : [ELanguage]                  = ELanguage.allItems()
    
    var protection_auto_logout : [Int]                   = [-1, 0, 1, 2, 5,
                                                            10, 15, 30, 60]
    
    var multi_domains: [Address]!
    var userInfo: UserInfo? = sharedUserDataService.userInfo {
        didSet {
            if oldValue != userInfo {
                self.tableView.reloadData()
            }
        }
    }
    
    /// cells
    let SettingSingalLineCell         = "settings_general"
    let SettingSingalSingleLineCell   = "settings_general_single_line"
    let SettingTwoLinesCell           = "settings_twolines"
    let SettingDomainsCell            = "setting_domains"
    let SettingStorageCell            = "setting_storage_cell"
    let HeaderCell                    = "header_cell"
    let SingleTextCell                = "single_text_cell"
    let SwitchCell                    = "switch_table_view_cell"
    
    //
    let CellHeight : CGFloat = 30.0
    var cleaning : Bool      = false
    
    //
    @IBOutlet var settingTableView: UITableView!
    
    //
    override func viewDidLoad() {
        super.viewDidLoad()
        self.restorationClass = SettingsTableViewController.self
        self.updateTitle()
        self.tableView.register(UITableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: HeaderCell)
    }
    
    private func updateTitle() {
        self.title = LocalString._menu_settings_title
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateProtectionItems()
        
        if sharedUserDataService.passwordMode == 1 {
            setting_general_items = [.notifyEmail, .singlePWD, .autoLoadImage, .linkOpeningMode, .browser, .metadataStripping, .cleanCache]
        } else {
            setting_general_items = [.notifyEmail, .loginPWD, .mbp, .autoLoadImage, .linkOpeningMode, .browser, .metadataStripping, .cleanCache]
        }
        if #available(iOS 10.0, *), Constants.Feature.snoozeOn {
            setting_general_items.append(.notificationsSnooze)
        }
   
        multi_domains = sharedUserDataService.addresses
        self.userInfo = sharedUserDataService.userInfo ?? self.userInfo
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    internal func updateProtectionItems() {
        setting_protection_items = []
        switch UIDevice.current.biometricType {
        case .none:
            break
        case .touchID:
            setting_protection_items.append(.touchID)
            break
        case .faceID:
            setting_protection_items.append(.faceID)
            break
        }
        setting_protection_items.append(.pinCode)
        if userCachedStatus.isPinCodeEnabled || userCachedStatus.isTouchIDEnabled {
            setting_protection_items.append(.enterTime)
        }
    }
    
    internal func updateTableProtectionSection() {
        self.updateProtectionItems()
        if let index = setting_headers.firstIndex(of: SettingSections.protection) {
            self.settingTableView.reloadSections(IndexSet(integer: index), with: .fade)
        }
    }
    
    ///MARK: -- table view delegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return setting_headers.count
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if setting_headers.count > section {
            switch(setting_headers[section]) {
            case .debug:
                return setting_debug_items.count
            case .general:
                return setting_general_items.count
            case .multiDomain:
                return setting_addresses_items.count
            case .swipeAction:
                return setting_swipe_action_items.count
            case .storage:
                return 1
            case .version:
                return 0
            case .protection:
                return setting_protection_items.count
            case .language:
                return 1
            case .labels:
                return setting_labels_items.count
            }
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cellout : UITableViewCell?
        if setting_headers.count > indexPath.section {
            let setting_item = setting_headers[indexPath.section]
            switch setting_item {
            case .general:
                if setting_general_items.count > indexPath.row {
                    let itme: SGItems = setting_general_items[indexPath.row]
                    switch itme {
                    case .notifyEmail:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingTwoLinesCell, for: indexPath) as! SettingsCell
                        cell.LeftText.text = itme.description
                        cell.RightText.text = userInfo?.notificationEmail
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    case .loginPWD, .mbp, .singlePWD:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingTwoLinesCell, for: indexPath) as! SettingsCell
                        cell.LeftText.text = itme.description
                        cell.RightText.text = LocalString._settings_secret_x_string
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    case .cleanCache:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalSingleLineCell, for: indexPath) as! GeneralSettingSinglelineCell
                        cell.configCell(itme.description)
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                        cellout = cell
                    case .notificationsSnooze:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalSingleLineCell, for: indexPath) as! GeneralSettingSinglelineCell
                        cell.configCell(itme.description)
                        cell.accessoryType = .disclosureIndicator
                        cellout = cell
                    case .autoLoadImage:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell, for: indexPath) as! SwitchTableViewCell
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                        cell.selectionStyle = UITableViewCell.SelectionStyle.none
                        if let userInfo = userInfo {
                            cell.configCell(itme.description, bottomLine: "", status: userInfo.autoShowRemote, complete: { (cell, newStatus,  feedback: @escaping ActionStatus) -> Void in
                                if let indexp = tableView.indexPath(for: cell!), indexPath == indexp {
                                    let view = UIApplication.shared.keyWindow ?? UIView()
                                    MBProgressHUD.showAdded(to: view, animated: true)
                                    sharedUserDataService.updateAutoLoadImage(remote: newStatus, completion: { (_, _, error) in
                                        MBProgressHUD.hide(for: view, animated: true)
                                        if let error = error {
                                            feedback(false)
                                            let alertController = error.alertController()
                                            alertController.addOKAction()
                                            self.present(alertController, animated: true, completion: nil)
                                        } else {
                                            feedback(true)
                                        }
                                    })
                                } else {
                                    feedback(false)
                                }
                            })
                        }
                        cellout = cell
                    case .browser:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingDomainsCell, for: indexPath) as! DomainsTableViewCell
                        cell.domainText.text = itme.description
                        let browser = userCachedStatus.browser
                        cell.defaultMark.text = browser.isInstalled ? browser.title : LinkOpener.safari.title
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                        
                    case .linkOpeningMode:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell, for: indexPath) as! SwitchTableViewCell
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                        cell.selectionStyle = UITableViewCell.SelectionStyle.none
                        if let userInfo = userInfo {
                            cell.configCell(itme.description, bottomLine: "", status: userInfo.linkConfirmation == .confirmationAlert) { cell, newStatus, feedback in
                                let view = UIApplication.shared.keyWindow ?? UIView()
                                MBProgressHUD.showAdded(to: view, animated: true)
                                sharedUserDataService.updateLinkConfirmation(newStatus ? .confirmationAlert : .openAtWill) { userInfo, _, error in
                                    MBProgressHUD.hide(for: view, animated: true)
                                    if let error = error {
                                        feedback(false)
                                        let alertController = error.alertController()
                                        alertController.addOKAction()
                                        self.present(alertController, animated: true, completion: nil)
                                    } else {
                                        feedback(true)
                                    }
                                }
                            }
                        }
                        cellout = cell
                    case .metadataStripping:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell, for: indexPath) as! SwitchTableViewCell
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                        cell.selectionStyle = UITableViewCell.SelectionStyle.none
                        cell.configCell(itme.description, bottomLine: "", status: userCachedStatus.metadataStripping == .stripMetadata) { cell, newStatus, feedback in
                            userCachedStatus.metadataStripping = newStatus ? .stripMetadata : .sendAsIs
                        }
                        cellout = cell
                    }
                }
            case .protection:
                if setting_protection_items.count > indexPath.row {
                    let item : SProtectionItems = setting_protection_items[indexPath.row]
                    switch item {
                    case .touchID, .faceID:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell, for: indexPath) as! SwitchTableViewCell
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                        cell.selectionStyle = UITableViewCell.SelectionStyle.none
                        cell.configCell(item.description, bottomLine: "", status: userCachedStatus.isTouchIDEnabled, complete: { (cell, newStatus, feedback) -> Void in
                            if let indexp = tableView.indexPath(for: cell!) {
                                if indexPath == indexp {
                                    if !userCachedStatus.isTouchIDEnabled {
                                        // Enable Bio
                                        keymaker.activate(BioProtection()) { _ in
                                            self.updateTableProtectionSection()
                                        }
                                    } else {
                                        // Disable Bio
                                        keymaker.deactivate(BioProtection())
                                        self.updateTableProtectionSection()
                                    }
                                } else {
                                    feedback(false)
                                }
                            } else {
                                feedback(false)
                            }
                        })
                        cellout = cell
                    case .pinCode:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell, for: indexPath) as! SwitchTableViewCell
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                        cell.selectionStyle = UITableViewCell.SelectionStyle.none
                        cell.configCell(item.description, bottomLine: "", status: userCachedStatus.isPinCodeEnabled, complete: { (cell, newStatus, feedback) -> Void in
                            if let indexp = tableView.indexPath(for: cell!) {
                                if indexPath == indexp {
                                    if !userCachedStatus.isPinCodeEnabled {
//                                        self.performSegue(withIdentifier: self.kSetupPinCodeSegue, sender: self)
                                        self.coordinator?.go(to: .pinCode)
                                    } else {
                                        keymaker.deactivate(PinProtection(pin: "doesnotmatter"))
                                        feedback(true)
                                        self.updateTableProtectionSection()
                                    }
                                } else {
                                    feedback(false)
                                }
                            } else {
                                feedback(false)
                            }
                        })
                        cellout = cell
                    case .updatePin:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalLineCell, for: indexPath) as! GeneralSettingViewCell
                        cell.configCell(item.description, right: "")
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    case .autoLogout:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell, for: indexPath) as! SwitchTableViewCell
                        cell.accessoryType = UITableViewCell.AccessoryType.none
                        cell.selectionStyle = UITableViewCell.SelectionStyle.none
                        cell.configCell(item.description, bottomLine: "", status: userCachedStatus.isPinCodeEnabled, complete: { (cell, newStatus, feedback) -> Void in
                            if let indexp = tableView.indexPath(for: cell!) {
                                if indexPath == indexp {
                                    
                                } else {
                                    feedback(false)
                                }
                            } else {
                                feedback(false)
                            }
                        })
                        cellout = cell
                    case .enterTime:
                        let timeIndex = userCachedStatus.lockTime.rawValue
                        var text = String(format: LocalString._settings_auto_lock_minutes, timeIndex)
                        if timeIndex == -1 {
                            text = LocalString._general_none
                        } else if timeIndex == 0 {
                            text = LocalString._settings_every_time_enter_app
                        } else if timeIndex == 1{
                            text = String(format: LocalString._settings_auto_lock_minute, timeIndex)
                        }
                        
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingTwoLinesCell, for: indexPath) as! SettingsCell
                        cell.LeftText.text = item.description
                        cell.RightText.text = text
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    }
                }
            case .labels:
                if setting_labels_items.count > indexPath.row {
                    let label_item = setting_labels_items[indexPath.row]
                    let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalLineCell, for: indexPath) as! GeneralSettingViewCell
                    cell.configCell(label_item.description, right: "")
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cellout = cell
                }
            case .multiDomain:
                if setting_addresses_items.count > indexPath.row {
                    let address_item: SAddressItems = setting_addresses_items[indexPath.row]
                    switch address_item {
                    case .addresses:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingDomainsCell, for: indexPath) as! DomainsTableViewCell
                        if let addr = multi_domains.defaultAddress() {
                            cell.domainText.text = addr.email
                        } else {
                            cell.domainText.text = LocalString._general_unknown_title
                        }
                        cell.defaultMark.text = LocalString._general_default
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    case .displayName:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingTwoLinesCell, for: indexPath) as! SettingsCell
                        cell.LeftText.text = address_item.description
                        if let addr = userInfo?.userAddresses.defaultAddress() {
                            cell.RightText.text = addr.display_name
                        } else {
                            cell.RightText.text = userInfo?.displayName.decodeHtml()
                        }
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    case .signature:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalLineCell, for: indexPath) as! GeneralSettingViewCell
                        cell.configCell(address_item.description, right: "")
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    case .defaultMobilSign:
                        let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalLineCell, for: indexPath) as! GeneralSettingViewCell
                        cell.configCell(address_item.description, right: "")
                        cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                        cellout = cell
                    }
                }
            case .swipeAction:
                if indexPath.row < setting_swipe_action_items.count {
                    let actionItem = setting_swipe_action_items[indexPath.row]
                    let cell = tableView.dequeueReusableCell(withIdentifier: SettingDomainsCell, for: indexPath) as! DomainsTableViewCell
                    let action = actionItem == .left ? userInfo?.swipeLeftAction : userInfo?.swipeRightAction
                    cell.domainText.text = actionItem.description
                    cell.defaultMark.text = action?.description
                    cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                    cellout = cell
                }
            case .storage:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingStorageCell, for: indexPath) as! StorageViewCell
                let usedSpace = userInfo?.usedSpace ?? 0
                let maxSpace = userInfo?.maxSpace ?? 0
                cell.setValue(usedSpace, maxSpace: maxSpace)
                cell.selectionStyle = UITableViewCell.SelectionStyle.none
                cellout = cell
            case .debug:
                if setting_debug_items.count > indexPath.row {
                    let itme: SDebugItem = setting_debug_items[indexPath.row]
                    let cell = tableView.dequeueReusableCell(withIdentifier: SettingTwoLinesCell, for: indexPath) as! GeneralSettingViewCell
                    cell.LeftText.text = itme.description
                    cell.RightText.text  = ""
                    cellout = cell
                }
            case .language:
                let language: ELanguage =  LanguageManager.currentLanguageEnum()
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalLineCell, for: indexPath) as! GeneralSettingViewCell
                if #available(iOS 13.0, *) {
                    cell.configCell(language.nativeDescription, right: LocalString._manage_language_in_device_settings)
                } else {
                    cell.configCell(language.nativeDescription, right: "")
                }
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                cellout = cell
                
            case .version:
                break
            }
        }
        
        if let cellout = cellout {
            return cellout
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingSingalLineCell, for: indexPath) as! GeneralSettingViewCell
            cell.configCell("", right: "")
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            return cell
        }
    }
    
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: HeaderCell)
        header?.textLabel?.font = Fonts.h6.regular
        header?.textLabel?.textColor = UIColor.ProtonMail.Gray_8E8E8E
        
        if(setting_headers[section] == SettingSections.version){
            var appVersion = "Unkonw Version"
            var libVersion = "| LibVersion: 1.0.0"
            
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                appVersion = "AppVersion: \(version)"
            }
            if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                appVersion = appVersion + " (\(build))"
            }
            
            let lib_v = PMNLibVersion.getLibVersion()
            libVersion = "| LibVersion: \(lib_v)"
            header?.textLabel?.text = appVersion + " " + libVersion
        }
        else
        {
            header?.textLabel?.text = setting_headers[section].description
        }
        return header
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CellHeight
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if setting_headers.count > indexPath.section {
            let setting_item = setting_headers[indexPath.section]
            switch setting_item {
            case .general:
                if setting_general_items.count > indexPath.row {
                    let general_itme: SGItems = setting_general_items[indexPath.row]
                    switch general_itme {
                    case .notifyEmail:
                        self.coordinator?.go(to: .notification)
                    case .loginPWD:
                        // if shard
                        if sharedUserDataService.passwordMode == 1 {
                            let alert = LocalString._general_use_web_reset_pwd.alertController()
                            alert.addOKAction()
                            present(alert, animated: true, completion: nil)
                        } else {
                            self.coordinator?.go(to: .loginPwd)
                        }
                    case .mbp:
                        self.coordinator?.go(to: .mailboxPwd)
                    case .singlePWD:
                        self.coordinator?.go(to: .singlePwd)
                    case .cleanCache:
                        if !cleaning {
                            cleaning = true
                            let nview = self.navigationController?.view ?? UIView()
                            let hud : MBProgressHUD = MBProgressHUD.showAdded(to: nview, animated: true)
                            hud.label.text = LocalString._settings_resetting_cache
                            hud.removeFromSuperViewOnHide = true
                            sharedMessageDataService.cleanLocalMessageCache() { task, res, error in
                                hud.mode = MBProgressHUDMode.text
                                hud.label.text = LocalString._general_done_button
                                hud.hide(animated: true, afterDelay: 1)
                                self.cleaning = false
                            }
                        }
                    case .notificationsSnooze:
                        self.coordinator?.go(to: .snooze)
                    case .browser:
                        let browsers = LinkOpener.allCases.filter {
                            $0.isInstalled
                        }.compactMap { app in
                            return UIAlertAction(title: app.title, style: .default) { [weak self] _ in
                                userCachedStatus.browser = app
                                self?.tableView?.reloadRows(at: [indexPath], with: .fade)
                            }
                        }
                        let alert = UIAlertController(title: nil, message: LocalString._settings_browser_disclaimer, preferredStyle: .actionSheet)
                        if let cell = tableView.cellForRow(at: indexPath) as? DomainsTableViewCell {
                            alert.popoverPresentationController?.sourceView = cell.contentView
                            alert.popoverPresentationController?.sourceRect = cell.defaultMark.frame
                        }
                        browsers.forEach(alert.addAction)
                        alert.addAction(.init(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        
                    case .autoLoadImage, .linkOpeningMode, .metadataStripping:
                        break
                    }
                }
            case .debug:
                if setting_debug_items.count > indexPath.row {
                    let debug_item: SDebugItem = setting_debug_items[indexPath.row]
                    switch debug_item {
                    case .queue:
//                        self.performSegue(withIdentifier: DebugQueueSegue, sender: self)
                        self.coordinator?.go(to: .debugQueue)
                        break
                    case .errorLogs:
                        break
                    }
                }
            case .protection:
                if setting_protection_items.count > indexPath.row {
                    let protection_item: SProtectionItems = setting_protection_items[indexPath.row]
                    switch protection_item {
                    case .touchID, .faceID:
                        break
                    case .pinCode:
                        break
                    case .updatePin:
                        break
                    case .autoLogout:
                        break
                    case .enterTime:
                        let alertController = UIAlertController(title: LocalString._settings_auto_lock_time,
                                                                message: nil,
                                                                preferredStyle: .actionSheet)
                        alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
                        for timeIndex in protection_auto_logout {
                            var text = String(format: LocalString._settings_auto_lock_minutes, timeIndex)
                            if timeIndex == -1 {
                                text = LocalString._general_none
                            } else if timeIndex == 0 {
                                text = LocalString._settings_every_time_enter_app
                            } else if timeIndex == 1{
                                text = String(format: LocalString._settings_auto_lock_minute, timeIndex)
                            }
                            alertController.addAction(UIAlertAction(title: text, style: .default, handler: { (action) -> Void in
                                userCachedStatus.lockTime = AutolockTimeout(rawValue: timeIndex)
                                DispatchQueue.main.async {
                                    tableView.reloadRows(at: [indexPath], with: .fade)
                                }
                            }))
                        }
                        let cell = tableView.cellForRow(at: indexPath)
                        alertController.popoverPresentationController?.sourceView = cell ?? self.view
                        alertController.popoverPresentationController?.sourceRect = (cell == nil ? self.view.frame : cell!.bounds)
                        present(alertController, animated: true, completion: nil)
                    }
                }
            case .multiDomain:
                if setting_addresses_items.count > indexPath.row {
                    let address_item: SAddressItems = setting_addresses_items[indexPath.row]
                    switch address_item {
                    case .addresses:
                        var needsShow : Bool = false
                        let alertController = UIAlertController(title: LocalString._settings_change_default_address_to, message: nil, preferredStyle: .actionSheet)
                        alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
                        let defaultAddress : Address? = multi_domains.defaultAddress()
                        for addr in multi_domains {
                            if addr.status == 1 && addr.receive == 1 {
                                if defaultAddress != addr {
                                    needsShow = true
                                    alertController.addAction(UIAlertAction(title: addr.email, style: .default, handler: { (action) -> Void in
                                        if addr.send == 0 {
                                            if addr.email.lowercased().range(of: "@pm.me") != nil {
                                                let msg = String(format: LocalString._settings_change_paid_address_warning, addr.email)
                                                let alertController = msg.alertController()
                                                alertController.addOKAction()
                                                self.present(alertController, animated: true, completion: nil)
                                            }
                                            return
                                        }
                                        
                                        var newAddrs = [Address]()
                                        var newOrder = [String]()
                                        newAddrs.append(addr)
                                        newOrder.append(addr.address_id)
                                        var order = 1
                                        addr.order = order
                                        order += 1
                                        for oldAddr in self.multi_domains {
                                            if oldAddr != addr {
                                                newAddrs.append(oldAddr)
                                                newOrder.append(oldAddr.address_id)
                                                oldAddr.order = order
                                                order += 1
                                            }
                                        }
                                        let view = UIApplication.shared.keyWindow ?? UIView()
                                        MBProgressHUD.showAdded(to: view, animated: true)
                                        sharedUserDataService.updateUserDomiansOrder(newAddrs,  newOrder:newOrder) { _, _, error in
                                            MBProgressHUD.hide(for: view, animated: true)
                                            if error == nil {
                                                self.multi_domains = newAddrs
                                            }
                                            self.userInfo = sharedUserDataService.userInfo ?? self.userInfo
                                        }
                                    }))
                                }
                            }
                        }
                        if needsShow {
                            let cell = tableView.cellForRow(at: indexPath)
                            alertController.popoverPresentationController?.sourceView = cell ?? self.view
                            alertController.popoverPresentationController?.sourceRect = (cell == nil ? self.view.frame : cell!.bounds)
                            present(alertController, animated: true, completion: nil)
                        }
                    case .displayName:
                        self.coordinator?.go(to: .displayName)
//                        self.performSegue(withIdentifier: DisplayNameSegue, sender: self)
                    case .signature:
//                        self.performSegue(withIdentifier: SignatureSegue, sender: self)
                        self.coordinator?.go(to: .signature)
                    case .defaultMobilSign:
//                        self.performSegue(withIdentifier: MobileSignatureSegue, sender: self)
                        self.coordinator?.go(to: .mobileSignature)
                    }
                }
            case .swipeAction:
                if setting_swipe_action_items.count > indexPath.row {
                    let action_item = setting_swipe_action_items[indexPath.row]
                    let alertController = UIAlertController(title: action_item.actionDescription, message: nil, preferredStyle: .actionSheet)
                    alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
                    
                    let currentAction = action_item == .left ? userInfo?.swipeLeftAction : userInfo?.swipeRightAction
                    for swipeAction in setting_swipe_actions {
                        if swipeAction != currentAction {
                            alertController.addAction(UIAlertAction(title: swipeAction.description, style: .default, handler: { (action) -> Void in
                                let _ = self.navigationController?.popViewController(animated: true)
                                let view = UIApplication.shared.keyWindow ?? UIView()
                                MBProgressHUD.showAdded(to: view, animated: true)
                                sharedUserDataService.updateUserSwipeAction(action_item == .left, action: swipeAction, completion: { (task, response, error) -> Void in
                                    MBProgressHUD.hide(for: view, animated: true)
                                    self.userInfo = sharedUserDataService.userInfo ?? self.userInfo
                                })
                            }))
                        }
                    }
                    let cell = tableView.cellForRow(at: indexPath)
                    alertController.popoverPresentationController?.sourceView = cell ?? self.view
                    alertController.popoverPresentationController?.sourceRect = (cell == nil ? self.view.frame : cell!.bounds)
                    present(alertController, animated: true, completion: nil)
                }
            case .labels:
//                self.performSegue(withIdentifier: kManagerLabelsSegue, sender: self)
                self.coordinator?.go(to: .lableManager)
            case .language:
                if #available(iOS 13.0, *) {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                } else {
                    let current_language = LanguageManager.currentLanguageEnum()
                    let title = LocalString._settings_current_language_is + current_language.nativeDescription
                    let alertController = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
                    alertController.addAction(UIAlertAction(title: LocalString._general_cancel_button, style: .cancel, handler: nil))
                    for l in setting_languages {
                        if l != current_language {
                            alertController.addAction(UIAlertAction(title: l.nativeDescription, style: .default, handler: { (action) -> Void in
                                let _ = self.navigationController?.popViewController(animated: true)
                                LanguageManager.saveLanguage(byCode: l.code)
                                LocalizedString.reset()
                                
                                self.updateTitle()
                                self.userInfo = sharedUserDataService.userInfo ?? self.userInfo
                            }))
                        }
                    }
                    let cell = tableView.cellForRow(at: indexPath)
                    alertController.popoverPresentationController?.sourceView = cell ?? self.view
                    alertController.popoverPresentationController?.sourceRect = (cell == nil ? self.view.frame : cell!.bounds)
                    present(alertController, animated: true, completion: nil)
                }
            default:
                break
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return UITableViewCell.EditingStyle.none
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section != proposedDestinationIndexPath.section {
            return sourceIndexPath
        }
        else {
            return proposedDestinationIndexPath
        }
    }
    
    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
//        if setting_headers[fromIndexPath.section] == SettingSections.multiDomain {
//            let val = self.multi_domains.remove(at: fromIndexPath.row)
//            self.multi_domains.insert(val, at: toIndexPath.row)
//            //let indexSet = NSIndexSet(index:fromIndexPath.section)
//            tableView.reloadData()
//        }
    }
    
    
    
//    // Override to support rearranging the table view.
//    @objc func tableView(_ tableView: UITableView, moveRowAtIndexPath fromIndexPath: IndexPath, toIndexPath: IndexPath) {

//    }
    
}

@available(iOS, deprecated: 13.0, message: "Multiwindow environment restores state via Deeplinkable conformance")
extension SettingsTableViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard let data = coder.decodeObject(forKey: "viewModel") as? Data,
            let viewModel = (try? JSONDecoder().decode(SettingsViewModelImpl.self, from: data)) else
        {
            return nil
        }

        let next = UIStoryboard(name: "Settings", bundle: .main).make(SettingsTableViewController.self)
        next.set(viewModel: viewModel)
        next.set(coordinator: .init(vc: next, vm: viewModel, services: sharedServices))

        return next
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        if let viewModel = self.viewModel as? SettingsViewModelImpl,
            let data = try? JSONEncoder().encode(viewModel)
        {
            coder.encode(data, forKey: "viewModel")
        }
        super.encodeRestorableState(with: coder)
    }
    
    override func applicationFinishedRestoringState() {
        super.applicationFinishedRestoringState()
        UIViewController.setup(self, self.menuButton, self.shouldShowSideMenu())
    }
}

extension SettingsTableViewController: Deeplinkable {
    var deeplinkNode: DeepLink.Node {
        return DeepLink.Node(name: String(describing: SettingsTableViewController.self), value: nil)
    }
}
