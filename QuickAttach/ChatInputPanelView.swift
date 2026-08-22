import UIKit

/// Telegram-style chat composer: "+" attach button, text field, send/mic button,
/// plus an attachment chip row (photo preview with an "×" badge) shown above the
/// text row when a photo has been quick-attached.
final class ChatInputPanelView: UIView {

    let attachButton = UIButton(type: .system)
    private let attachIcon = UIImageView()
    private let separator = UIView()
    private let fieldBackground = UIView()
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)

    private let chipContainer = UIView()
    private let chipImageView = UIImageView()
    private let chipRemoveButton = UIButton(type: .system)
    private var chipHeightConstraint: NSLayoutConstraint!

    private(set) var attachedImage: UIImage?

    var onSend: ((String?, UIImage?) -> Void)?
    var onAttachTap: (() -> Void)?

    private let chipSide: CGFloat = 64
    private let chipTopPadding: CGFloat = 10

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.panelBackground

        separator.backgroundColor = Theme.panelSeparator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        // Attachment chip row (hidden by default).
        chipContainer.translatesAutoresizingMaskIntoConstraints = false
        chipContainer.clipsToBounds = true
        addSubview(chipContainer)

        chipImageView.contentMode = .scaleAspectFill
        chipImageView.clipsToBounds = true
        chipImageView.layer.cornerRadius = 10
        chipImageView.translatesAutoresizingMaskIntoConstraints = false
        chipContainer.addSubview(chipImageView)

        chipRemoveButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)), for: .normal)
        chipRemoveButton.tintColor = .white
        chipRemoveButton.backgroundColor = UIColor(white: 0.2, alpha: 0.85)
        chipRemoveButton.layer.cornerRadius = 11
        chipRemoveButton.layer.borderWidth = 1.5
        chipRemoveButton.layer.borderColor = UIColor.white.cgColor
        chipRemoveButton.translatesAutoresizingMaskIntoConstraints = false
        chipRemoveButton.addTarget(self, action: #selector(removeAttachment), for: .touchUpInside)
        chipContainer.addSubview(chipRemoveButton)

        // Attach "+" button.
        attachButton.translatesAutoresizingMaskIntoConstraints = false
        attachButton.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
        attachButton.tintColor = Theme.panelIcon
        attachButton.backgroundColor = UIColor(white: 0.0, alpha: 0.05)
        attachButton.layer.cornerRadius = 17
        addSubview(attachButton)
        attachButton.addTarget(self, action: #selector(attachTapped), for: .touchUpInside)

        // Text field.
        fieldBackground.backgroundColor = Theme.fieldBackground
        fieldBackground.layer.cornerRadius = 17
        fieldBackground.layer.borderWidth = 0.5
        fieldBackground.layer.borderColor = Theme.fieldBorder.cgColor
        fieldBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fieldBackground)

        textField.attributedPlaceholder = NSAttributedString(
            string: "Сообщение",
            attributes: [.foregroundColor: Theme.placeholder]
        )
        textField.font = .systemFont(ofSize: 17)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        textField.returnKeyType = .send
        textField.delegate = self
        fieldBackground.addSubview(textField)

        // Send / mic buttons.
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setImage(UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)), for: .normal)
        sendButton.tintColor = .white
        sendButton.backgroundColor = Theme.accent
        sendButton.layer.cornerRadius = 17
        sendButton.alpha = 0.0
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        addSubview(sendButton)

        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.setImage(UIImage(systemName: "mic", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)), for: .normal)
        micButton.tintColor = Theme.panelIcon
        addSubview(micButton)

        chipHeightConstraint = chipContainer.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            chipContainer.topAnchor.constraint(equalTo: topAnchor),
            chipContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            chipContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            chipHeightConstraint,

            chipImageView.leadingAnchor.constraint(equalTo: chipContainer.leadingAnchor),
            chipImageView.topAnchor.constraint(equalTo: chipContainer.topAnchor, constant: chipTopPadding),
            chipImageView.widthAnchor.constraint(equalToConstant: chipSide),
            chipImageView.heightAnchor.constraint(equalToConstant: chipSide),

            chipRemoveButton.centerXAnchor.constraint(equalTo: chipImageView.trailingAnchor, constant: -4),
            chipRemoveButton.centerYAnchor.constraint(equalTo: chipImageView.topAnchor, constant: 4),
            chipRemoveButton.widthAnchor.constraint(equalToConstant: 22),
            chipRemoveButton.heightAnchor.constraint(equalToConstant: 22),

            attachButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            attachButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            attachButton.widthAnchor.constraint(equalToConstant: 34),
            attachButton.heightAnchor.constraint(equalToConstant: 34),

            fieldBackground.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 8),
            fieldBackground.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            fieldBackground.topAnchor.constraint(equalTo: chipContainer.bottomAnchor, constant: 8),
            fieldBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            fieldBackground.heightAnchor.constraint(equalToConstant: 34),

            textField.leadingAnchor.constraint(equalTo: fieldBackground.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: fieldBackground.trailingAnchor, constant: -12),
            textField.topAnchor.constraint(equalTo: fieldBackground.topAnchor),
            textField.bottomAnchor.constraint(equalTo: fieldBackground.bottomAnchor),

            sendButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            sendButton.centerYAnchor.constraint(equalTo: fieldBackground.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34),

            micButton.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Attachment chip

    /// Reserves the chip slot (expands the panel) and returns the frame the flying
    /// thumbnail should land in, in `view`'s coordinate space. The chip itself is
    /// revealed later via `revealAttachment`.
    func prepareAttachmentSlot(in view: UIView) -> CGRect {
        chipHeightConstraint.constant = chipSide + chipTopPadding
        chipImageView.alpha = 0.0
        chipRemoveButton.alpha = 0.0
        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.3) {
            self.superview?.layoutIfNeeded()
        }
        superview?.layoutIfNeeded()
        return chipImageView.convert(chipImageView.bounds, to: view)
    }

    func revealAttachment(_ image: UIImage) {
        attachedImage = image
        chipImageView.image = image
        chipImageView.alpha = 1.0
        chipRemoveButton.alpha = 0.0
        chipRemoveButton.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.25, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.4) {
            self.chipRemoveButton.alpha = 1.0
            self.chipRemoveButton.transform = .identity
        }
        updateSendButton()
    }

    @objc private func removeAttachment() {
        attachedImage = nil
        chipHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.chipImageView.alpha = 0.0
            self.chipRemoveButton.alpha = 0.0
            self.superview?.layoutIfNeeded()
        } completion: { _ in
            self.chipImageView.image = nil
        }
        updateSendButton()
    }

    func clearAfterSend() {
        textField.text = nil
        attachedImage = nil
        chipImageView.image = nil
        chipImageView.alpha = 0.0
        chipRemoveButton.alpha = 0.0
        chipHeightConstraint.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.superview?.layoutIfNeeded()
        }
        updateSendButton()
    }

    // MARK: - Actions

    @objc private func attachTapped() {
        onAttachTap?()
    }

    @objc private func textChanged() {
        updateSendButton()
    }

    @objc private func sendTapped() {
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (text?.isEmpty == false) || attachedImage != nil else { return }
        onSend?(text?.isEmpty == false ? text : nil, attachedImage)
    }

    private func updateSendButton() {
        let hasContent = (textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) || attachedImage != nil
        UIView.animate(withDuration: 0.2) {
            self.sendButton.alpha = hasContent ? 1.0 : 0.0
            self.micButton.alpha = hasContent ? 0.0 : 1.0
        }
    }
}

extension ChatInputPanelView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return false
    }
}
