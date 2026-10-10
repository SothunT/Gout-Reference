@echo off
cd /d "%~dp0"
echo Downloading food photos into the Images\photos folder...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download_images.ps1"
echo.
pause
