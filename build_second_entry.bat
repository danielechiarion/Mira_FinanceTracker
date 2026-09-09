@echo off
SET SOURCE_PATH=desktop/background_check.dart
SET FLUTTER_BUILD_PATH=build\windows\x64\runner\Release\mira_finance_tracker.exe
SET BUILD_PATH=build\background_check.exe

flutter build windows --release --target=%SOURCE_PATH%
if errorlevel 1 exit /b %errorlevel%
copy /Y %FLUTTER_BUILD_PATH% %BUILD_PATH% >NUL