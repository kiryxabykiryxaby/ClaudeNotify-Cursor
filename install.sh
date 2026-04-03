#!/bin/bash
set -e

echo "🔧 CursorNotify Setup (форк ClaudeNotify для Cursor IDE)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Проверка Xcode CLI Tools
if ! xcode-select -p &>/dev/null; then
    echo "❌ Xcode Command Line Tools не установлены."
    echo "   Запусти: xcode-select --install"
    echo "   После установки запусти install.sh снова."
    exit 1
fi
echo "✓ Xcode CLI Tools найдены"

# 2. Проверка Cursor
if [ ! -d "/Applications/Cursor.app" ]; then
    echo "⚠️  Cursor не найден в /Applications/Cursor.app"
    echo "   Установи Cursor с https://cursor.com и запусти install.sh снова."
    exit 1
fi
echo "✓ Cursor найден"

# Цель сборки Swift (Apple Silicon / Intel)
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    SWIFT_TARGET="arm64-apple-macos13.0"
else
    SWIFT_TARGET="x86_64-apple-macos13.0"
fi

# 3. Копируем исходник и скилл
mkdir -p ~/.claude/ClaudeNotify-source ~/.claude/skills
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/ClaudeNotify-source/main.swift" ~/.claude/ClaudeNotify-source/
cp "$SCRIPT_DIR/claude-skills/setup-project.md" ~/.claude/skills/
echo "✓ Файлы скопированы в ~/.claude/"

# 4. Собираем ClaudeNotify.app (имя бинарника сохранено для совместимости с хуками)
APP_DIR="$HOME/Applications/ClaudeNotify.app/Contents"
mkdir -p "$APP_DIR/MacOS" "$APP_DIR/Resources"

cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.cursornotify.claude</string>
  <key>CFBundleName</key><string>Cursor</string>
  <key>CFBundleDisplayName</key><string>Cursor</string>
  <key>CFBundleExecutable</key><string>ClaudeNotify</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST

# Иконка из расширения Claude Code в Cursor
CLAUDE_EXT=$(ls ~/.cursor/extensions/ 2>/dev/null | grep anthropic.claude-code | sort -V | tail -1)
if [ -n "$CLAUDE_EXT" ]; then
    ICON_SRC="$HOME/.cursor/extensions/$CLAUDE_EXT/resources/claude-logo.png"
    if [ -f "$ICON_SRC" ]; then
        rm -rf /tmp/claude.iconset
        mkdir -p /tmp/claude.iconset
        for size in 16 32 64 128 256 512; do
            sips -z $size $size "$ICON_SRC" --out "/tmp/claude.iconset/icon_${size}x${size}.png" 2>/dev/null
            sips -z $((size*2)) $((size*2)) "$ICON_SRC" --out "/tmp/claude.iconset/icon_${size}x${size}@2x.png" 2>/dev/null
        done
        iconutil -c icns /tmp/claude.iconset -o "$APP_DIR/Resources/AppIcon.icns" 2>/dev/null
        echo "✓ Иконка Claude добавлена из Cursor extensions"
    fi
fi

echo "⏳ Компилируем ClaudeNotify.app (target: $SWIFT_TARGET)..."
swiftc ~/.claude/ClaudeNotify-source/main.swift \
    -o "$APP_DIR/MacOS/ClaudeNotify" \
    -framework Cocoa \
    -framework UserNotifications \
    -target "$SWIFT_TARGET"
echo "✓ Скомпилировано"

# 5. Подписываем
codesign --sign - --force "$HOME/Applications/ClaudeNotify.app"
echo "✓ Подписано"

# 6. Добавляем хуки в ~/.claude/settings.json
if [ ! -f ~/.claude/settings.json ]; then
    echo '{"hooks":{}}' > ~/.claude/settings.json
fi

python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.claude/settings.json")
with open(path, 'r') as f:
    data = json.load(f)
if "hooks" not in data:
    data["hooks"] = {}
data["hooks"]["Stop"] = [{"hooks": [{"type": "command", "async": True,
    "command": "open ~/Applications/ClaudeNotify.app --args '✅ Задача выполнена' 'Cursor' 'Hero'"}]}]
data["hooks"]["PermissionRequest"] = [{"hooks": [{"type": "command", "async": False,
    "command": "open ~/Applications/ClaudeNotify.app --args '⚠️ Нужно разрешение' 'Cursor' 'Glass'"}]}]
data["hooks"]["Notification"] = [{"matcher": "idle_prompt", "hooks": [{"type": "command", "async": True,
    "command": "open ~/Applications/ClaudeNotify.app --args '💬 Claude ждёт ответа' 'Cursor' 'Tink'"}]}]
with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print("✓ Хуки добавлены в ~/.claude/settings.json")
PYEOF

# 7. Тестовое уведомление (запрос разрешений)
echo ""
echo "⏳ Запускаем первое уведомление для запроса разрешений..."
open "$HOME/Applications/ClaudeNotify.app" --args "Нажми Разрешить если появился запрос" "Cursor" "Glass"
sleep 2

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ CursorNotify установлен!"
echo ""
echo "Следующие шаги:"
echo "1. Если появился запрос разрешений — нажми Разрешить"
echo "2. System Settings → Notifications → Cursor → Alerts"
echo "3. Перезапусти сессию Claude Code в Cursor и напиши: /setup-project"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
