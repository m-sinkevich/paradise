@echo off
rem Beacon of the Four Houses - fullscreen video loop (VLC 2.2.x, Windows XP)
set VIDEO=C:\beacon\beacon.avi
set VLC=%ProgramFiles%\VideoLAN\VLC\vlc.exe

rem wait until Windows has finished starting
ping -n 15 127.0.0.1 >nul

:run
start "" /wait "%VLC%" --fullscreen --loop --no-video-title-show --no-osd --no-qt-fs-controller --mouse-hide-timeout=200 --no-qt-privacy-ask --no-qt-updates-notif --no-qt-error-dialogs --qt-continue=0 "%VIDEO%"
rem VLC closed or crashed - start again
ping -n 3 127.0.0.1 >nul
goto run
