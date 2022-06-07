//
//  DoHProviderGoogle.swift
//  ProtonCore-Doh - Created on 2/24/20.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCore_Log

// Txt record only
public struct Google: DoHProviderInternal {
    
    let networkingEngine: DoHNetworkingEngine

    init(networkingEngine: DoHNetworkingEngine) {
        self.networkingEngine = networkingEngine
    }

    let supported: [Int] = [DNSType.txt.rawValue]

    public let url = "https://dns.google.com"

    func query(host: String, sessionId: String?) -> String {
        if let sessionId = sessionId {
            return self.url + "/resolve?type=TXT&name=" + sessionId + "." + host
        }
        return self.url + "/resolve?type=TXT&name=" + host
    }

    func parse(response: String) -> DNS? {
        return nil
    }

    func parse(data response: Data) -> [DNS]? {
        do {
            guard let dictRes = try JSONSerialization.jsonObject(with: response, options: JSONSerialization.ReadingOptions.allowFragments) as? [String: Any] else {
                // throw error
                return nil
            }

            guard let answers = dictRes["Answer"] as? [[String: Any]] else {
                // throw error
                return nil
            }

            var addrList: [String] = []
            var ttl = -1
            for answer in answers {
                if let type = answer["type"] as? Int, supported.contains(type) {
                    if let addr = answer["data"] as? String {
                        let pureAddr = addr.replacingOccurrences(of: "\"", with: "")
                        addrList.append(pureAddr)
                    }
                    if let timeout = answer["TTL"] as? Int {
                        ttl = timeout
                    }
                }
            }
            if ttl > 0 && addrList.count > 0 {
                var dnsList: [DNS] = []
                for addr in addrList {
                    dnsList.append(DNS(url: addr, ttl: ttl))
                }
                return dnsList
            }
            return nil
        } catch {
            PMLog.debug("parse error: \(error)")
            // TODO:: throw error
            return nil
        }
    }

}