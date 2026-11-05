@echo off
rem ===== Терминал модуля в режиме киоска (Chrome, иначе Edge) =====
rem Вызывается из Terminal_<КОД>.bat:  call _kiosk.bat КОД
chcp 65001 >nul
setlocal
set "CODE=%~1"
if "%CODE%"=="" (
  set /p "CODE=Код модуля (например PARADISE): "
)
if "%CODE%"=="" exit /b 1
set "URL=https://m-sinkevich.github.io/paradise/terminal.html?module=%CODE%"

rem Отдельный профиль браузера: в нём хранится выгруженная оффлайн-база,
rem и киоск открывается, даже если обычный Chrome уже запущен.
set "PROFILE=%LOCALAPPDATA%\ParadiseKiosk\%CODE%"
if not exist "%PROFILE%" mkdir "%PROFILE%"

rem Не засыпать и не гасить экран (от сети и от батареи)
powercfg /change monitor-timeout-ac 0 >nul 2>&1
powercfg /change monitor-timeout-dc 0 >nul 2>&1
powercfg /change standby-timeout-ac 0 >nul 2>&1
powercfg /change standby-timeout-dc 0 >nul 2>&1
powercfg /change hibernate-timeout-ac 0 >nul 2>&1
powercfg /change hibernate-timeout-dc 0 >nul 2>&1

set "FLAGS=--kiosk --user-data-dir="%PROFILE%" --no-first-run --no-default-browser-check --disable-pinch --overscroll-history-navigation=0 --autoplay-policy=no-user-gesture-required --use-fake-ui-for-media-stream --disable-translate --disable-features=Translate,TranslateUI --noerrdialogs --disable-session-crashed-bubble --hide-crash-restore-bubble --disable-infobars --check-for-update-interval=31536000"

set "BR="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "BR=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined BR if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "BR=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined BR if exist "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe" set "BR=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
if defined BR (
  start "" "%BR%" %FLAGS% "%URL%"
  exit /b 0
)

set "BR="
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "BR=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined BR if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "BR=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if defined BR (
  start "" "%BR%" %FLAGS% --edge-kiosk-type=fullscreen --no-first-run "%URL%"
  exit /b 0
)

echo Не найден ни Google Chrome, ни Microsoft Edge. Установите Chrome.
pause
exit /b 1
