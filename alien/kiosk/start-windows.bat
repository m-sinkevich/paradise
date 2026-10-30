@echo off
rem Запуск инопланетного терминала во весь экран (режим киоска).
rem Чтобы запускался при входе в Windows: Win+R -> shell:startup -> положить туда ярлык на этот файл.
rem Выход из киоска: Alt+F4.
set OPTS=
set PAGE=%~dp0..\index.html
set PAGE=%PAGE:\=/%
set CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe
if not exist "%CHROME%" set CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe
if exist "%CHROME%" (
  start "" "%CHROME%" --kiosk --incognito --noerrdialogs --disable-session-crashed-bubble --disable-pinch --overscroll-history-navigation=0 --autoplay-policy=no-user-gesture-required "file:///%PAGE%?%OPTS%"
) else (
  start "" msedge --kiosk "file:///%PAGE%?%OPTS%" --edge-kiosk-type=fullscreen --no-first-run
)
