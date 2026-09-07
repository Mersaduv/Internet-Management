@echo off
REM iOS روی ویندوز بیلد نمی‌شود — فقط پیام راهنما
echo.
echo [!] بیلد iOS فقط روی macOS ممکن است.
echo.
echo روی مک:
echo   bash tools/build_ios.sh
echo.
echo یا از GitHub Actions:
echo   .github/workflows/ios-ipa.yml
echo.
pause
exit /b 1
