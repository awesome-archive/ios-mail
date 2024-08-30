//
//  NewMessageBodyViewModel.swift
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

import ProtonCore_DataModel
import SwiftSoup
import UIKit
import WebKit

protocol NewMessageBodyViewModelDelegate: AnyObject {
    func reloadWebView(forceRecreate: Bool)
    func showReloadError()
}

enum MessageDisplayMode {
    case collapsed // Only latest message, without previous response
    case expanded // Full body

    mutating func toggle() {
        switch self {
        case .collapsed:
            self = .expanded
        case .expanded:
            self = .collapsed
        }
    }
}

struct BodyParts {
    let originalBody: String
    let strippedBody: String
    let darkModeCSS: String?

    let bodyHasHistory: Bool

    init(originalBody: String, isNewsLetter: Bool, isPlainText: Bool) {
        self.originalBody = originalBody
        let level = CSSMagic.darkStyleSupportLevel(htmlString: originalBody,
                                                   isNewsLetter: isNewsLetter,
                                                   isPlainText: isPlainText)
        switch level {
        case .protonSupport:
            self.darkModeCSS = CSSMagic.generateCSSForDarkMode(htmlString: originalBody)
        case .notSupport:
            self.darkModeCSS = nil
        case .nativeSupport:
            self.darkModeCSS = ""
        }

        var bodyHasHistory = false

        do {
            let fullHTMLDocument = try SwiftSoup.parse(originalBody)
            fullHTMLDocument.outputSettings().prettyPrint(pretty: false)

            for quoteElement in String.quoteElements {
                let elements = try fullHTMLDocument.select(quoteElement)
                if !elements.isEmpty() {
                    bodyHasHistory = true
                }
                try elements.remove()
            }
            strippedBody = try fullHTMLDocument.html()
        } catch {
            assertionFailure("\(error)")
            strippedBody = originalBody
        }

        self.bodyHasHistory = bodyHasHistory
    }

    func body(for displayMode: MessageDisplayMode) -> String {
        switch displayMode {
        case .collapsed:
            return strippedBody
        case .expanded:
            return originalBody
        }
    }
}

final class NewMessageBodyViewModel: LinkOpeningValidator {

    var recalculateCellHeight: ((_ isLoaded: Bool) -> Void)?
    let internetStatusProvider: InternetConnectionStatusProvider
    let linkConfirmation: LinkOpeningMode
    let userKeys: UserKeys

    weak var delegate: NewMessageBodyViewModelDelegate?
    private(set) var spam: SpamType?
    private(set) var currentMessageRenderStyle: MessageRenderStyle = .dark
    private(set) var contents: WebContents? {
        didSet {
            guard contents != oldValue else { return }

            delegate?.reloadWebView(forceRecreate: false)
        }
    }

    var placeholderContent: String {
        var css: String
        switch currentMessageRenderStyle {
        case .lightOnly:
            css = WebContents.cssLightModeOnly
        case .dark:
            css = WebContents.css
        }

        let meta = "<meta name=\"viewport\" content=\"width=device-width\">"

        let htmlString = """
                            <html><head>\(meta)<style type='text/css'>
                            \(css)</style>
                            </head></html>
                         """
        return htmlString
    }

    var webViewPreferences: WKPreferences {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = false
        preferences.javaScriptCanOpenWindowsAutomatically = false
        return preferences
    }

    var webViewConfig: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = [.phoneNumber, .link]
        return config
    }

    init(spamType: SpamType?,
         internetStatusProvider: InternetConnectionStatusProvider,
         linkConfirmation: LinkOpeningMode,
         userKeys: UserKeys
        ) {
        self.spam = spamType
        self.internetStatusProvider = internetStatusProvider
        self.linkConfirmation = linkConfirmation
        self.userKeys = userKeys
    }

    func errorHappens() {
        delegate?.showReloadError()
    }

    func update(content: WebContents?) {
        self.contents = content
    }

    func update(renderStyle: MessageRenderStyle) {
        self.currentMessageRenderStyle = renderStyle
    }

    func update(spam: SpamType?) {
        self.spam = spam
    }
}

struct BannerHelper {
    let embeddedContentPolicy: WebContents.EmbeddedContentPolicy
    let remoteContentPolicy: WebContents.RemoteContentPolicy
    let isHavingEmbeddedImages: Bool

    func calculateBannerStatus(bodyToCheck: String, result: @escaping (Bool, Bool) -> Void) {
        calculateRemoteBannerStatus(bodyToCheck: bodyToCheck) { shouldShowRemoteBanner in
            let shouldShowEmbeddedBanner = self.shouldShowEmbeddedBanner()
            result(shouldShowRemoteBanner, shouldShowEmbeddedBanner)
        }
    }

    func calculateRemoteBannerStatus(bodyToCheck: String, result: @escaping ((Bool) -> Void)) {
        if remoteContentPolicy != .allowed {
            DispatchQueue.global().async {
                // this method is slow
                let shouldShowRemoteBanner = bodyToCheck.hasRemoteImage()
                DispatchQueue.main.async {
                    result(shouldShowRemoteBanner)
                }
            }
        } else {
            result(false)
        }
    }

    func shouldShowEmbeddedBanner() -> Bool {
        return embeddedContentPolicy != .allowed && isHavingEmbeddedImages
    }
}
