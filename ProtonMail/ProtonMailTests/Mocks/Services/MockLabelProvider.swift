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

import Foundation
@testable import ProtonMail
import PromiseKit

class MockLabelProvider: LabelProviderProtocol {
    var customFolderToReturn: [LabelEntity] = []
    var mockLabelPublisherToReturn: MockLabelPublisher?
    private(set) var wasFetchV4LabelsCalled: Bool = false

    func makePublisher() -> LabelPublisherProtocol {
        return mockLabelPublisherToReturn!
    }

    func getCustomFolders() -> [LabelEntity] {
        return customFolderToReturn
    }

    func fetchV4Labels(completion: ((Swift.Result<Void, NSError>) -> Void)?) {
        wasFetchV4LabelsCalled = true
        completion?(.success)
    }
}

class MockLabelPublisher: LabelPublisherProtocol {
    weak var delegate: LabelListenerProtocol?
    var labelsToReturn: [LabelEntity] = []

    func fetchLabels(labelType: LabelFetchType) {
        delegate?.receivedLabels(labels: labelsToReturn)
    }
}
