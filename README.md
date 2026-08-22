# Telegram Quick Attach

Демо-реализация экрана чата Telegram (iOS, UIKit, без зависимостей) с механикой **быстрого атача по лонгтапу** — как в ChatGPT: зажал «+», из кнопки веером выпрыгивают последние фото галереи, ведёшь палец — миниатюра под пальцем подсвечивается, отпустил — фото прикрепляется к полю ввода.

Проект следует спецификации из рисерч-дока `docs/` (жест, анимации, поведение при отпускании — **вариант A**: прикрепление, не мгновенная отправка).

## Как запустить

1. Открыть `QuickAttach.xcodeproj` в Xcode 16+.
2. Выбрать симулятор iPhone (iOS 16+) и нажать Run.
3. В чате зажать кнопку «+» слева от поля ввода.

Доступ к галерее запрашивается при запуске. Если доступа нет или галерея пуста (свежий симулятор), полоса показывает сгенерированные плейсхолдеры — жест работает всегда.

## Механика (спека из рисерча)

| Шаг | Поведение |
|---|---|
| Лонгтап по «+» (≈0.33 с) | Полоса из 4 последних фото «выпрыгивает» веером из точки кнопки (staggered spring, задержка 30 мс между айтемами); фон блюрится; «+» морфится в «×» |
| Палец зажат, движется | Хит-тест айтема под пальцем, подсветка scale 1.18 (spring), при смене айтема — selection-хаптик |
| Отпускание над айтемом | Невыбранные тают, блюр уходит, выбранное фото «перелетает» в композер и становится вложением-чипом с бейджем «×»; кнопка отправки активируется |
| Отпускание над «×» / мимо | Отмена: обратная анимация «в точку кнопки» |
| Обычный тап по «+» | Прежнее поведение — полное меню вложений (мок) |
| «×» на чипе | Удаление вложения, возврат к исходному состоянию |
| Отправка | Фото (с подписью, если введён текст) уходит пузырём в чат |

## Структура

```
QuickAttach/
├── ChatViewController.swift     — экран чата, роутинг жеста (began/changed/ended)
├── ChatInputPanelView.swift     — композер: «+», поле, send/mic, attachment-чип
├── QuickAttachOverlayView.swift — ядро фичи: блюр, полоса, трекинг, анимации
├── RecentPhotosProvider.swift   — PHAsset fetch последних фото + плейсхолдеры
├── ChatMessageCell.swift        — пузыри сообщений (текст / фото)
├── Theme.swift, Message.swift, AppDelegate.swift, SceneDelegate.swift
```

## Соответствие плану интеграции в настоящий Telegram-iOS

Этот проект — работающий прототип UX. Карта переноса в реальную кодовую базу (проверена по `TelegramMessenger/Telegram-iOS@master`, см. `docs/PLAN_VALIDATION.md`):

| Здесь | В Telegram-iOS |
|---|---|
| `UILongPressGestureRecognizer` на attach-кнопке | `ContextGesture` на `attachmentButton` в `ChatTextInputPanelNode` (по образцу `sendButtonLongPressed`, стр. 932) |
| `handleAttachLongPress` → overlay | Новый метод `displayQuickAttachment(...)` в `ChatPanelInterfaceInteraction` + реализация рядом с attach-меню в `ChatControllerOpenAttachmentMenu.swift` |
| `updateTracking` / `finishTracking` | `gesture.externalUpdated` / `gesture.externalEnded` (паттерн `ChatSendMessageContextScreen`, стр. 363/378) |
| `QuickAttachOverlayView` | Новый модуль `submodules/TelegramUI/Components/QuickAttachmentUI/` |
| `RecentPhotosProvider` | `PHFetchResult`-паттерны из `MediaPickerUI` |
| `UISelectionFeedbackGenerator` | `HapticFeedback` из `Display` |
| Прикрепление-чип (вариант A) | Медиапикер/превью с предвыбранным ассетом; вариант B — `enqueueMediaMessages(signals:...)` |
