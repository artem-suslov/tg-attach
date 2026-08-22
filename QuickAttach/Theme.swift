import UIKit

/// Palette approximating Telegram iOS "Day Classic" theme.
enum Theme {
    static let accent = UIColor(red: 0.0, green: 0.494, blue: 0.898, alpha: 1.0)          // #007EE5
    static let chatBackground = UIColor(red: 0.839, green: 0.882, blue: 0.831, alpha: 1.0) // wallpaper-like greenish gray
    static let incomingBubble = UIColor.white
    static let outgoingBubble = UIColor(red: 0.882, green: 1.0, blue: 0.780, alpha: 1.0)   // #E1FFC7
    static let incomingText = UIColor.black
    static let outgoingText = UIColor.black
    static let incomingTime = UIColor(white: 0.0, alpha: 0.35)
    static let outgoingTime = UIColor(red: 0.0, green: 0.53, blue: 0.0, alpha: 0.55)
    static let panelBackground = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1.0)
    static let panelSeparator = UIColor(white: 0.0, alpha: 0.15)
    static let panelIcon = UIColor(red: 0.55, green: 0.56, blue: 0.58, alpha: 1.0)
    static let fieldBackground = UIColor.white
    static let fieldBorder = UIColor(white: 0.0, alpha: 0.12)
    static let placeholder = UIColor(white: 0.0, alpha: 0.30)
    static let navBackground = UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 0.94)
    static let subtitle = UIColor(white: 0.0, alpha: 0.45)
}
