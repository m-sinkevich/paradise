@echo off
rem После игры: вернуть обычный сон и затухание экрана (10 мин экран, 30 мин сон; от батареи 5/15)
chcp 65001 >nul
powercfg /change monitor-timeout-ac 10
powercfg /change monitor-timeout-dc 5
powercfg /change standby-timeout-ac 30
powercfg /change standby-timeout-dc 15
echo Готово: сон и затухание экрана снова включены.
pause
