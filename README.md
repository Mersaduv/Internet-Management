# Jahan Bit / جهان بیت

جهان بیت — Jahan Bit internet management

## Build (۳ اسکریپت)

از ریشهٔ پروژه:

```powershell
# Android → dist\android\Jahan_Bit-v…-release.apk
.\tools\build_android.ps1

# Windows → dist\windows\Jahan_Bit.exe (+ DLL)
.\tools\build_windows.ps1
.\tools\build_windows.ps1 -Installer   # + dist\installer\Jahan_Bit-Setup.exe

# iOS → dist\ios\Jahan_Bit-….ipa
# روی ویندوز: بعد از push به master، CI را منتظر می‌ماند و IPA را دانلود می‌کند
# روی مک: بیلد محلی unsigned
.\tools\build_ios.ps1
```

خروجی‌ها فقط در `dist\android` ، `dist\windows` ، `dist\ios` (و در صورت نصب‌کننده: `dist\installer`).
