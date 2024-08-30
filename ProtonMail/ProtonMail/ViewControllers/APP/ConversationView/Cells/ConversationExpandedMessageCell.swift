import ProtonCore_UIFoundations

class ConversationExpandedMessageCell: UITableViewCell {

    var prepareForReuseBlock: (() -> Void)?
    var messageId: MessageID?
    let container = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.backgroundColor = ColorProvider.BackgroundDeep
        addSubviews()
        setUpLayout()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        container.subviews.forEach { $0.removeFromSuperview() }
        messageId = nil
        prepareForReuseBlock?()
    }

    private func addSubviews() {
        contentView.addSubview(container)
    }

    private func setUpLayout() {
        [
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ].activate()
    }

}
