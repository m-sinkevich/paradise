#!/bin/bash
# ===== Терминал модуля в режиме киоска на Mac (Chrome, иначе Safari во весь экран) =====
# Вызывается из Terminal_<КОД>.command:  "$(dirname "$0")/_kiosk.sh" КОД
CODE="$1"
if [ -z "$CODE" ]; then read -r -p "Код модуля (например PARADISE): " CODE; fi
[ -z "$CODE" ] && exit 1
URL="https://m-sinkevich.github.io/paradise/terminal.html?module=$CODE"
# отдельный профиль: в нём хранится выгруженная оффлайн-база, и киоск открывается, даже если обычный Chrome запущен
PROFILE="$HOME/Library/Application Support/ParadiseKiosk/$CODE"
mkdir -p "$PROFILE"

CHROME=""
for c in "/Applications/Google Chrome.app" "$HOME/Applications/Google Chrome.app"; do
  [ -d "$c" ] && CHROME="$c/Contents/MacOS/Google Chrome" && break
done

if [ -n "$CHROME" ]; then
  nohup "$CHROME" --kiosk --user-data-dir="$PROFILE" --no-first-run --no-default-browser-check --disable-pinch \
    --overscroll-history-navigation=0 --autoplay-policy=no-user-gesture-required --use-fake-ui-for-media-stream \
    --disable-features=Translate,TranslateUI --noerrdialogs --hide-crash-restore-bubble --disable-infobars \
    --check-for-update-interval=31536000 "$URL" >/dev/null 2>&1 &
  PID=$!
  # не спать и не гасить экран, пока открыт терминал
  nohup caffeinate -dims -w "$PID" >/dev/null 2>&1 &
  disown -a
else
  # Safari: режима киоска нет — открываем во весь экран (нужно разрешение «Универсальный доступ» для Терминала)
  open -a Safari "$URL"
  sleep 3
  osascript -e 'tell application "Safari" to activate' \
            -e 'tell application "System Events" to keystroke "f" using {command down, control down}' >/dev/null 2>&1
  nohup caffeinate -dims -t 86400 >/dev/null 2>&1 &
  disown -a
fi
echo "Терминал модуля $CODE запущен. Это окно можно закрыть."
exit 0
