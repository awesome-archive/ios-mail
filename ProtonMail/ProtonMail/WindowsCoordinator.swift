//
//  WindowsCoordinator.swift
//  ProtonMail - Created on 12/11/2018.
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
import Keymaker

import SWRevealViewController // for state restoration


// this view controller is placed into AppWindow only until it is correctly loaded from storyboard or correctly restored with use of MainKey
fileprivate class PlaceholderVC: UIViewController { }

class WindowsCoordinator: CoordinatorNew {
    private var deeplink: DeepLink?
    private lazy var snapshot = Snapshot()
    private var upgradeView: ForceUpgradeView?
    private var appWindow: UIWindow! = UIWindow(root: PlaceholderVC(), scene: nil)
    
    private var lockWindow: UIWindow?
    
    var currentWindow: UIWindow! {
        didSet {
            self.currentWindow.makeKeyAndVisible()
        }
    }
    
    enum Destination {
        case lockWindow, appWindow, signInWindow
    }
    
    internal var scene: AnyObject? {
        didSet {
            // UIWindowScene class is available on iOS 13 and newer, older platforms should not use this property
            if #available(iOS 13.0, *) {
                assert(scene is UIWindowScene, "Scene should be of type UIWindowScene")
            } else {
                assert(false, "Scenes are unavailable on iOS 12 and older")
            }
        }
    }
    
    init() {
        defer {
            NotificationCenter.default.addObserver(self, selector: #selector(performForceUpgrade), name: .forceUpgrade, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(lock), name: Keymaker.requestMainKey, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(unlock), name: .didUnlock, object: nil)
            
            if #available(iOS 13.0, *) {
                // this is done by UISceneDelegate
            } else {
                NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            }
        }
    }
    
    /// restore some cache after login/authorized
    func loginmigrate() {
        ///
        //let cacheService : AppCacheService = serviceHolder.get()
        //cacheService.restoreCacheAfterAuthorized()
    }
    func prepare() {
        self.currentWindow = self.appWindow
    }
    
    func start() {
        let placeholder = UIWindow(root: UIViewController(), scene: self.scene)
        self.snapshot.show(at: placeholder)
        self.currentWindow = placeholder
        
        //we should not trigger the touch id here. because it also doing in the sign vc. so when need lock. we just go to lock screen first
        // clean this up later.
        let flow = UnlockManager.shared.getUnlockFlow()
        if flow == .requireTouchID || flow == .requirePin {
            self.lock()
        } else {
            DispatchQueue.main.async {
                // initiate unlock process which will send .didUnlock or .requestMainKey eventually
                UnlockManager.shared.initiateUnlock(flow: flow,
                                                    requestPin: self.lock,
                                                    requestMailboxPassword: self.lock)
            }
        }
    }
    
    @objc func willEnterForeground() {
        self.snapshot.remove()
    }
    
    @objc func didEnterBackground() {
        self.snapshot.show(at: self.currentWindow)
    }
    
    @objc func lock() {
        guard SignInManager.shared.isSignedIn() else {
            self.go(dest: .signInWindow)
            return
        }
        self.go(dest: .lockWindow)
    }
    
    @objc func unlock() {
        self.lockWindow = nil
        
        guard SignInManager.shared.isSignedIn() else {
            self.go(dest: .signInWindow)
            return
        }
        
        if sharedUserDataService.isNewUser {
            sharedUserDataService.isNewUser = false
            self.appWindow = nil
        }
        self.go(dest: .appWindow)
    }
    
    
    func go(dest: Destination) {
        DispatchQueue.main.async { // cuz
            switch dest {
            case .signInWindow:
                self.appWindow = nil
                self.navigate(from: self.currentWindow, to: UIWindow(storyboard: .signIn, scene: self.scene))
            case .lockWindow:
                if self.lockWindow == nil {
                    let lock = UIWindow(storyboard: .signIn, scene: self.scene)
                    lock.windowLevel = .statusBar
                    self.navigate(from: self.currentWindow, to: lock)
                    self.lockWindow = lock
                }
            case .appWindow:
                if self.appWindow == nil || self.appWindow.rootViewController is PlaceholderVC {
                    self.appWindow = UIWindow(storyboard: .inbox, scene: self.scene)
                }
                if #available(iOS 13.0, *), self.appWindow.windowScene == nil {
                    self.appWindow.windowScene = self.scene as? UIWindowScene
                }
                if self.navigate(from: self.currentWindow, to: self.appWindow),
                    let deeplink = self.deeplink
                {
                    self.appWindow.enumerateViewControllerHierarchy { controller, stop in
                        if let menu = controller as? MenuViewController,
                            let coordinator = menu.getCoordinator() as? MenuCoordinatorNew
                        {
                            coordinator.follow(deeplink)
                            stop = true
                        }
                    }
                }
            }
        }
    }
    
    @discardableResult func navigate(from source: UIWindow?, to destination: UIWindow) -> Bool {
        guard source != destination, source?.rootViewController?.restorationIdentifier != destination.rootViewController?.restorationIdentifier else {
            return false
        }
        
        let effectView = UIVisualEffectView(frame: UIScreen.main.bounds)
        source?.addSubview(effectView)
        destination.alpha = 0.0
        
        UIView.animate(withDuration: 0.5, animations: {
            effectView.effect = UIBlurEffect(style: .dark)
            destination.alpha = 1.0
        }, completion: { _ in
            let _ = source
            let _ = destination
            effectView.removeFromSuperview()
        })
        
        // notify source's views they are disappearing
        source?.topmostViewController()?.viewWillDisappear(false)
        
        self.currentWindow = destination
        
        // notify destination views they are about to show up
        if let topDestination = destination.topmostViewController(), topDestination.isViewLoaded {
            topDestination.viewDidAppear(false)
        }
        
        return true
    }
    
    // Preserving and Restoring State
    
    func currentDeepLink() -> DeepLink? {
        let deeplink = DeepLink("Root")
        self.appWindow?.enumerateViewControllerHierarchy { controller, _ in
            guard let deeplinkable = controller as? Deeplinkable else { return }
            deeplink.append(deeplinkable.deeplinkNode)
        }
        guard let _ = deeplink.popFirst, let _ = deeplink.head else {
            return nil
        }
        return deeplink
    }
    
    internal func saveForRestoration(_ coder: NSCoder) {
        switch UIDevice.current.stateRestorationPolicy {
        case .deeplink:
            if let deeplink = self.currentDeepLink(),
                let data = try? JSONEncoder().encode(deeplink)
            {
                coder.encode(data, forKey: "deeplink")
            }
            
        case .coders:
            guard let root = self.appWindow?.rootViewController else {
                return
            }
            coder.encodeRootObject(root)
        }
    }
    
    internal func restoreState(_ coder: NSCoder) {
        switch UIDevice.current.stateRestorationPolicy {
        case .deeplink:
            if let data = coder.decodeObject(forKey: "deeplink") as? Data,
                let deeplink = try? JSONDecoder().decode(DeepLink.self, from: data)
            {
                self.followDeeplink(deeplink)
            }
            
        case .coders:
            // SWRevealViewController is restorable, but not all of its children are
            guard let root = coder.decodeObject() as? SWRevealViewController,
                root.frontViewController != nil else
            {
                return
            }
            self.appWindow?.rootViewController = root
        }
    }
    
    internal func followDeeplink(_ deeplink: DeepLink) {
        self.deeplink = deeplink
        _ = deeplink.popFirst
        self.start()
    }
}

// This logic is taken from AppDelegate as-is, not refactored
extension WindowsCoordinator: ForceUpgradeViewDelegate {
    @objc func performForceUpgrade(_ notification: Notification) {
        guard let keywindow = UIApplication.shared.keyWindow else {
            return
        }
        
        if let exsitView = upgradeView {
            keywindow.bringSubviewToFront(exsitView)
            return
        }
        
        let view = ForceUpgradeView(frame: keywindow.bounds)
        self.upgradeView = view
        if let msg = notification.object as? String {
            view.messageLabel.text = msg
        }
        view.delegate = self
        UIView.transition(with: keywindow, duration: 0.25,
                          options: .transitionCrossDissolve, animations: {
                            keywindow.addSubview(view)
        }, completion: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func rotated() {
        if let view = self.upgradeView {
            guard let keywindow = UIApplication.shared.keyWindow else {
                return
            }
            
            UIView.animate(withDuration: 0.25, delay: 0.0,
                           options: UIView.AnimationOptions.layoutSubviews, animations: {
                            view.frame = keywindow.frame
                            view.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    func learnMore() {
        if UIApplication.shared.canOpenURL(.forceUpgrade) {
            UIApplication.shared.openURL(.forceUpgrade)
        }
    }
    func update() {
        if UIApplication.shared.canOpenURL(.appleStore) {
            UIApplication.shared.openURL(.appleStore)
        }
    }
}

