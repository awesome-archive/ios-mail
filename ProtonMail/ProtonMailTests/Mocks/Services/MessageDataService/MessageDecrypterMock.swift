// Copyright (c) 2022 Proton AG
//
// This file is part of Proton Mail.
//
// Proton Mail is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Mail is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Mail. If not, see https://www.gnu.org/licenses/.

import CoreData
import ProtonCore_Crypto
@testable import ProtonMail

final class MessageDecrypterMock: MessageDecrypter {
    private(set) var decryptCallCount = 0

    override func decrypt(message: MessageEntity, verificationKeys: [ArmoredKey]) throws -> MessageDecrypter.Output {
        decryptCallCount += 1
        return try super.decrypt(message: message, verificationKeys: verificationKeys)
    }
}
