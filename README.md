# CursorNotify — уведомления для Claude Code в **Cursor IDE** (macOS)

Это **форк** проекта [ClaudeNotify](https://github.com/Ph0enixT1m3/ClaudeNotify), заточенный **только под [Cursor](https://cursor.com/)**: нативные уведомления macOS и автофокус на окно **Cursor** по клику (не VS Code).

Оригинал ориентирован на Visual Studio Code. Здесь заменены пути к IDE, bundle ID и подписи в уведомлениях. Логика `UNUserNotificationCenter` и сборка Swift остаются теми же.

## Что даёт

- Уведомление, когда агент завершил задачу (звук Hero)
- Уведомление, когда нужно разрешение вне проекта (звук Glass)
- Уведомление, когда агент ждёт ответа (звук Tink)
- По клику на уведомление — вывод **Cursor** на передний план
- Скилл `/setup-project` — автономные разрешения внутри проекта (как в оригинале)

## Системные требования

- macOS 13 (Ventura) или новее
- **[Cursor](https://cursor.com/)** с расширением Claude Code (`anthropic.claude-code`)
- Xcode Command Line Tools: `xcode-select --install`
- Python 3

## Установка

### Вариант 1 — через Cursor (рекомендуется)

В чате Claude Code в Cursor:

```
Прочитай и выполни инструкции из: https://raw.githubusercontent.com/kiryxabykiryxaby/ClaudeNotify-Cursor/main/INSTALL-PROMPT.md
```

Исходники и обсуждения: [github.com/kiryxabykiryxaby/ClaudeNotify-Cursor](https://github.com/kiryxabykiryxaby/ClaudeNotify-Cursor).

### Вариант 2 — `install.sh`

```bash
git clone https://github.com/kiryxabykiryxaby/ClaudeNotify-Cursor.git
cd ClaudeNotify-Cursor
bash install.sh
```

Скрипт проверит Cursor в `/Applications/Cursor.app`, соберёт `~/Applications/ClaudeNotify.app`, настроит хуки в `~/.claude/settings.json`, скопирует скилл `setup-project` и отправит тестовое уведомление. Иконка подтягивается из `~/.cursor/extensions/anthropic.claude-code-*`.

После установки:

1. Если macOS спросила доступ к уведомлениям — **Разрешить**
2. **System Settings → Notifications → Cursor → Alerts**
3. Перезапусти сессию Claude Code в Cursor

## Использование

В корне нового проекта в Cursor:

```
/setup-project
```

Создаётся `.claude/settings.json` с разрешениями внутри репозитория (без лишних диалогов на каждую команду).

## Уведомления

| Иконка | Звук | Когда |
|--------|------|--------|
| ✅ | Hero | Задача выполнена или ответ готов |
| ⚠️ | Glass | Нужно разрешение |
| 💬 | Tink | Агент ждёт ответа |

Клик по баннеру активирует **Cursor**.

## Архитектура

```
~/.claude/settings.json (hooks: Stop, PermissionRequest, Notification)
        │
        └── open ~/Applications/ClaudeNotify.app --args "текст" "Cursor" "звук"
                    │
                    └── UNUserNotificationCenter → клик → NSWorkspace → Cursor
```

Исполняемый файл по-прежнему называется `ClaudeNotify` — так совместимы существующие хуки и пути; отображаемое имя приложения в системе — **Cursor** (см. `Info.plist`).

## Bundle ID Cursor

В коде используется `com.todesktop.230313mzl4w4u92` (типичный bundle ID дистрибутива Cursor). Если после обновления Cursor перестанет активироваться по клику, проверь актуальный ID:

```bash
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/Cursor.app/Contents/Info.plist
```

и обнови константу `kCursorBundleId` в `ClaudeNotify-source/main.swift`, затем пересобери (`bash install.sh` или шаги из скилла).

## Безопасность

Сборка из исходников на вашем Mac (`swiftc`), готовые бинарники не скачиваются. Ad-hoc подпись: при первом запуске Gatekeeper может запросить подтверждение — см. раздел ниже.

### Gatekeeper

```bash
xattr -dr com.apple.quarantine ~/Applications/ClaudeNotify.app
```

либо **System Settings → Privacy & Security → Open Anyway**.

## Troubleshooting

| Проблема | Что сделать |
|----------|-------------|
| Нет уведомлений | Notifications → **Cursor** → включить, режим **Alerts** |
| «Cursor» нет в списке | Запусти: `open ~/Applications/ClaudeNotify.app --args "тест" "Cursor" "Glass"` |
| Клик не поднимает IDE | Проверь Cursor в `/Applications/Cursor.app` и bundle ID (см. выше) |
| Ошибка `swiftc` | `xcode-select --install`, снова `bash install.sh` |
| Дубликаты уведомлений | В `~/.claude/settings.json` не должно быть двойных хуков Stop / PermissionRequest / Notification |

## Связь с оригиналом

- **Этот форк (только Cursor IDE):** [kiryxabykiryxaby/ClaudeNotify-Cursor](https://github.com/kiryxabykiryxaby/ClaudeNotify-Cursor)
- **Идея и upstream (VS Code):** [Ph0enixT1m3/ClaudeNotify](https://github.com/Ph0enixT1m3/ClaudeNotify) (MIT)

## Лицензия

MIT (как у оригинала).
