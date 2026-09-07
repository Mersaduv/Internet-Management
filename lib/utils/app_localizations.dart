import 'package:flutter/material.dart';

/// 应用国际化翻译类
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // 语言相关
  String get language =>
      locale.languageCode == 'en' ? 'Language' : 'زبان برنامه';
  String get persian => locale.languageCode == 'en' ? 'Persian' : 'فارسی';
  String get english => locale.languageCode == 'en' ? 'English' : 'انگلیسی';
  String get languageChanged => locale.languageCode == 'en'
      ? 'Language changed successfully'
      : 'زبان با موفقیت تغییر یافت';
  String get languageChangeError => locale.languageCode == 'en'
      ? 'Error changing language'
      : 'خطا در تغییر زبان';

  // 应用标题
  String get appTitle =>
      locale.languageCode == 'en' ? 'Jahan Bit' : 'جهان بیت';

  // 设置页面
  String get settings => locale.languageCode == 'en' ? 'Settings' : 'تنظیمات';
  String get appSettings =>
      locale.languageCode == 'en' ? 'App Settings' : 'تنظیمات برنامه';
  String get connectionSettings =>
      locale.languageCode == 'en' ? 'Connection Settings' : 'تنظیمات اتصال';
  String get darkMode => locale.languageCode == 'en' ? 'Theme Mode' : 'حالت تم';
  String get dark => locale.languageCode == 'en' ? 'Dark' : 'تاریک';
  String get light => locale.languageCode == 'en' ? 'Light' : 'روشن';
  String get system => locale.languageCode == 'en' ? 'System' : 'سیستم';
  String get lightMode =>
      locale.languageCode == 'en' ? 'Light Mode' : 'حالت روشن';
  String get darkModeText =>
      locale.languageCode == 'en' ? 'Dark Mode' : 'حالت تاریک';
  String get followSystem =>
      locale.languageCode == 'en' ? 'Follow System' : 'پیروی از سیستم';
  String get logout => locale.languageCode == 'en' ? 'Logout' : 'خروج از حساب';
  String get logoutMessage => locale.languageCode == 'en'
      ? 'Logout from account'
      : 'خروج از حساب کاربری';
  String get logoutConfirm => locale.languageCode == 'en'
      ? 'Are you sure you want to logout from your account?'
      : 'آیا مطمئن هستید که می‌خواهید از حساب کاربری خارج شوید؟';
  String get cancel => locale.languageCode == 'en' ? 'Cancel' : 'لغو';

  // 连接设置
  String get mikrotikRouterOS => locale.languageCode == 'en'
      ? 'MikroTik RouterOS Settings'
      : 'تنظیمات MikroTik RouterOS';
  String get ipAddressOrHostname => locale.languageCode == 'en'
      ? 'IP Address or Hostname'
      : 'آدرس IP یا Hostname';
  String get port => locale.languageCode == 'en' ? 'Port' : 'پورت';
  String get ssl => locale.languageCode == 'en' ? 'SSL' : 'SSL';
  String get saveSettings =>
      locale.languageCode == 'en' ? 'Save Settings' : 'ذخیره تنظیمات';
  String get saving =>
      locale.languageCode == 'en' ? 'Saving...' : 'در حال ذخیره...';
  String get settingsSaved => locale.languageCode == 'en'
      ? 'Settings saved successfully'
      : 'تنظیمات با موفقیت ذخیره شد';
  String get settingsSaveError => locale.languageCode == 'en'
      ? 'Error saving settings'
      : 'خطا در ذخیره تنظیمات';
  String get resetToDefaults =>
      locale.languageCode == 'en' ? 'Reset to Defaults' : 'بازنشانی به پیش‌فرض';
  String get resetSettingsConfirm => locale.languageCode == 'en'
      ? 'Are you sure you want to reset settings to default values?'
      : 'آیا مطمئن هستید که می‌خواهید تنظیمات را به حالت پیش‌فرض بازگردانید؟';
  String get reset => locale.languageCode == 'en' ? 'Reset' : 'بازنشانی';
  String get settingsReset => locale.languageCode == 'en'
      ? 'Settings reset to default'
      : 'تنظیمات به حالت پیش‌فرض بازگردانده شد';
  String get pleaseEnterIP => locale.languageCode == 'en'
      ? 'Please enter IP address'
      : 'لطفاً آدرس IP را وارد کنید';
  String get pleaseEnterPort => locale.languageCode == 'en'
      ? 'Please enter port'
      : 'لطفاً پورت را وارد کنید';
  String get portRangeError => locale.languageCode == 'en'
      ? 'Port must be a number between 1 and 65535'
      : 'پورت باید عددی بین 1 تا 65535 باشد';
  String get errorLoadingSettings => locale.languageCode == 'en'
      ? 'Error loading settings'
      : 'خطا در بارگذاری تنظیمات';

  // ä¸»é¡µ
  String get home => locale.languageCode == 'en' ? 'Home' : 'خانه';
  String get internetService =>
      locale.languageCode == 'en' ? 'Internet Service' : 'سرویس انترنت';
  String get internetPackagesTitle => locale.languageCode == 'en'
      ? 'Internet Packages'
      : 'بسته‌های اینترنتی';
  String get unlimitedPackagesTab => locale.languageCode == 'en'
      ? 'Unlimited'
      : 'نامحدود';
  String get volumePackagesTab =>
      locale.languageCode == 'en' ? 'Volume' : 'حجمی';
  String get dedicatedPackagesTab =>
      locale.languageCode == 'en' ? 'Dedicated' : 'ددیکیت';
  String get unlimitedPackageBadge => locale.languageCode == 'en'
      ? 'Unlimited Package'
      : 'بسته نامحدود';
  String get volumePackageBadge =>
      locale.languageCode == 'en' ? 'Volume Package' : 'بسته حجمی';
  String get dedicatedPackageBadge => locale.languageCode == 'en'
      ? 'Dedicated Package'
      : 'بسته ددیکیت';
  String get daySpeedLabel =>
      locale.languageCode == 'en' ? 'Day speed' : 'سرعت روزانه';
  String get nightSpeedLabel =>
      locale.languageCode == 'en' ? 'Night speed' : 'سرعت شبانه';
  String get unlimitedPackagesNote => locale.languageCode == 'en'
      ? 'Note: Unlimited package speed doubles from 11 PM to 7 AM.'
      : 'نوت: سرعت بسته‌های نامحدود از ساعت ۱۱ شب تا ۷ صبح دو برابر می‌باشد.';
  String get volumePackagesNote => locale.languageCode == 'en'
      ? 'Note: Usage is free from 12 AM to 8 AM.'
      : 'نوت: استفاده از این بسته‌ها از ساعت ۱۲ شب تا ۸ صبح رایگان می‌باشد.';
  String durationMonthsLabel(int months) {
    if (locale.languageCode == 'en') {
      if (months == 12) return '1 Year';
      if (months == 1) return '1 Month';
      return '$months Months';
    }
    switch (months) {
      case 1:
        return 'یک ماه';
      case 2:
        return 'دو ماه';
      case 3:
        return 'سه ماه';
      case 6:
        return 'شش ماه';
      case 12:
        return 'یک سال';
      default:
        return '$months ماه';
    }
  }
  String get wifiInfo =>
      locale.languageCode == 'en' ? 'WiFi Information' : 'اطلاعات Wifi';
  String get wifiInfoSubtitle => locale.languageCode == 'en'
      ? 'View WiFi info and change WiFi name and password'
      : 'نمایش اطلاعات وایفای و تغییر نام و رمز وایفای';
  String get wifiSettings =>
      locale.languageCode == 'en' ? 'WiFi Settings' : 'تنظیمات وایفای';
  String get wifiSettingsSubtitle => locale.languageCode == 'en'
      ? 'Change network name and password'
      : 'تغییر نام و رمز شبکه';
  String get wifiNameLabel => locale.languageCode == 'en'
      ? 'Network Name (SSID)'
      : 'نام شبکه (SSID)';
  String get wifiPasswordLabel =>
      locale.languageCode == 'en' ? 'Password' : 'رمز عبور';
  String get wifiPasswordHint => locale.languageCode == 'en'
      ? 'New password'
      : 'رمز عبور جدید';
  String get wifiHideSsid => locale.languageCode == 'en'
      ? 'Hide Network Name'
      : 'مخفی کردن نام شبکه';
  String get wifiHideSsidSubtitle => locale.languageCode == 'en'
      ? 'Devices will not see the network name'
      : 'دستگاه‌ها نام شبکه را نمی‌بینند';
  String get wifiSave =>
      locale.languageCode == 'en' ? 'Save Changes' : 'ذخیره تغییرات';
  String get wifiSaveConfirmTitle => locale.languageCode == 'en'
      ? 'Save WiFi Settings'
      : 'ذخیره تنظیمات وایفای';
  String get wifiSaveConfirmBody => locale.languageCode == 'en'
      ? 'WiFi connection may drop briefly. Continue?'
      : 'ممکن است اتصال وایفای چند ثانیه قطع شود. ادامه می‌دهید؟';
  String get wifiSaveSuccess => locale.languageCode == 'en'
      ? 'WiFi settings saved successfully'
      : 'تنظیمات وایفای با موفقیت ذخیره شد';
  String get wifiSaveSuccessTitle => locale.languageCode == 'en'
      ? 'Saved successfully'
      : 'اطلاعات با موفقیت ذخیره شد';
  String get wifiSaveSuccessReconnectBody => locale.languageCode == 'en'
      ? 'To use the app again, please close the application, '
          'reconnect to your WiFi network, then open the app again.'
      : 'برای استفاده مجدد لطفاً برنامه را بسته نمایید، '
          'دوباره به وایفای خود متصل شوید، '
          'مجدداً برنامه را باز کنید.';
  String get wifiCloseApp =>
      locale.languageCode == 'en' ? 'Close app' : 'بستن برنامه';
  String get wifiBackWithoutClose => locale.languageCode == 'en'
      ? 'Back without closing'
      : 'بازگشت بدون بستن';
  String get wifiSaveSuccessOk =>
      locale.languageCode == 'en' ? 'Got it' : 'متوجه شدم';
  String get wifiNoInterface => locale.languageCode == 'en'
      ? 'No wireless interface found'
      : 'رابط وایرلس یافت نشد';
  String get wifiLoading => locale.languageCode == 'en'
      ? 'Loading WiFi settings...'
      : 'در حال خواندن تنظیمات وایفای...';
  String get wifiSharedProfileWarning => locale.languageCode == 'en'
      ? 'Password changes apply to the shared security profile and may affect other wireless interfaces.'
      : 'تغییر رمز عبور روی پروفایل امنیتی مشترک اعمال می‌شود و ممکن است روی سایر رابط‌های وایرلس هم تأثیر بگذارد.';
  String get wifiConnectionLost => locale.languageCode == 'en'
      ? 'Connection to router was lost'
      : 'اتصال به روتر قطع شده است';
  String get wifiReconnect =>
      locale.languageCode == 'en' ? 'Reconnect' : 'اتصال مجدد';
  String get wifiInterfaceLabel =>
      locale.languageCode == 'en' ? 'Wireless interface' : 'رابط وایرلس';
  String get connectedDevices =>
      locale.languageCode == 'en' ? 'Connected Devices' : 'دستگاه‌های متصل';
  String get bannedDevices =>
      locale.languageCode == 'en' ? 'Banned Devices' : 'دستگاه‌های مسدود';
  String get you => locale.languageCode == 'en' ? 'You' : 'شما';
  String get user => locale.languageCode == 'en' ? 'User' : 'کاربر';
  String get yourDeviceIP =>
      locale.languageCode == 'en' ? 'Your Device IP' : 'IP دستگاه شما';
  String get noConnectedDevices => locale.languageCode == 'en'
      ? 'No connected devices found'
      : 'هیچ دستگاه متصلی یافت نشد';
  String get noBannedDevices => locale.languageCode == 'en'
      ? 'No banned devices found'
      : 'هیچ دستگاه مسدود شده‌ای یافت نشد';
  String get retry => locale.languageCode == 'en' ? 'Retry' : 'تلاش مجدد';
  String get unknownDevice =>
      locale.languageCode == 'en' ? 'Unknown Device' : 'دستگاه ناشناس';
  String get device => locale.languageCode == 'en' ? 'Device' : 'دستگاه';
  String get lockNewConnections =>
      locale.languageCode == 'en' ? 'Lock New Connections' : 'قفل اتصال جدید';
  String get lockNewConnectionsActive => locale.languageCode == 'en'
      ? 'Lock New Connections (Active)'
      : 'قفل اتصال جدید (فعال)';
  String get lockNewConnectionsEnabled => locale.languageCode == 'en'
      ? 'New connections locked'
      : 'قفل اتصال جدید فعال شد';
  String get lockNewConnectionsDisabled => locale.languageCode == 'en'
      ? 'New connections unlocked'
      : 'قفل اتصال جدید غیرفعال شد';
  String get lockStatusError => locale.languageCode == 'en'
      ? 'Error changing lock status'
      : 'خطا در تغییر وضعیت قفل';

  // 设备相关
  String get static => locale.languageCode == 'en' ? 'Static' : 'Static';
  String get pending => locale.languageCode == 'en' ? 'Pending' : 'Pending';
  String get pendingApproval =>
      locale.languageCode == 'en' ? 'Pending Approval' : 'در انتظار تایید';
  String get approve => locale.languageCode == 'en' ? 'Approve' : 'تایید';
  String get reject => locale.languageCode == 'en' ? 'Reject' : 'رد';
  String get deviceApproved =>
      locale.languageCode == 'en' ? 'Device approved' : 'دستگاه تایید شد';
  String get deviceRejected =>
      locale.languageCode == 'en' ? 'Device rejected' : 'دستگاه رد و مسدود شد';
  String get approveError => locale.languageCode == 'en'
      ? 'Error approving device'
      : 'خطا در تایید دستگاه';
  String get rejectError => locale.languageCode == 'en'
      ? 'Error rejecting device'
      : 'خطا در رد دستگاه';
  String get banned => locale.languageCode == 'en' ? 'Banned' : 'مسدود';
  String get bannedDevice =>
      locale.languageCode == 'en' ? 'Banned Device' : 'دستگاه مسدود شده';
  String get unbanDevice =>
      locale.languageCode == 'en' ? 'Unban Device' : 'رفع مسدودیت دستگاه';
  String get unbanDeviceConfirm => locale.languageCode == 'en'
      ? 'Are you sure you want to unban device {ip}?'
      : 'آیا مطمئن هستید که می‌خواهید مسدودیت دستگاه {ip} را بردارید؟';
  String get unban => locale.languageCode == 'en' ? 'Unban' : 'رفع مسدودیت';
  String get deviceUnbanned => locale.languageCode == 'en'
      ? 'Device unbanned successfully'
      : 'مسدودیت دستگاه با موفقیت برداشته شد';
  String get unbanError => locale.languageCode == 'en'
      ? 'Error unbanning device'
      : 'مسدود خودکار (قفل اتصال جدید)';
  String get manualBanned =>
      locale.languageCode == 'en' ? 'Manual Ban' : 'مسدود دستی';

  // 设备类型
  String get wireless => locale.languageCode == 'en' ? 'Wireless' : 'Wireless';
  String get dhcp => locale.languageCode == 'en' ? 'DHCP' : 'DHCP';
  String get hotspot => locale.languageCode == 'en' ? 'Hotspot' : 'Hotspot';
  String get ppp => locale.languageCode == 'en' ? 'PPP' : 'PPP';
  String get unknown => locale.languageCode == 'en' ? 'Unknown' : 'نامشخص';
  String get download => locale.languageCode == 'en' ? 'Download' : 'دانلود';
  String get upload => locale.languageCode == 'en' ? 'Upload' : 'آپلود';
  String get maximum => locale.languageCode == 'en' ? 'Maximum' : 'حداکثر';
  // 通用
  String get loading =>
      locale.languageCode == 'en' ? 'Loading...' : 'در حال بارگذاری...';
  String get error => locale.languageCode == 'en' ? 'Error' : 'خطا';
  String get success => locale.languageCode == 'en' ? 'Success' : 'موفقیت';
  String get ok => locale.languageCode == 'en' ? 'OK' : 'تایید';
  String get yes => locale.languageCode == 'en' ? 'Yes' : 'بله';
  String get no => locale.languageCode == 'en' ? 'No' : 'خیر';
  String get refresh => locale.languageCode == 'en' ? 'Refresh' : 'به‌روزرسانی';
  String get close => locale.languageCode == 'en' ? 'Close' : 'بستن';
  String get delete => locale.languageCode == 'en' ? 'Delete' : 'حذف';
  String get edit => locale.languageCode == 'en' ? 'Edit' : 'ویرایش';
  String get save => locale.languageCode == 'en' ? 'Save' : 'ذخیره';
  String get search => locale.languageCode == 'en' ? 'Search' : 'جستجو';
  String get filter => locale.languageCode == 'en' ? 'Filter' : 'فیلتر';
  String get clear => locale.languageCode == 'en' ? 'Clear' : 'پاک کردن';
  String get select => locale.languageCode == 'en' ? 'Select' : 'انتخاب';
  String get selected =>
      locale.languageCode == 'en' ? 'Selected' : 'انتخاب شده';
  String get all => locale.languageCode == 'en' ? 'All' : 'همه';
  String get none => locale.languageCode == 'en' ? 'None' : 'هیچکدام';

  // 辅助方法

  String unbanDeviceConfirmWithIP(String ip) {
    return unbanDeviceConfirm.replaceAll('{ip}', ip);
  }

  // 登录页面
  String get pleaseEnterRouterInfo => locale.languageCode == 'en'
      ? 'Please enter your information'
      : 'لطفاً اطلاعات خود را وارد کنید';
  String get username =>
      locale.languageCode == 'en' ? 'Username' : 'نام کاربری';
  String get password => locale.languageCode == 'en' ? 'Password' : 'رمز عبور';
  String get pleaseEnterUsername => locale.languageCode == 'en'
      ? 'Please enter username'
      : 'لطفاً نام کاربری را وارد کنید';
  String get pleaseEnterPassword => locale.languageCode == 'en'
      ? 'Please enter password'
      : 'لطفاً رمز عبور را وارد کنید';
  String get login => locale.languageCode == 'en' ? 'Login' : 'ورود';
  String get rememberMe =>
      locale.languageCode == 'en' ? 'Remember me' : 'مرا به خاطر بسپار';
  String get enterPassword => locale.languageCode == 'en'
      ? 'Enter your password'
      : 'رمز عبور خود را وارد کنید';
  String get invalidUsernameOrPassword => locale.languageCode == 'en'
      ? 'Invalid username or password'
      : 'نام کاربری یا رمز عبور نامعتبر است';
  String get loginFailed => locale.languageCode == 'en'
      ? 'Login failed. Please check your credentials.'
      : 'ورود ناموفق بود. لطفاً اطلاعات ورود خود را بررسی کنید.';

  // 设备详情页面
  String get deviceDetails =>
      locale.languageCode == 'en' ? 'Device Details' : 'جزئیات دستگاه';
  String get deviceName =>
      locale.languageCode == 'en' ? 'Device Name' : 'نام دستگاه';
  String get deviceNameHint =>
      locale.languageCode == 'en' ? 'Example: Office PC' : 'مثال: Office PC';
  String get deviceNameHelper => locale.languageCode == 'en'
      ? 'This name is saved as DHCP lease comment and will be shown in the app.'
      : 'این نام در comment مربوط به DHCP lease ذخیره می‌شود و از این به بعد در برنامه نمایش داده می‌شود.';
  String get dhcpLeaseComment => locale.languageCode == 'en'
      ? 'Comment for DHCP Lease'
      : 'Comment برای DHCP Lease';
  String get deviceNameSaved =>
      locale.languageCode == 'en' ? 'Device name saved' : 'نام دستگاه ذخیره شد';
  String get deviceNameSaveError => locale.languageCode == 'en'
      ? 'Error saving device name'
      : 'خطا در ذخیره نام دستگاه';
  String get deviceNameRequired => locale.languageCode == 'en'
      ? 'Please enter a device name'
      : 'لطفاً نام دستگاه را وارد کنید';
  String get deviceInformation =>
      locale.languageCode == 'en' ? 'Device Information' : 'اطلاعات دستگاه';
  String get operations =>
      locale.languageCode == 'en' ? 'Operations' : 'عملیات';
  String get type => locale.languageCode == 'en' ? 'Type' : 'نوع';
  String get ipAddress =>
      locale.languageCode == 'en' ? 'IP Address' : 'آدرس IP';
  String get macAddress =>
      locale.languageCode == 'en' ? 'MAC Address' : 'آدرس MAC';
  String get hostname =>
      locale.languageCode == 'en' ? 'Hostname' : 'نام میزبان';
  String get connectionTime =>
      locale.languageCode == 'en' ? 'Connection Time' : 'زمان اتصال';
  String get signalStrength =>
      locale.languageCode == 'en' ? 'Signal Strength' : 'قدرت سیگنال';
  String get speedLimit =>
      locale.languageCode == 'en' ? 'Speed Limit' : 'محدودیت سرعت';
  String get setSpeedLimit =>
      locale.languageCode == 'en' ? 'Set Speed Limit' : 'تنظیم سرعت';
  String get downloadSpeed =>
      locale.languageCode == 'en' ? 'Download Speed' : 'سرعت دانلود';
  String get uploadSpeed =>
      locale.languageCode == 'en' ? 'Upload Speed' : 'سرعت آپلود';
  String get liveTraffic =>
      locale.languageCode == 'en' ? 'Live Traffic' : 'ترافیک لحظه‌ای';
  String get value => locale.languageCode == 'en' ? 'Value' : 'مقدار';
  String get unit => locale.languageCode == 'en' ? 'Unit' : 'واحد';
  String get pleaseEnterNumber => locale.languageCode == 'en'
      ? 'Please enter a number'
      : 'لطفاً عدد را وارد کنید';
  String get numberMustBeGreaterThanZero => locale.languageCode == 'en'
      ? 'Number must be greater than zero'
      : 'عدد باید بزرگتر از صفر باشد';
  String get unitGuide =>
      locale.languageCode == 'en' ? 'Unit Guide:' : 'راهنمای واحدها:';
  String get unitGuideText => locale.languageCode == 'en'
      ? '• Mbps = Megabits per second\n• Kbps = Kilobits per second'
      : '• Mbps = مگابیت بر ثانیه\n• Kbps = کیلوبیت بر ثانیه';
  String get speedSetSuccessfully => locale.languageCode == 'en'
      ? 'Speed limit set successfully: {speed}'
      : 'سرعت با موفقیت تنظیم شد: {speed}';
  String get speedSetTimeout => locale.languageCode == 'en'
      ? 'Speed limit setting timeout'
      : 'زمان تنظیم سرعت به پایان رسید';
  String get errorSettingSpeed => locale.languageCode == 'en'
      ? 'Error setting speed limit'
      : 'خطا در تنظیم سرعت';
  String get banDevice =>
      locale.languageCode == 'en' ? 'Ban Device' : 'مسدود کردن';
  String get banDeviceConfirm => locale.languageCode == 'en'
      ? 'Are you sure you want to ban device {ip}?'
      : 'آیا مطمئن هستید که می‌خواهید دستگاه {ip} را مسدود کنید؟';
  String get cannotBanCurrentDevice => locale.languageCode == 'en'
      ? 'You cannot ban the current device you are using.'
      : 'امکان مسدود کردن دستگاهی که با آن وارد برنامه شده‌اید وجود ندارد.';
  String get deviceNotConnected => locale.languageCode == 'en'
      ? 'The device is not currently connected. Please check the device connection first.'
      : 'دستگاه مورد نظر در حال حاضر متصل نیست. لطفاً ابتدا اتصال دستگاه را بررسی کنید.';
  String get connectionNotEstablished => locale.languageCode == 'en'
      ? 'Connection not established'
      : 'اتصال برقرار نشده';
  String get thisDeviceIsBanned => locale.languageCode == 'en'
      ? 'This device is banned'
      : 'این دستگاه مسدود شده است';
  String get deviceWithIP =>
      locale.languageCode == 'en' ? 'Device {ip}' : 'دستگاه {ip}';
  String get deviceWithMAC =>
      locale.languageCode == 'en' ? 'Device {mac}' : 'دستگاه {mac}';
  String get unknownDeviceText =>
      locale.languageCode == 'en' ? 'Unknown Device' : 'دستگاه ناشناس';
  String get bannedDeviceText =>
      locale.languageCode == 'en' ? 'Banned Device' : 'دستگاه مسدود شده';
  String get unbanDeviceTooltip =>
      locale.languageCode == 'en' ? 'Unban Device' : 'رفع مسدودیت';
  String get unbanDeviceTitle =>
      locale.languageCode == 'en' ? 'Unban Device' : 'رفع مسدودیت دستگاه';
  String get unbanDeviceConfirmText => locale.languageCode == 'en'
      ? 'Are you sure you want to unban device {ip}?'
      : 'آیا مطمئن هستید که می‌خواهید مسدودیت دستگاه {ip} را بردارید؟';
  String get deviceUnbannedSuccess => locale.languageCode == 'en'
      ? 'Device unbanned successfully'
      : 'مسدودیت دستگاه با موفقیت برداشته شد';
  String get errorUnbanning => locale.languageCode == 'en'
      ? 'Error unbanning device'
      : 'خطا در رفع مسدودیت';
  String get deviceBannedSuccess => locale.languageCode == 'en'
      ? 'Device banned successfully'
      : 'دستگاه با موفقیت مسدود شد';
  String get errorBanningDevice => locale.languageCode == 'en'
      ? 'Error banning device'
      : 'خطا در مسدود کردن دستگاه';
  String get retryText => locale.languageCode == 'en' ? 'Retry' : 'تلاش مجدد';
  String get noConnectedDevicesText => locale.languageCode == 'en'
      ? 'No connected devices found'
      : 'هیچ دستگاه متصلی یافت نشد';
  String get noBannedDevicesText => locale.languageCode == 'en'
      ? 'No banned devices found'
      : 'هیچ دستگاه مسدود شده‌ای یافت نشد';

  // 辅助方法
  String speedSetSuccessfullyWithSpeed(String speed) {
    return speedSetSuccessfully.replaceAll('{speed}', speed);
  }

  String deviceWithIPText(String ip) {
    return deviceWithIP.replaceAll('{ip}', ip);
  }

  String deviceWithMACText(String mac) {
    return deviceWithMAC.replaceAll('{mac}', mac);
  }

  String unbanDeviceConfirmTextWithIP(String ip) {
    return unbanDeviceConfirmText.replaceAll('{ip}', ip);
  }

  String banDeviceConfirmWithIP(String ip) {
    return banDeviceConfirm.replaceAll('{ip}', ip);
  }

  // MikroTik Service 错误消息
  String get connectionError =>
      locale.languageCode == 'en' ? 'Connection error' : 'خطا در اتصال';
  String get connectionNotEstablishedError => locale.languageCode == 'en'
      ? 'Connection not established'
      : 'اتصال برقرار نشده';
  String get deviceIpRequired => locale.languageCode == 'en'
      ? 'Device IP address is required'
      : 'آدرس IP دستگاه الزامی است';
  String get invalidPlatform => locale.languageCode == 'en'
      ? 'Invalid platform: {platform}'
      : 'پلتفرم نامعتبر: {platform}';
  String get queueEditError => locale.languageCode == 'en'
      ? 'Error editing queue: {error}'
      : 'خطا در ویرایش queue: {error}';
  String get queueCreateError => locale.languageCode == 'en'
      ? 'Error creating queue: {error}'
      : 'خطا در ایجاد queue: {error}';
  String get speedSettingError => locale.languageCode == 'en'
      ? 'Error setting speed: {error}'
      : 'خطا در تنظیم سرعت: {error}';
  String get timeoutError =>
      locale.languageCode == 'en' ? 'Timeout error' : 'خطای زمان‌بندی';
  String get queueEditTimeout => locale.languageCode == 'en'
      ? 'Timeout editing queue'
      : 'Timeout در ویرایش queue';
  String get queueCreateTimeout => locale.languageCode == 'en'
      ? 'Timeout creating queue'
      : 'Timeout در ایجاد queue';
  // 辅助方法
  String invalidPlatformWithPlatform(String platform) {
    return invalidPlatform.replaceAll('{platform}', platform);
  }

  String queueEditErrorWithError(String error) {
    return queueEditError.replaceAll('{error}', error);
  }

  String queueCreateErrorWithError(String error) {
    return queueCreateError.replaceAll('{error}', error);
  }

  String speedSettingErrorWithError(String error) {
    return speedSettingError.replaceAll('{error}', error);
  }

  /// 将服务层的消息转换为本地化消息（包括成功和错误消息）
  String localizeServiceMessage(String message) {
    // 检查是否是服务层返回的硬编码消息
    // 如果不是已知消息，尝试作为错误消息处理
    return localizeServiceError(message);
  }

  /// 将服务层的错误消息转换为本地化消息
  String localizeServiceError(String errorMessage) {
    if (errorMessage.contains('خطا در فرمان صف:') ||
        errorMessage.contains('Timeout در فرمان صف:')) {
      return errorMessage;
    }
    if (errorMessage.contains('خطا در اتصال') ||
        errorMessage.contains('Connection error')) {
      return connectionError;
    }
    if (errorMessage.contains('اتصال برقرار نشده') ||
        errorMessage.contains('Connection not established')) {
      return connectionNotEstablishedError;
    }
    if (errorMessage.contains('آدرس IP دستگاه الزامی است') ||
        errorMessage.contains('Device IP address is required')) {
      return deviceIpRequired;
    }
    if (errorMessage.contains('پلتفرم نامعتبر') ||
        errorMessage.contains('Invalid platform')) {
      final match = RegExp(
        r'پلتفرم نامعتبر:\s*(.+)|Invalid platform:\s*(.+)',
      ).firstMatch(errorMessage);
      if (match != null) {
        final platform = match.group(1) ?? match.group(2) ?? '';
        return invalidPlatformWithPlatform(platform);
      }
      return invalidPlatformWithPlatform('');
    }
    if (errorMessage.contains('خطا در ویرایش queue') ||
        errorMessage.contains('Error editing queue')) {
      final match = RegExp(
        r'خطا در ویرایش queue:\s*(.+)|Error editing queue:\s*(.+)',
      ).firstMatch(errorMessage);
      if (match != null) {
        final error = match.group(1) ?? match.group(2) ?? '';
        return queueEditErrorWithError(error);
      }
      return queueEditErrorWithError('');
    }
    if (errorMessage.contains('خطا در ایجاد queue') ||
        errorMessage.contains('Error creating queue')) {
      final match = RegExp(
        r'خطا در ایجاد queue:\s*(.+)|Error creating queue:\s*(.+)',
      ).firstMatch(errorMessage);
      if (match != null) {
        final error = match.group(1) ?? match.group(2) ?? '';
        return queueCreateErrorWithError(error);
      }
      return queueCreateErrorWithError('');
    }
    if (errorMessage.contains('خطا در تنظیم سرعت') ||
        errorMessage.contains('Error setting speed')) {
      final match = RegExp(
        r'خطا در تنظیم سرعت:\s*(.+)|Error setting speed:\s*(.+)',
      ).firstMatch(errorMessage);
      if (match != null) {
        final error = match.group(1) ?? match.group(2) ?? '';
        return speedSettingErrorWithError(error);
      }
      return speedSettingErrorWithError('');
    }
    if (errorMessage.contains('Timeout') || errorMessage.contains('timeout')) {
      if (errorMessage.contains('ویرایش queue') ||
          errorMessage.contains('editing queue')) {
        return queueEditTimeout;
      }
      if (errorMessage.contains('ایجاد queue') ||
          errorMessage.contains('creating queue')) {
        return queueCreateTimeout;
      }
      return timeoutError;
    }
    // 如果无法匹配，返回原始消息
    return errorMessage;
  }

  // راهنمای مشترکین
  String get subscriberHelp =>
      locale.languageCode == 'en' ? 'Subscriber Guide' : 'راهنمایی مشترکین';
  String get subscriberHelpSettingsSubtitle => locale.languageCode == 'en'
      ? 'Learn devices, Wi‑Fi, and service step by step'
      : 'آموزش مدیریت دستگاه، وای‌فای و سرویس';
  String get phoneCopied =>
      locale.languageCode == 'en' ? 'Phone number copied' : 'شماره کپی شد';
  String get subscriberHelpIntroTitle => locale.languageCode == 'en'
      ? 'Simple guide to using the app'
      : 'راهنمای ساده استفاده از برنامه';
  String get subscriberHelpIntroBody => locale.languageCode == 'en'
      ? 'Read each section in order. Every button shows the same icon used in the app so you can quickly find what it does and where it is.'
      : 'هر بخش را به‌ترتیب بخوانید. کنار هر دکمه، آیکون همان دکمه در برنامه نشان داده شده تا سریع پیدا کنید چه کاری انجام می‌دهد و از کجا باز می‌شود.';

  String get helpDevicesSectionTitle => locale.languageCode == 'en'
      ? 'Manage devices (Home)'
      : 'مدیریت دستگاه‌ها (صفحه خانه)';
  String get helpDevicesSectionSubtitle => locale.languageCode == 'en'
      ? 'Priority 1 — see and control devices on your network'
      : 'اولویت اول — دیدن و کنترل دستگاه‌های وصل‌شده به شبکه';
  String get helpDevicesWhere => locale.languageCode == 'en'
      ? 'Where: bottom bar → Home icon'
      : 'از کجا: نوار پایین → آیکون خانه';
  String get helpOpenHome =>
      locale.languageCode == 'en' ? 'Go to Home' : 'رفتن به صفحه خانه';
  String get helpDevActHomeTitle =>
      locale.languageCode == 'en' ? 'Home icon' : 'آیکون خانه';
  String get helpDevActHomeDetail => locale.languageCode == 'en'
      ? 'In the bottom bar, tap the first icon (Home) to open the main page.'
      : 'در نوار پایین برنامه، اولین آیکون (خانه) را بزنید تا صفحه اصلی باز شود.';
  String get helpDevActRouterTitle => locale.languageCode == 'en'
      ? 'Router info (top of page)'
      : 'اطلاعات روتر (بالای صفحه)';
  String get helpDevActRouterDetail => locale.languageCode == 'en'
      ? 'At the top you see router name and user. Info only — not a button.'
      : 'بالای صفحه نام روتر و کاربر را می‌بینید. فقط برای اطلاع است؛ دکمه‌ای برای فشار دادن نیست.';
  String get helpDevActLockTitle => locale.languageCode == 'en'
      ? 'Lock new connections button'
      : 'دکمه قفل اتصال جدید';
  String get helpDevActLockDetail => locale.languageCode == 'en'
      ? 'Below router info. When on, new devices are restricted. Tap again to unlock.'
      : 'این دکمه زیر اطلاعات روتر است. اگر روشن باشد، دستگاه‌های تازه‌وارد محدود می‌شوند. دوباره بزنید تا باز شود.';
  String get helpDevActConnectedTitle =>
      locale.languageCode == 'en' ? '“Connected” tab' : 'زبانه «متصل»';
  String get helpDevActConnectedDetail => locale.languageCode == 'en'
      ? 'Devices icon — lists phones and laptops currently on the network.'
      : 'آیکون چند دستگاه — فهرست گوشی‌ها و لپ‌تاپ‌هایی که الان به شبکه وصل‌اند را نشان می‌دهد.';
  String get helpDevActBannedTitle =>
      locale.languageCode == 'en' ? '“Banned” tab' : 'زبانه «مسدود»';
  String get helpDevActBannedDetail => locale.languageCode == 'en'
      ? 'Blocked-circle icon — devices you previously banned are here.'
      : 'آیکون دایره با خط — دستگاه‌هایی که قبلاً مسدود کرده‌اید اینجاست.';
  String get helpDevActRefreshTitle => locale.languageCode == 'en'
      ? 'Pull down to refresh'
      : 'کشیدن صفحه به پایین';
  String get helpDevActRefreshDetail => locale.languageCode == 'en'
      ? 'Pull the list down to refresh and see newly joined devices.'
      : 'لیست را با انگشت به پایین بکشید تا تازه‌سازی شود و دستگاه‌های جدید دیده شوند.';
  String get helpDevActTapTitle => locale.languageCode == 'en'
      ? 'Tap a device'
      : 'لمس روی یک دستگاه';
  String get helpDevActTapDetail => locale.languageCode == 'en'
      ? 'Tap a device row to open details (speed limit, ban, and more).'
      : 'روی نام یا ردیف دستگاه بزنید تا صفحه جزئیات باز شود (سرعت، مسدودسازی و …).';
  String get helpDevActSpeedTitle =>
      locale.languageCode == 'en' ? 'Limit speed' : 'محدود کردن سرعت';
  String get helpDevActSpeedDetail => locale.languageCode == 'en'
      ? 'On the device page, set download/upload speed and save.'
      : 'داخل صفحه دستگاه، سرعت دانلود/آپلود را تنظیم و ذخیره کنید.';
  String get helpDevActBanTitle =>
      locale.languageCode == 'en' ? 'Ban a device' : 'مسدود کردن دستگاه';
  String get helpDevActBanDetail => locale.languageCode == 'en'
      ? 'On the same details page, ban the device so it moves to the Banned tab.'
      : 'در همان صفحه جزئیات، گزینه مسدودسازی را بزنید تا دستگاه از اینترنت قطع شود و به زبانه «مسدود» برود.';
  String get helpDevActUnbanTitle =>
      locale.languageCode == 'en' ? 'Unban' : 'رفع مسدودیت';
  String get helpDevActUnbanDetail => locale.languageCode == 'en'
      ? 'In the Banned tab, tap the unlock icon next to a device to free it.'
      : 'در زبانه «مسدود»، آیکون قفل باز کنار دستگاه را بزنید تا دوباره آزاد شود.';

  String get helpWifiSectionTitle =>
      locale.languageCode == 'en' ? 'Wi‑Fi settings' : 'تنظیمات وای‌فای';
  String get helpWifiSectionSubtitle => locale.languageCode == 'en'
      ? 'Priority 2 — change network name and Wi‑Fi password'
      : 'اولویت دوم — تغییر نام شبکه و رمز وای‌فای';
  String get helpWifiWhere => locale.languageCode == 'en'
      ? 'Where: bottom bar → Settings → WiFi Settings'
      : 'از کجا: نوار پایین → تنظیمات → تنظیمات وایفای';
  String get helpOpenWifiSettings => locale.languageCode == 'en'
      ? 'Open Wi‑Fi settings'
      : 'باز کردن تنظیمات وای‌فای';
  String get helpWifiActSettingsTitle =>
      locale.languageCode == 'en' ? 'Settings icon' : 'آیکون تنظیمات';
  String get helpWifiActSettingsDetail => locale.languageCode == 'en'
      ? 'In the bottom bar, tap the last icon (gear) to open Settings.'
      : 'در نوار پایین، آخرین آیکون (چرخ‌دنده) را بزنید تا صفحه تنظیمات باز شود.';
  String get helpWifiActItemTitle => locale.languageCode == 'en'
      ? '“WiFi Settings” item'
      : 'گزینه «تنظیمات وایفای»';
  String get helpWifiActItemDetail => locale.languageCode == 'en'
      ? 'First item in Settings. Tap it to change name and password.'
      : 'اولین گزینه در لیست تنظیمات است. روی آن بزنید تا صفحه تغییر نام و رمز باز شود.';
  String get helpWifiActSsidTitle =>
      locale.languageCode == 'en' ? 'Network name (SSID)' : 'نام شبکه (SSID)';
  String get helpWifiActSsidDetail => locale.languageCode == 'en'
      ? 'The name phones see in Wi‑Fi lists. You can change it.'
      : 'نامی که گوشی‌ها در لیست وای‌فای می‌بینند. می‌توانید عوض کنید.';
  String get helpWifiActPassTitle =>
      locale.languageCode == 'en' ? 'Password' : 'رمز عبور';
  String get helpWifiActPassDetail => locale.languageCode == 'en'
      ? 'Enter a new password. Usually at least 8 characters.'
      : 'رمز جدید را وارد کنید. معمولاً حداقل ۸ کاراکتر لازم است.';
  String get helpWifiActHideTitle => locale.languageCode == 'en'
      ? 'Hide network name'
      : 'مخفی کردن نام شبکه';
  String get helpWifiActHideDetail => locale.languageCode == 'en'
      ? 'If on, the network name is hidden from Wi‑Fi lists (optional).'
      : 'اگر روشن باشد، نام شبکه در لیست وای‌فای دیده نمی‌شود (اختیاری).';
  String get helpWifiActSaveTitle =>
      locale.languageCode == 'en' ? 'Save button' : 'دکمه ذخیره';
  String get helpWifiActSaveDetail => locale.languageCode == 'en'
      ? 'After filling fields, tap Save and wait for the success message.'
      : 'بعد از پر کردن فیلدها، ذخیره را بزنید و صبر کنید تا پیام موفقیت بیاید.';
  String get helpWifiActReconnectTitle => locale.languageCode == 'en'
      ? 'Reconnect devices'
      : 'وصل شدن دوباره دستگاه‌ها';
  String get helpWifiActReconnectDetail => locale.languageCode == 'en'
      ? 'After changing the password, all devices must reconnect with the new password.'
      : 'بعد از تغییر رمز، همه گوشی‌ها و لپ‌تاپ‌ها باید با رمز جدید دوباره وصل شوند.';
  String get helpWifiActWebTitle => locale.languageCode == 'en'
      ? 'Some antennas (LHG / SXT / …)'
      : 'بعضی آنتن‌ها (LHG / SXT / …)';
  String get helpWifiActWebDetail => locale.languageCode == 'en'
      ? 'On some models an in-app browser opens instead of the form. Change name and password there.'
      : 'در برخی مدل‌ها به‌جای فرم، صفحه مرورگر داخلی باز می‌شود. همان‌جا نام و رمز را عوض کنید.';

  String get helpInternetSectionTitle =>
      locale.languageCode == 'en' ? 'Internet service' : 'سرویس اینترنت';
  String get helpInternetSectionSubtitle => locale.languageCode == 'en'
      ? 'Open the user panel and subscription status'
      : 'دیدن پنل کاربری و وضعیت اشتراک';
  String get helpInternetWhere => locale.languageCode == 'en'
      ? 'Where: bottom bar → globe icon'
      : 'از کجا: نوار پایین → آیکون کره زمین';
  String get helpOpenInternetService => locale.languageCode == 'en'
      ? 'Open internet service'
      : 'باز کردن سرویس اینترنت';
  String get helpNetActTabTitle => locale.languageCode == 'en'
      ? 'Internet Service icon'
      : 'آیکون سرویس انترنت';
  String get helpNetActTabDetail => locale.languageCode == 'en'
      ? 'Tap the second bottom icon (globe). The user panel opens automatically.'
      : 'دومین آیکون نوار پایین (کره) را بزنید. پنل کاربری خودکار باز می‌شود.';
  String get helpNetActLoginTitle =>
      locale.languageCode == 'en' ? 'Sign in to panel' : 'ورود به پنل';
  String get helpNetActLoginDetail => locale.languageCode == 'en'
      ? 'Sign in with your username and password to see subscription status.'
      : 'با نام کاربری و رمز اختصاصی خود وارد شوید تا وضعیت اشتراک را ببینید.';
  String get helpNetActBackTitle =>
      locale.languageCode == 'en' ? 'Back (header)' : 'دکمه بازگشت (هدر)';
  String get helpNetActBackDetail => locale.languageCode == 'en'
      ? 'Left arrow at the top — goes to the previous page inside the panel.'
      : 'آیکون فلش چپ در بالای صفحه — صفحه قبلی داخل پنل را نشان می‌دهد.';
  String get helpNetActForwardTitle =>
      locale.languageCode == 'en' ? 'Forward (header)' : 'دکمه جلو (هدر)';
  String get helpNetActForwardDetail => locale.languageCode == 'en'
      ? 'Right arrow — goes forward again if you went back.'
      : 'آیکون فلش راست — اگر قبلاً برگشته باشید، دوباره جلو می‌رود.';
  String get helpNetActReloadTitle =>
      locale.languageCode == 'en' ? 'Refresh' : 'دکمه تازه‌سازی';
  String get helpNetActReloadDetail => locale.languageCode == 'en'
      ? 'Circular arrow icon — reloads the panel page.'
      : 'آیکون دایره فلش‌دار — صفحه پنل را دوباره بارگذاری می‌کند.';
  String get helpNetActLinkTitle =>
      locale.languageCode == 'en' ? 'Change address' : 'دکمه تغییر آدرس';
  String get helpNetActLinkDetail => locale.languageCode == 'en'
      ? 'Link icon in the header — change the panel URL only if needed.'
      : 'آیکون لینک در هدر — فقط اگر لازم شد آدرس پنل را عوض کنید.';

  String get helpPackagesSectionTitle =>
      locale.languageCode == 'en' ? 'Internet packages' : 'بسته‌های اینترنتی';
  String get helpPackagesSectionSubtitle => locale.languageCode == 'en'
      ? 'Browse package types and speeds'
      : 'مشاهده انواع بسته و سرعت‌ها';
  String get helpPackagesWhere => locale.languageCode == 'en'
      ? 'Where: bottom bar → Packages icon'
      : 'از کجا: نوار پایین → آیکون بسته‌ها';
  String get helpOpenPackages =>
      locale.languageCode == 'en' ? 'Go to packages' : 'رفتن به بسته‌ها';
  String get helpPkgActTabTitle =>
      locale.languageCode == 'en' ? 'Packages icon' : 'آیکون بسته‌ها';
  String get helpPkgActTabDetail => locale.languageCode == 'en'
      ? 'Tap the third bottom icon to open the packages list.'
      : 'سومین آیکون نوار پایین را بزنید تا فهرست بسته‌ها باز شود.';
  String get helpPkgActTabsTitle =>
      locale.languageCode == 'en' ? 'Top tabs' : 'زبانه‌های بالا';
  String get helpPkgActTabsDetail => locale.languageCode == 'en'
      ? 'Switch Unlimited / Volume / Dedicated and review speed and duration.'
      : 'بین نامحدود، حجمی و ددیکیت جابه‌جا شوید و سرعت و مدت هر بسته را ببینید.';

  String get helpTipsTitle =>
      locale.languageCode == 'en' ? 'Simple tips' : 'نکات ساده';
  String get helpTip1 => locale.languageCode == 'en'
      ? 'Before using the app, connect to your router Wi‑Fi.'
      : 'قبل از کار با برنامه، به وای‌فای همان شبکه روتر وصل باشید.';
  String get helpTip2 => locale.languageCode == 'en'
      ? 'If the device list is empty, pull down to refresh or wait a moment.'
      : 'اگر لیست دستگاه‌ها خالی بود، صفحه را به پایین بکشید یا کمی صبر کنید.';
  String get helpTip3 => locale.languageCode == 'en'
      ? 'After changing the Wi‑Fi password, reconnect devices with the new password.'
      : 'بعد از عوض کردن رمز وای‌فای، دستگاه‌ها را با رمز جدید وصل کنید.';
  String get helpTip4 => locale.languageCode == 'en'
      ? 'If the service panel does not open, tap Refresh (circular arrow).'
      : 'اگر پنل سرویس باز نشد، دکمه تازه‌سازی (دایره فلش‌دار) را بزنید.';
  String get helpTip5 => locale.languageCode == 'en'
      ? 'For login issues or forgotten password, contact support.'
      : 'برای مشکل ورود یا رمز فراموش‌شده، با پشتیبانی تماس بگیرید.';
  String get helpSupportTitle =>
      locale.languageCode == 'en' ? 'Contact support' : 'تماس با پشتیبانی';
  String get helpSupportSubtitle => locale.languageCode == 'en'
      ? 'Tap a number to copy it'
      : 'برای کپی شماره، روی آن ضربه بزنید';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fa'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
