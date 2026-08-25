# QuickAttach

<img src="docs/fan-frames.png" width="900" alt="ten frames of the fan opening">

Telegram's iOS chat screen, rebuilt in plain UIKit — the original runs on
their AsyncDisplayKit fork, with nodes and hand-computed layout — plus one
thing Telegram doesn't have: **quick attach on a long press**, the way ChatGPT
does it.

## Why

Sending a photo you just took costs four steps — paperclip, sheet, scroll,
tap — and it's almost always one of the last few pictures in the roll.

Here you press and hold the paperclip, four thumbnails fan out of it (camera
first, then recents), you slide onto one and let go. It lands in the composer.
Release anywhere else and everything folds back. One gesture, no sheet.

## How

No dependencies, UIKit, iOS 16+.

The screen is transcribed from [Telegram-iOS](https://github.com/TelegramMessenger/Telegram-iOS) —
bubble images, the gradient wallpaper kernel, glass header and composer,
CoreText bubble widths — rather than eyeballed, but rebuilt on `UITableView`
and Auto Layout instead of their `ListView` and `ASDisplayNode`.

The fan is the interesting part. One spring per card would fly it in a straight
line, so each card runs **two springs — one on `position.x`, one on
`position.y`** — with different stiffness and damping. A fast bouncy Y plus a
slower smooth X bends the path into an arc while both axes keep real spring
physics, which a keyframed curve throws away. Cancelling swaps the two axes'
parameters and the card leaves along the path it arrived on. Numbers live in
`FanTuning.swift`, the gesture in `QuickAttachOverlayView.swift`.

## Run

Open `QuickAttach.xcodeproj`, pick a simulator, Run, hold the paperclip.
Without photo access the fan falls back to placeholders; the camera tile needs
a real device.

---

Graphics and drawing code come from Telegram-iOS (GPL-2.0). A UX prototype, not
a client.
