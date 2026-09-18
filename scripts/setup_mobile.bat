@echo off
setlocal
cd /d "%~dp0..\mobile"
if not exist android\gradlew (
  call flutter create --platforms=android,ios --org com.cropcare --project-name cropcare_ai .
  if errorlevel 1 goto failure
)
py -3.12 ..\scripts\configure_mobile.py
if errorlevel 1 goto failure
call flutter pub get
if errorlevel 1 goto failure
echo.
echo Mobile setup complete. See docs\SETUP_WINDOWS.md for emulator or phone commands.
pause
exit /b 0
:failure
echo Setup failed. Read the error above.
pause
exit /b 1
