import UIKit

/// Telegram-style chat screen hosting the quick attach gesture:
/// long-press on "+" fans out the recent photos strip (QuickAttachOverlayView),
/// a plain tap keeps the standard behavior (full attachment menu).
final class ChatViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputPanel = ChatInputPanelView()
    private let headerView = UIView()

    private var messages: [Message] = []
    private var overlay: QuickAttachOverlayView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.chatBackground

        seedMessages()
        setupHeader()
        setupTable()
        setupInputPanel()
        setupQuickAttachGesture()

        RecentPhotosProvider.shared.prefetch()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToBottom(animated: false)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: - Setup

    private func seedMessages() {
        let calendar = Calendar.current
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }
        messages = [
            Message(content: .text("Привет! Ты уже дома?"), isOutgoing: false, date: at(9, 41)),
            Message(content: .text("Да, только зашёл 🙌"), isOutgoing: true, date: at(9, 42)),
            Message(content: .text("Скинь фотки с прогулки, пока не забыл"), isOutgoing: false, date: at(9, 43)),
            Message(content: .text("Сейчас! Кстати, попробуй зажать «+» — новый быстрый атач 😉"), isOutgoing: true, date: at(9, 44)),
        ]
    }

    private func setupHeader() {
        headerView.backgroundColor = Theme.navBackground
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let separator = UIView()
        separator.backgroundColor = Theme.panelSeparator
        separator.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(separator)

        let backIcon = UIImageView(image: UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        backIcon.tintColor = Theme.accent
        backIcon.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(backIcon)

        let titleLabel = UILabel()
        titleLabel.text = "Аня"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = "в сети"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = Theme.subtitle
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)

        let avatar = UILabel()
        avatar.text = "А"
        avatar.textColor = .white
        avatar.font = .systemFont(ofSize: 16, weight: .semibold)
        avatar.textAlignment = .center
        avatar.backgroundColor = UIColor(red: 0.91, green: 0.45, blue: 0.35, alpha: 1.0)
        avatar.layer.cornerRadius = 18
        avatar.clipsToBounds = true
        avatar.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(avatar)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),

            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            backIcon.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            backIcon.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor, constant: 8),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),

            subtitleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),

            avatar.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -12),
            avatar.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor, constant: 8),
            avatar.widthAnchor.constraint(equalToConstant: 36),
            avatar.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.register(TextMessageCell.self, forCellReuseIdentifier: TextMessageCell.reuseIdentifier)
        tableView.register(PhotoMessageCell.self, forCellReuseIdentifier: PhotoMessageCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }

    private func setupInputPanel() {
        inputPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputPanel)

        inputPanel.onAttachTap = { [weak self] in
            self?.presentFullAttachmentMenu()
        }
        inputPanel.onSend = { [weak self] text, image in
            self?.sendMessage(text: text, image: image)
        }

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputPanel.topAnchor),

            inputPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputPanel.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    // MARK: - Quick attach gesture

    private func setupQuickAttachGesture() {
        // In real Telegram-iOS this is a ContextGesture on attachmentButton
        // (same pattern as sendButtonLongPressed). Here: UILongPressGestureRecognizer.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleAttachLongPress(_:)))
        longPress.minimumPressDuration = 0.33
        inputPanel.attachButton.addGestureRecognizer(longPress)
    }

    @objc private func handleAttachLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            presentQuickAttach()
        case .changed:
            overlay?.updateTracking(location: gesture.location(in: view))
        case .ended:
            finishQuickAttach(location: gesture.location(in: view))
        case .cancelled, .failed:
            cancelQuickAttach()
        default:
            break
        }
    }

    private func presentQuickAttach() {
        guard overlay == nil else { return }
        view.endEditing(false)

        let overlay = QuickAttachOverlayView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)
        self.overlay = overlay

        // Hide the real "+" while its "×" replacement is shown by the overlay.
        let sourceRect = inputPanel.attachButton.convert(inputPanel.attachButton.bounds, to: view)
        inputPanel.attachButton.alpha = 0.0

        overlay.present(images: RecentPhotosProvider.shared.cachedThumbnails, from: sourceRect)
    }

    private func finishQuickAttach(location: CGPoint) {
        guard let overlay else { return }
        let selectedIndex = overlay.finishTracking(location: location)

        if let selectedIndex {
            let thumbnails = RecentPhotosProvider.shared.cachedThumbnails
            guard selectedIndex < thumbnails.count else {
                cancelQuickAttach()
                return
            }
            let image = thumbnails[selectedIndex]
            let targetRect = inputPanel.prepareAttachmentSlot(in: view)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            overlay.dismiss(selectedIndex: selectedIndex, targetRect: targetRect) { [weak self] in
                guard let self else { return }
                self.overlay = nil
                self.inputPanel.attachButton.alpha = 1.0
                self.inputPanel.revealAttachment(image)
            }
        } else {
            cancelQuickAttach()
        }
    }

    private func cancelQuickAttach() {
        guard let overlay else { return }
        overlay.dismiss(selectedIndex: nil, targetRect: nil) { [weak self] in
            self?.overlay = nil
            self?.inputPanel.attachButton.alpha = 1.0
        }
    }

    // MARK: - Full attachment menu (plain tap — standard behavior preserved)

    private func presentFullAttachmentMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for title in ["Камера", "Фото или видео", "Файл", "Геопозиция", "Контакт"] {
            sheet.addAction(UIAlertAction(title: title, style: .default))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = inputPanel.attachButton
            popover.sourceRect = inputPanel.attachButton.bounds
        }
        present(sheet, animated: true)
    }

    // MARK: - Sending

    private func sendMessage(text: String?, image: UIImage?) {
        var appended = 0
        if let image {
            messages.append(Message(content: .photo(image, caption: text), isOutgoing: true, date: Date()))
            appended += 1
        } else if let text {
            messages.append(Message(content: .text(text), isOutgoing: true, date: Date()))
            appended += 1
        }
        guard appended > 0 else { return }

        inputPanel.clearAfterSend()
        tableView.reloadData()
        scrollToBottom(animated: true)

        let hadPhoto = image != nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            let reply = hadPhoto ? "Вау, классное фото! 😍" : "👍"
            self.messages.append(Message(content: .text(reply), isOutgoing: false, date: Date()))
            self.tableView.reloadData()
            self.scrollToBottom(animated: true)
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        switch message.content {
        case .text:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextMessageCell.reuseIdentifier, for: indexPath) as! TextMessageCell
            cell.configure(with: message)
            return cell
        case .photo:
            let cell = tableView.dequeueReusableCell(withIdentifier: PhotoMessageCell.reuseIdentifier, for: indexPath) as! PhotoMessageCell
            cell.configure(with: message)
            return cell
        }
    }
}
