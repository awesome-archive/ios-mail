//
//  RemoteAndEmbededBannerView.swift
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

import ProtonCore_UIFoundations

class RemoteAndEmbeddedBannerView: UIView {

    init() {
        super.init(frame: .zero)
        backgroundColor = ColorProvider.BackgroundSecondary
        setCornerRadius(radius: 8)
        addSubviews()
        setUpLayout()
    }

    let loadContentButton = SubviewsFactory.loadContentButton
    let loadImagesButton = SubviewsFactory.loadImagesButton
    let buttonStackView = SubviewsFactory.buttonStackView
    let iconView = SubviewsFactory.iconImageView
    let titleLabel = SubviewsFactory.titleLabel

    required init?(coder: NSCoder) {
        nil
    }

    private func addSubviews() {
        addSubview(iconView)
        addSubview(buttonStackView)
        buttonStackView.addArrangedSubview(loadContentButton)
        buttonStackView.addArrangedSubview(loadImagesButton)
        addSubview(titleLabel)
    }

    private func setUpLayout() {
        [
            iconView.topAnchor.constraint(equalTo: self.topAnchor, constant: 16.0),
            iconView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16.0),
            iconView.heightAnchor.constraint(equalToConstant: 20.0),
            iconView.widthAnchor.constraint(equalToConstant: 20.0)
        ].activate()

        [
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ].activate()
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        [
            loadContentButton.heightAnchor.constraint(equalToConstant: 32),
            loadImagesButton.heightAnchor.constraint(equalToConstant: 32)
        ].activate()

        [
            buttonStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12.0),
            buttonStackView.leadingAnchor.constraint(equalTo: iconView.leadingAnchor),
            buttonStackView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16)
        ].activate()
    }
}

private enum SubviewsFactory {

    static var buttonStackView: UIStackView {
        let view = UIStackView(frame: .zero)
        view.axis = .horizontal
        view.distribution = .fillEqually
        view.spacing = 12
        return view
    }

    static var loadContentButton: UIButton {
        button(title: LocalString._banner_load_remote_content)
    }

    static var loadImagesButton: UIButton {
        button(title: LocalString._banner_load_embedded_image)
    }

    static var titleLabel: UILabel {
        let label = UILabel(frame: .zero)
        label.attributedText = LocalString._banner_remote_and_embedded_title.apply(style: FontManager.Caption)
        label.numberOfLines = 0
        return label
    }

    static var iconImageView: UIImageView {
        let imageView = UIImageView(image: IconProvider.fileShapes)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = ColorProvider.IconNorm
        return imageView
    }

    private static func button(title: String) -> UIButton {
        let button = UIButton(frame: .zero)
        button.backgroundColor = ColorProvider.InteractionWeak
        button.setCornerRadius(radius: 8)
        let attributes = FontManager.body3RegularNorm
        button.setAttributedTitle(title.apply(style: attributes), for: .normal)
        button.setAttributedTitle(
            title.apply(style: attributes.foregroundColor(ColorProvider.TextDisabled)),
            for: .disabled
        )
        return button
    }

}