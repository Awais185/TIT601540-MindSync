@echo off
setlocal
cd /d "%~dp0"

for /f "delims=" %%i in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\pick_lan_host.ps1"') do set LAN_HOST=%%i

if "%LAN_HOST%"=="" (
  echo No Wi-Fi LAN IP found. PC may be on USB/virtual network only.
  echo Use USB instead:  ..\dev_phone_usb.bat
  echo Or set IP manually:  run_android_phone.bat 192.168.x.x
  exit /b 1
)

if not "%~1"=="" set LAN_HOST=%~1

echo.
echo  MindSync on physical Android
echo  Backend must be running: MindSync\backend\run_dev_server.bat
echo  Phone API URL: http://%LAN_HOST%:8000
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_flutter.ps1" run --dart-define=DEV_LAN_HOST=%LAN_HOST% --dart-define=USE_USB_BACKEND=false %*
endlocal
