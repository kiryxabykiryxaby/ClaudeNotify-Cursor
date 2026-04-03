# Setup Project (Cursor IDE)

When this skill is invoked, execute ALL steps automatically without asking for confirmation.

**Environment:** Claude Code running inside **Cursor** (not VS Code). Uses `~/Applications/ClaudeNotify.app` and Cursor notifications.

---

## Autonomous behavior rules (permanent, apply in ALL projects from now on)

- **Inside project folder** — execute Bash, Edit, Write, Read, Glob, Grep, MultiEdit without asking permission
- **Outside project folder** — request permission AND send ⚠️ notification before proceeding
- **Before any question to the user** — always send 💬 notification first:
  ```bash
  open ~/Applications/ClaudeNotify.app --args "💬 Claude ждёт ответа" "Cursor" "Tink"
  ```
- **Work strategy** — explore and understand the task first, then execute autonomously with minimal interruptions
- **On task completion** — send ✅ notification (handled automatically by the Stop hook)

---

## Step 1 — Build ClaudeNotify.app (skip if already exists)

Check if `~/Applications/ClaudeNotify.app` exists.

**If it exists:** skip to Step 2.

**If it does not exist:** run the following bash commands in sequence (set `SWIFT_TARGET` to `arm64-apple-macos13.0` on Apple Silicon, `x86_64-apple-macos13.0` on Intel):

```bash
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then SWIFT_TARGET="arm64-apple-macos13.0"; else SWIFT_TARGET="x86_64-apple-macos13.0"; fi

mkdir -p /tmp/claude-notify-build
cp ~/.claude/ClaudeNotify-source/main.swift /tmp/claude-notify-build/main.swift

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

CLAUDE_EXT=$(ls ~/.cursor/extensions/ | grep anthropic.claude-code | sort -V | tail -1)
ICON_SRC="$HOME/.cursor/extensions/$CLAUDE_EXT/resources/claude-logo.png"
mkdir -p /tmp/claude.iconset
for size in 16 32 64 128 256 512; do
  sips -z $size $size "$ICON_SRC" --out "/tmp/claude.iconset/icon_${size}x${size}.png" 2>/dev/null
  sips -z $((size*2)) $((size*2)) "$ICON_SRC" --out "/tmp/claude.iconset/icon_${size}x${size}@2x.png" 2>/dev/null
done
iconutil -c icns /tmp/claude.iconset -o "$APP_DIR/Resources/AppIcon.icns"

swiftc ~/.claude/ClaudeNotify-source/main.swift \
  -o "$APP_DIR/MacOS/ClaudeNotify" \
  -framework Cocoa -framework UserNotifications \
  -target "$SWIFT_TARGET"

codesign --sign - --force "$HOME/Applications/ClaudeNotify.app"

open "$HOME/Applications/ClaudeNotify.app" --args "Разреши уведомления в появившемся диалоге" "Cursor" "Glass"
```

After the first launch, tell the user:
> Если появился запрос разрешений — нажми **Разрешить**.
> Затем: **System Settings → Notifications → Cursor → Alerts**.

---

## Step 2 — Update global hooks in ~/.claude/settings.json

Read `~/.claude/settings.json` and merge hooks (do not remove existing keys). Run via python3:

```python
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
```

---

## Step 3 — Create project permissions file

Create `.claude/settings.json` in the root of the CURRENT project:

```json
{
  "permissions": {
    "allow": ["Bash(*)", "Edit(*)", "Write(*)", "Read(*)", "Glob(*)", "Grep(*)", "MultiEdit(*)"]
  }
}
```

If the file already exists, merge without removing existing entries.

---

## Step 4 — Create CURSOR-SETUP.md in project root

Create `CURSOR-SETUP.md` in the current working directory:

```markdown
## Быстрый старт (Cursor IDE)

### Требования
- macOS 13+
- [Cursor](https://cursor.com/) с расширением Claude Code (`anthropic.claude-code`)
- Xcode Command Line Tools: `xcode-select --install`

### Установка
В Cursor открой Claude Code и напиши: `/setup-project`

### Что произойдёт
- Соберётся `~/Applications/ClaudeNotify.app` — нативные уведомления с иконкой из `~/.cursor/extensions/`
- Настроятся хуки: ✅ задача выполнена, ⚠️ нужно разрешение, 💬 ждёт ответа
- При первом запуске macOS спросит разрешение — нажми Разрешить
- **System Settings → Notifications → Cursor → Alerts**
- Автономные разрешения для проекта (новая сессия Claude Code)

### Уведомления
| Звук | Когда |
|------|-------|
| Hero ✅ | Задача выполнена |
| Glass ⚠️ | Нужно разрешение |
| Tink 💬 | Ждёт ответа |

Клик на уведомление → **Cursor** на передний план.

Форк: [CursorNotify / ClaudeNotify-Cursor](https://github.com/) — только для Cursor IDE; upstream: [ClaudeNotify](https://github.com/Ph0enixT1m3/ClaudeNotify).
```

(Replace the placeholder GitHub URL with this repository’s URL once published.)

---

## Step 5 — Send completion notification

```bash
open ~/Applications/ClaudeNotify.app --args "✅ Проект настроен!" "Cursor" "Hero"
```

Tell the user:
> Готово! Переключись в другое приложение и кликни на уведомление — откроется **Cursor**.
> Разрешения вступят в силу при следующей сессии.
