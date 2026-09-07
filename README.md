# Jahan Bit / جهان بیت

جهان بیت — Jahan Bit internet management

## Build

### یک‌جا (ویندوز + اندروید)

```powershell
.\tools\build_all.ps1
.\tools\build_all.ps1 -Installer
```

یا: `tools\build_all.bat`

### جدا برای هر پلتفرم

```powershell
# فقط ویندوز (+ نصب‌کننده اختیاری)
.\tools\build_windows.ps1
.\tools\build_windows.ps1 -Installer
# یا: tools\build_windows.bat

# فقط اندروید
.\tools\build_android.ps1
# یا: tools\build_android.bat

# فقط iOS (فقط macOS)
bash tools/build_ios.sh
```

خروجی‌ها: `dist\windows` ، `dist\android` ، `dist\ios`  
اسکریپت ویندوز قبل از بیلد کش CMake را پاک می‌کند تا خطای درایو اشتباه تکرار نشود.

```bash
flutter pub get
dart run flutter_launcher_icons
```

### Android (APK) — دستی

```bash
flutter build apk --release
```

خروجی: `build/app/outputs/flutter-apk/app-release.apk`  
(و نام‌گذاری پروژه: `Jahan_Bit-v1.0.0(1)-release.apk`)

### iOS (IPA)

نیاز به macOS / Xcode، یا از GitHub Actions روی `master`:

```bash
flutter build ios --release --no-codesign
bash tools/package_ipa.sh
```

خروجی: `Jahan_Bit-<version>.ipa`  
CI: `.github/workflows/ios-ipa.yml` → Release / Artifact

### Windows — دستی

از ریشهٔ همین پروژه بسازید (بین `windows` و `--release` فاصله بگذارید):

```powershell
cd D:\production\internet_management_j_bit\Internet-Management

# اگر خطای CMake دربارهٔ X: دیدید، کش قدیمی را پاک کنید:
Remove-Item -Recurse -Force .\build\windows -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .\windows\flutter\ephemeral -ErrorAction SilentlyContinue

flutter pub get
flutter build windows --release
```

خروجی داخل پروژه:  
`D:\production\internet_management_j_bit\Internet-Management\build\windows\x64\runner\Release\Jahan_Bit.exe`  
(+ DLLهای کنارش در همان پوشه)

نصب‌کننده: `Jahan_Bit.iss` → `dist\installer\Jahan_Bit-Setup.exe`
