import UIKit

/// Text message bubble in Telegram Day Classic style.
final class TextMessageCell: UITableViewCell {
    static let reuseIdentifier = "TextMessageCell"

    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.layer.cornerRadius = 17
        bubbleView.layer.shadowColor = UIColor.black.cgColor
        bubbleView.layer.shadowOpacity = 0.06
        bubbleView.layer.shadowRadius = 1
        bubbleView.layer.shadowOffset = CGSize(width: 0, height: 1)
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 17)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(messageLabel)

        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(timeLabel)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.78),

            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 13),
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -6),

            timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -7),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with message: Message) {
        guard case let .text(text) = message.content else { return }
        messageLabel.text = text
        timeLabel.text = message.timeString
        if message.isOutgoing {
            bubbleView.backgroundColor = Theme.outgoingBubble
            messageLabel.textColor = Theme.outgoingText
            timeLabel.textColor = Theme.outgoingTime
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        } else {
            bubbleView.backgroundColor = Theme.incomingBubble
            messageLabel.textColor = Theme.incomingText
            timeLabel.textColor = Theme.incomingTime
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
    }
}

/// Photo message bubble (optionally with a caption).
final class PhotoMessageCell: UITableViewCell {
    static let reuseIdentifier = "PhotoMessageCell"

    private let bubbleView = UIView()
    private let photoView = UIImageView()
    private let captionLabel = UILabel()
    private let timeBadge = UIView()
    private let timeLabel = UILabel()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var captionBottomConstraint: NSLayoutConstraint!
    private var photoBottomConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        bubbleView.layer.cornerRadius = 17
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)

        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(photoView)

        captionLabel.numberOfLines = 0
        captionLabel.font = .systemFont(ofSize: 17)
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(captionLabel)

        timeBadge.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        timeBadge.layer.cornerRadius = 10
        timeBadge.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(timeBadge)

        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = .white
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeBadge.addSubview(timeLabel)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)
        captionBottomConstraint = captionLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        photoBottomConstraint = photoView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),

            photoView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            photoView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            photoView.widthAnchor.constraint(equalToConstant: 240),
            photoView.heightAnchor.constraint(equalToConstant: 240),

            captionLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 13),
            captionLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -13),
            captionLabel.topAnchor.constraint(equalTo: photoView.bottomAnchor, constant: 6),

            timeBadge.trailingAnchor.constraint(equalTo: photoView.trailingAnchor, constant: -8),
            timeBadge.bottomAnchor.constraint(equalTo: photoView.bottomAnchor, constant: -8),

            timeLabel.leadingAnchor.constraint(equalTo: timeBadge.leadingAnchor, constant: 7),
            timeLabel.trailingAnchor.constraint(equalTo: timeBadge.trailingAnchor, constant: -7),
            timeLabel.topAnchor.constraint(equalTo: timeBadge.topAnchor, constant: 3),
            timeLabel.bottomAnchor.constraint(equalTo: timeBadge.bottomAnchor, constant: -3),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with message: Message) {
        guard case let .photo(image, caption) = message.content else { return }
        photoView.image = image
        timeLabel.text = message.timeString
        captionLabel.text = caption

        let hasCaption = (caption?.isEmpty == false)
        captionLabel.isHidden = !hasCaption
        captionBottomConstraint.isActive = hasCaption
        photoBottomConstraint.isActive = !hasCaption

        if message.isOutgoing {
            bubbleView.backgroundColor = Theme.outgoingBubble
            captionLabel.textColor = Theme.outgoingText
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        } else {
            bubbleView.backgroundColor = Theme.incomingBubble
            captionLabel.textColor = Theme.incomingText
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
    }
}
