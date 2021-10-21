//
//  ShareExtensionEntry.swift
//  Share - Created on 6/28/17.
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


import Foundation
import UIKit
import AFNetworking
import PMCommon

@objc(ShareExtensionEntry)
class ShareExtensionEntry : UINavigationController {
    var reachabilityManager: AFNetworkReachabilityManager = {
        let manager = AFNetworkReachabilityManager.shared()
        manager.startMonitoring()
        return manager
    }()
    var appCoordinator : ShareAppCoordinator?

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        self.setup()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.setup()
    }
    
    private func setup() {
        #if DEBUG
        PMAPIService.noTrustKit = true
        #endif
        TrustKitWrapper.start(delegate: self)
        appCoordinator = ShareAppCoordinator(navigation: self)
        if #available(iOSApplicationExtension 15.0, *) {
            setupNavigationBarAppearance()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.appCoordinator?.start()
        //TODO:: fix me
        //APIService.shared.delegate = self
    }
}

//TODO:: fix me
//extension ShareExtensionEntry: APIServiceDelegate {
//    func onError(error: NSError) {
//        // alert
//        error.alertErrorToast()
//    }
//
//    func isReachable() -> Bool {
//        return self.reachabilityManager.isReachable
//    }
//}

extension ShareExtensionEntry: TrustKitUIDelegate {
    func onTrustKitValidationError(_ alert: UIAlertController) {
        self.appCoordinator?.navigationController?.present(alert, animated: true, completion: nil)
    }
}

extension ShareExtensionEntry {
    @available(iOS 15.0, *)
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.ProtonMail.Nav_Bar_Background
        appearance.shadowColor = .clear
        let navigationBarTitleFont = Fonts.h2.light
        appearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: navigationBarTitleFont
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
    }
}
