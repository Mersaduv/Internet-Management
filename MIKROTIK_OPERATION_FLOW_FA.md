# مستند فنی فرایندهای MikroTik در پروژه `internet_management`

## هدف سند

این سند بر اساس کد فعلی پروژه تهیه شده و هدف آن شناسایی کامل مسیر عملیات‌های اصلی سیستم از سمت فرانت‌اند تا لایه سرویس و دستورات MikroTik RouterOS API v6 است.

دامنه بررسی این سند:

1. شناسایی `gateway` برای تنظیم `host` اتصال به RouterOS
2. عملیات ورود
3. دیدن دستگاه‌های متصل
4. قفل اتصال جدید
5. مسدود کردن
6. رفع مسدود کردن
7. جزئیات دستگاه
8. تنظیم سرعت

## جمع‌بندی اجرایی

- این کدبیس **بک‌اند مستقل** از نوع `Node.js`، `Python`، `PHP` یا API HTTP برای عملیات‌های MikroTik ندارد.
- مسیر واقعی اجرا به این شکل است:
  `Flutter UI -> Provider -> Service Manager -> MikroTikService -> RouterOSClientV2 -> RouterOS API v6`
- در نسخه فعلی، **اسکریپت MikroTik از نوع `/system/script`** در این مسیرها استفاده نشده است. عملیات‌ها با **دستور مستقیم RouterOS API v6** انجام می‌شوند.
- کلاینت فعال RouterOS در runtime فایل `[lib/services/routeros_client_v2.dart](lib/services/routeros_client_v2.dart)` است و از پکیج `router_os_client` استفاده می‌کند. فایل `[lib/services/routeros_client.dart](lib/services/routeros_client.dart)` در این مسیر عملیاتی استفاده نشده است.
- عملیات **قفل اتصال جدید** در کد فعلی یک «قفل سراسری روی روتر» نیست؛ بلکه ترکیبی از:
  - فلگ محلی در `SharedPreferences`
  - شناسایی دستگاه‌های داینامیک
  - اعمال `wireless access-list` برای محدودسازی دستگاه‌های تاییدنشده
- مسیر **مسدود کردن** دو مدل دارد:
  - `banClientInstant` از صفحه جزئیات: بن مستقیم، بدون ثبت fingerprint
  - `banClient` از Provider: تلاش برای بن با fingerprint و در صورت خطا fallback به بن مستقیم

## معماری واقعی پروژه

### 1. لایه فرانت‌اند

- صفحه ورود: `[lib/screens/login_screen.dart](lib/screens/login_screen.dart)`
- صفحه اصلی و لیست دستگاه‌ها: `[lib/main.dart](lib/main.dart)`
- صفحه جزئیات دستگاه: `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)`

### 2. لایه State / Orchestration

- مدیریت وضعیت کلاینت‌ها و عملیات‌ها: `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)`

### 3. لایه سرویس داخلی پروژه

- مدیریت singleton اتصال: `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)`
- منطق اصلی MikroTik: `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)`
- تشخیص IP و Gateway: `[lib/services/network_info_service.dart](lib/services/network_info_service.dart)`
- تنظیمات اتصال و ماندگاری داده‌ها: `[lib/services/settings_service.dart](lib/services/settings_service.dart)`
- لایه ترنسپورت RouterOS: `[lib/services/routeros_client_v2.dart](lib/services/routeros_client_v2.dart)`

### 4. مدل‌های اثرگذار در عملیات

- مدل اتصال: `[lib/models/mikrotik_connection.dart](lib/models/mikrotik_connection.dart)`
- مدل دستگاه: `[lib/models/client_info.dart](lib/models/client_info.dart)`
- اثرانگشت دستگاه: `[lib/models/device_fingerprint.dart](lib/models/device_fingerprint.dart)`
- ذخیره fingerprintهای بن‌شده: `[lib/services/device_fingerprint_service.dart](lib/services/device_fingerprint_service.dart)`

## نکات مهم قبل از ورود به عملیات‌ها

### نکته 1: این پروژه برای عملیات‌های مورد بررسی، درخواست HTTP به بک‌اند نمی‌زند

در مسیرهای `0` تا `7` هیچ فراخوانی `http` یا `dio` برای انجام عملیات MikroTik دیده نشد. عملیات‌ها مستقیم به RouterOS API v6 می‌روند.

### نکته 2: شناسایی Gateway فقط یک hop را می‌بیند

بر اساس کد فعلی، فقط **Gateway پیش‌فرض دستگاه** تشخیص داده می‌شود و همان در `host` ذخیره می‌شود. بنابراین:

- اگر `LHG` گیت‌وی پیش‌فرض باشد، اپلیکیشن `host` را روی IP همان `LHG` می‌گذارد.
- اگر `Main Router` گیت‌وی پیش‌فرض باشد، `host` روی IP همان روتر اصلی می‌رود.
- در کد فعلی، عبور خودکار از Gateway به «روتر پشت آن» دیده نشد.

### نکته 3: همه متدهای سرویس لزوماً در UI فعلی مصرف نشده‌اند

- لیست اصلی دستگاه‌ها از `getConnectedClients()` استفاده می‌کند، نه `getAllClients()` یا `getClientsDetailed()`.
- `getClientsDetailed()` وجود دارد، اما صفحه اصلی و صفحه جزئیات فعلی مستقیماً از آن استفاده نمی‌کنند.

### نکته 4: لیست دستگاه‌های مسدودشده، آرشیو کامل نیست

متد `getBannedClients()` فقط ruleها را نمی‌خواند؛ بعداً با `DHCP/ARP` تطبیق می‌دهد تا دستگاه‌های قابل‌تشخیص و فعال را برگرداند. بنابراین این لیست بیشتر شبیه «دستگاه‌های بن‌شده قابل مشاهده/فعال» است، نه یک تاریخچه کامل و دائمی.

---

## 0. شناسایی Gateway برای تنظیم IP اتصال RouterOS

### هدف

قبل از ورود، `host` اتصال MikroTik به‌صورت خودکار از Gateway فعلی شبکه تشخیص داده شود تا کاربر مجبور نباشد IP روتر را دستی وارد کند.

### ترتیب اجرای واقعی

1. در `initState` صفحه ورود، متد `_autoSetRouterHostFromGateway()` اجرا می‌شود.
2. متد `NetworkInfoService.getDefaultGatewayOrRouterIp()` فراخوانی می‌شود.
3. اگر اتصال RouterOS از قبل برقرار باشد:
   - `MikroTikServiceManager.getDefaultGatewayOrRouterIp()`
   - `MikroTikService.getDefaultGatewayOrRouterIp()`
   - `MikroTikService.getDefaultGateway()`
   - RouterOS route table با `/ip/route/print` خوانده می‌شود.
4. اگر اتصال برقرار نباشد:
   - IP محلی دستگاه از `NetworkInterface.list()` گرفته می‌شود.
   - بر اساس subnet، gateway به صورت `x.x.x.1` حدس زده می‌شود.
5. اگر این روش هم جواب ندهد:
   - `host` ذخیره‌شده در تنظیمات خوانده می‌شود.
6. در نهایت، `SettingsService.setHost(gateway)` اجرا می‌شود و مقدار `host` ذخیره می‌شود.

### RouterOS API v6 / Script

- دستور RouterOS در حالت connected:
  - `/ip/route/print`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- کاهش نیاز به ورود دستی IP روتر
- تنظیم خودکار `host` بر اساس گیت‌وی واقعی شبکه
- سازگاری با سناریویی که دسترسی از طریق `LHG` یا `Main Router` انجام می‌شود

### قبل و بعد از عملیات

- قبل از عملیات:
  - صفحه ورود تازه باز شده است
  - هنوز اتصال کاربر برقرار نشده یا از session قبلی ممکن است برقرار باشد
- بعد از عملیات:
  - `host` در تنظیمات به gateway تشخیص‌داده‌شده تغییر می‌کند
  - فرم ورود با IP جدید آماده اتصال می‌شود

### نکته مهم

- با باز شدن صفحه Login، کد فعلی می‌تواند `host` ذخیره‌شده قبلی را با gateway جدید overwrite کند.

### رفرنس‌های کد

- فرانت:
  - `[lib/screens/login_screen.dart](lib/screens/login_screen.dart)` - `initState` خط `33`
  - `[lib/screens/login_screen.dart](lib/screens/login_screen.dart)` - `_autoSetRouterHostFromGateway()` خط `41`
- سرویس:
  - `[lib/services/network_info_service.dart](lib/services/network_info_service.dart)` - `getDeviceIPv4Address()` خط `15`
  - `[lib/services/network_info_service.dart](lib/services/network_info_service.dart)` - `getDefaultGateway()` خط `53`
  - `[lib/services/network_info_service.dart](lib/services/network_info_service.dart)` - `getDefaultGatewayOrRouterIp()` خط `71`
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `getDefaultGateway()` خط `104`
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `getDefaultGatewayOrRouterIp()` خط `112`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getDefaultGateway()` خط `2408`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getDefaultGatewayOrRouterIp()` خط `2447`
  - `[lib/services/settings_service.dart](lib/services/settings_service.dart)` - `setHost()` خط `52`
- لاگ و مشاهده در startup:
  - `[lib/main.dart](lib/main.dart)` - بررسی و لاگ وضعیت شبکه از `main()` خط `29`
  - `[lib/main.dart](lib/main.dart)` - `_loadNetworkInfo()` خط `328`

### عملیات معکوس

- عملیات معکوس خودکار برای این بخش وجود ندارد.
- اگر کاربر بخواهد به جای gateway شناسایی‌شده به IP دیگری متصل شود، باید `host` را دستی تغییر دهد.

---

## 1. عملیات ورود

### هدف

برقراری session با RouterOS API v6 و آماده‌سازی داده‌های اصلی سیستم برای نمایش صفحه اصلی.

### ترتیب اجرای واقعی

1. کاربر نام کاربری و رمز را در صفحه ورود وارد می‌کند.
2. `_handleLogin()` تنظیمات اتصال را می‌خواند:
   - `host`
   - `port`
   - `useSsl`
3. یک `MikroTikConnection` ساخته می‌شود.
4. اگر `useSsl = true` و پورت `8728` باشد، مدل اتصال `actualPort` را به `8729` تبدیل می‌کند.
5. `MikroTikServiceManager.connect()` فراخوانی می‌شود.
6. Manager اتصال قبلی را قطع می‌کند و یک نمونه جدید از `MikroTikService` می‌سازد.
7. `MikroTikService.connect()`، شیء `RouterOSClientV2` را ساخته و `login()` را صدا می‌زند.
8. خود `RouterOSClientV2` از پکیج `router_os_client` برای لاگین استفاده می‌کند.
9. اگر اتصال موفق بود:
   - `MikroTikServiceManager.connect()` بلافاصله `getRouterInfo()` را هم صدا می‌زند.
   - timestamp لاگین در `SharedPreferences` ذخیره می‌شود.
   - کاربر به صفحه اصلی می‌رود.

### RouterOS API v6 / Script

- Handshake لاگین:
  - در کد پروژه به‌صورت دستور raw پیاده‌سازی نشده و داخل پکیج `router_os_client` انجام می‌شود.
- دستورات پس از ورود:
  - `/system/resource/print`
  - `/system/routerboard/print`
  - `/system/identity/print`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- احراز هویت با RouterOS
- ساخت context اتصال برای همه عملیات‌های بعدی
- دریافت مشخصات روتر برای نمایش و تصمیم‌گیری‌های بعدی

### قبل و بعد از عملیات

- قبل از عملیات:
  - `host` معمولاً قبلاً از gateway پر شده است
  - انقضای session قبلی بررسی می‌شود
- بعد از عملیات:
  - ارتباط RouterOS برقرار می‌شود
  - اطلاعات روتر preload می‌شود
  - زمان لاگین ذخیره می‌شود
  - `ClientsProvider` در صفحه اصلی `initialize()` را اجرا می‌کند

### نکته مهم

- انقضای لاگین در `SettingsService.isLoginExpired()` با بازه `14 روز` بررسی می‌شود.

### رفرنس‌های کد

- فرانت:
  - `[lib/screens/login_screen.dart](lib/screens/login_screen.dart)` - `_checkLoginExpiration()` خط `81`
  - `[lib/screens/login_screen.dart](lib/screens/login_screen.dart)` - `_handleLogin()` خط `89`
  - `[lib/main.dart](lib/main.dart)` - `HomePage` و `provider.initialize()` خط `491` و `508`
- مدل اتصال:
  - `[lib/models/mikrotik_connection.dart](lib/models/mikrotik_connection.dart)` - مدل و `actualPort` خط `2` و `18`
- تنظیمات:
  - `[lib/services/settings_service.dart](lib/services/settings_service.dart)` - `getHost()` خط `35`
  - `[lib/services/settings_service.dart](lib/services/settings_service.dart)` - `getPort()` خط `63`
  - `[lib/services/settings_service.dart](lib/services/settings_service.dart)` - `getUseSsl()` خط `91`
  - `[lib/services/settings_service.dart](lib/services/settings_service.dart)` - `setLoginTimestamp()` خط `156`
  - `[lib/services/settings_service.dart](lib/services/settings_service.dart)` - `isLoginExpired()` خط `177`
- سرویس:
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `connect()` خط `27`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `connect()` خط `17`
  - `[lib/services/routeros_client_v2.dart](lib/services/routeros_client_v2.dart)` - `login()` خط `25`
  - `[lib/services/routeros_client_v2.dart](lib/services/routeros_client_v2.dart)` - `talk()` خط `51`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getRouterInfo()` خط `2462`

### عملیات معکوس

- قطع اتصال و پاک‌کردن زمان لاگین:
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `disconnect()` خط `59`
  - `[lib/services/settings_service.dart](lib/services/settings_service.dart)` - `clearLoginTimestamp()` خط `192`
  - `[lib/main.dart](lib/main.dart)` - مسیر بازگشت به صفحه ورود در `_checkLoginExpiration()` خط `378`

---

## 2. دیدن دستگاه‌های متصل

### هدف

ساخت لیست دستگاه‌های متصل از چند منبع MikroTik و نمایش آن در صفحه اصلی.

### ترتیب اجرای واقعی

1. پس از ورود، `ClientsProvider.initialize()` اجرا می‌شود.
2. ترتیب اجرای آن:
   - `_loadApprovedDevices()`
   - `_loadLockStatus()`
   - `loadDeviceIp()`
   - `loadRouterInfo()`
   - `loadClients()`
   - `loadBannedClients()`
3. `loadClients()` از `MikroTikServiceManager.getConnectedClients()` داده می‌گیرد.
4. در `MikroTikService.getConnectedClients()` اطلاعات از این منابع جمع می‌شود:
   - `DHCP leases` برای hostname و تشخیص static/dynamic
   - `ARP table` برای تکمیل IP
   - `wireless registration table`
   - `hotspot active`
5. خروجی‌ها به `ClientInfo` تبدیل می‌شوند.
6. در Provider:
   - دستگاه‌های جدید از روی MAC شناسایی می‌شوند
   - اگر قفل فعال باشد، منطق pending approval و restrict اجرا می‌شود
   - اگر داده‌ها ناقص باشند، یک یا دو بار retry انجام می‌شود
   - دستگاه‌های بن‌شده از لیست حذف می‌شوند
   - دستگاه فعلی کاربر در ابتدای لیست قرار می‌گیرد

### RouterOS API v6 / Script

- دستورات اصلی:
  - `/ip/dhcp-server/lease/print`
  - `/ip/arp/print`
  - `/interface/wireless/registration-table/print`
  - `/ip/hotspot/active/print`
- دستورات تکمیلی برای بعضی helperها که در UI اصلی مستقیم مصرف نشده‌اند:
  - `/ppp/active/print`
  - `/queue/simple/print`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- ساخت لیست قابل اتکا از دستگاه‌ها با ترکیب چند منبع
- تعیین IP، MAC، hostname، نوع اتصال و وضعیت static/dynamic
- آماده‌سازی داده برای عملیات‌های بعدی مانند بن، تایید، جزئیات و سرعت

### قبل و بعد از عملیات

- قبل از عملیات:
  - session RouterOS باید برقرار باشد
  - Provider وضعیت lock، approved devices و banned devices را می‌خواند
- بعد از عملیات:
  - لیست اصلی UI پر می‌شود
  - دستگاه‌های بن‌شده در تب متصل‌ها نمایش داده نمی‌شوند
  - دستگاه فعلی کاربر در صدر لیست قرار می‌گیرد

### نکات مهم

- متد مورد استفاده UI اصلی `getConnectedClients()` است.
- متد `getAllClients()` و `getClientsDetailed()` وجود دارند، اما در مسیر اصلی نمایش لیست متصل‌ها مستقیماً استفاده نشده‌اند.
- مسیر `getConnectedClients()` فعلی، `PPP active` را وارد لیست اصلی نمی‌کند، در حالی که helperهای دیگر چنین قابلیتی دارند.
- در `initialize()` ابتدا `loadClients()` و بعد `loadBannedClients()` اجرا می‌شود، اما در `refresh()` ترتیب برعکس است و ابتدا banned list به‌روزرسانی می‌شود.

### رفرنس‌های کد

- فرانت:
  - `[lib/main.dart](lib/main.dart)` - `HomePage` خط `491`
  - `[lib/main.dart](lib/main.dart)` - شروع `provider.initialize()` خط `508`
  - `[lib/main.dart](lib/main.dart)` - ساخت کارت دستگاه `_buildClientCard()` خط `1497`
- Provider:
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `initialize()` خط `1116`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadDeviceIp()` خط `54`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadRouterInfo()` خط `77`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadClients()` خط `94`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadBannedClients()` خط `409`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `refresh()` خط `424`
- سرویس:
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `getConnectedClients()` خط `88`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getConnectedClients()` خط `307`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getAllClients()` خط `53`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getClientsDetailed()` خط `176`
- مدل:
  - `[lib/models/client_info.dart](lib/models/client_info.dart)` - مدل و تفسیر static/dynamic از lease خط `2` و `106`

### عملیات معکوس

- عملیات معکوس مستقیمی ندارد.
- در عمل، `refresh()` مسیر بازخوانی کامل همین عملیات است.

---

## 3. قفل اتصال جدید

### هدف

جلوگیری از دسترسی کامل دستگاه‌های داینامیک جدید یا تاییدنشد‌ه و هدایت آن‌ها به وضعیت «در انتظار تایید».

### واقعیت مهم این نسخه

در این نسخه، قفل اتصال جدید **قفل سراسری روی RouterOS** نیست.

آنچه واقعاً رخ می‌دهد:

1. یک فلگ محلی به نام `new_connections_locked` در `SharedPreferences` ذخیره می‌شود.
2. در هر بار `loadClients()`:
   - همه دستگاه‌های داینامیک بررسی می‌شوند
   - دستگاه فعلی، دستگاه‌های static، approved و banned رد می‌شوند
   - بقیه در `pending approval` قرار می‌گیرند
   - روی MAC آن‌ها `wireless access-list` با `deny/reject` اعمال می‌شود

### ترتیب اجرای واقعی

1. کاربر در صفحه اصلی دکمه Lock را می‌زند.
2. `provider.lockNewConnections()` یا `provider.unlockNewConnections()` اجرا می‌شود.
3. این متد فقط وضعیت را در Provider و `SharedPreferences` ذخیره می‌کند.
4. بعد از آن `provider.refresh()` اجرا می‌شود.
5. در `loadClients()`:
   - MACهای جدید نسبت به `_seenDevices` تشخیص داده می‌شوند
   - اگر lock فعال باشد، دستگاه‌های داینامیک تاییدنشده به `_pendingApprovalDevices` افزوده می‌شوند
   - `restrictNonStaticDevice()` برای آن‌ها فراخوانی می‌شود
6. `restrictNonStaticDevice()` در RouterOS:
   - `wireless access-list` را می‌خواند
   - اگر rule محدودکننده برای MAC وجود نداشته باشد، rule `deny` یا `reject` اضافه می‌کند

### RouterOS API v6 / Script

- برای خود `lockNewConnections()`:
  - هیچ دستور RouterOS اجرا نمی‌شود
- برای enforce شدن lock هنگام refresh:
  - `/interface/wireless/access-list/print`
  - `/interface/wireless/access-list/add`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- محدودسازی دستگاه‌های جدید داینامیک تا زمان تایید
- تفکیک دستگاه‌های trusted از دستگاه‌های تازه‌وارد
- جلوگیری از دسترسی کامل قبل از approve

### قبل و بعد از عملیات

- قبل از عملیات:
  - lock status از `SharedPreferences` بارگذاری می‌شود
- بعد از عملیات:
  - وضعیت lock در اپلیکیشن ذخیره می‌شود
  - enforce واقعی آن در refresh بعدی یا هنگام خواندن لیست اعمال می‌شود
  - دستگاه‌های pending در UI پیام approve/reject می‌گیرند

### نکته مهم

- در `loadClients()` اگر دستگاه approved یا pending قطع شود، از لیست‌های داخلی حذف می‌شود و در reconnect بعدی دوباره می‌تواند به‌عنوان دستگاه جدید/نیازمند تایید شناخته شود.

### تایید دستگاه در زمان lock

ترتیب اجرای `approveDevice()`:

1. MAC به `_approvedDevices` اضافه و ذخیره می‌شود
2. از `_pendingApprovalDevices` حذف می‌شود
3. `allowNonStaticDevice()` اجرا می‌شود
4. در RouterOS:
   - ruleهای `deny/reject` با comment مربوط به restriction حذف می‌شوند
   - rule مجاز `allow` یا `authentication=yes` اضافه می‌شود
5. MAC و IP در `locked_allowed_macs` و `locked_allowed_ips` ذخیره می‌شوند

### رد دستگاه در زمان lock

ترتیب اجرای `rejectDevice()`:

1. MAC از approved/pending/seen حذف می‌شود
2. `banClient()` مستقیم صدا زده می‌شود
3. comment مسیر reject:
   - `Rejected by user - New connection lock`
4. پس از بن:
   - لیست بن‌شده‌ها refresh می‌شود
   - دستگاه از لیست متصل‌ها حذف می‌شود

### رفرنس‌های کد

- فرانت:
  - `[lib/main.dart](lib/main.dart)` - دکمه lock/unlock خط `700`
  - `[lib/main.dart](lib/main.dart)` - approve device خط `1934`
  - `[lib/main.dart](lib/main.dart)` - reject device خط `2034`
  - `[lib/main.dart](lib/main.dart)` - add/remove allowed list خط `2276` و `2366`
- Provider:
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `lockNewConnections()` خط `1126`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `unlockNewConnections()` خط `1141`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadClients()` خط `94`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `approveDevice()` خط `993`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `rejectDevice()` خط `1040`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `isDevicePendingApproval()` خط `896`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `isDeviceAllowed()` خط `1373`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `allowNonStaticDevice()` خط `1409`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `removeFromAllowedList()` خط `1436`
- سرویس:
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `lockNewConnections()` خط `128`
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `unlockNewConnections()` خط `134`
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `restrictNonStaticDevice()` خط `152`
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `allowNonStaticDevice()` خط `160`
  - `[lib/services/mikrotik_service_manager.dart](lib/services/mikrotik_service_manager.dart)` - `removeFromAllowedList()` خط `168`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `lockNewConnections()` خط `2532`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `restrictNonStaticDevice()` خط `3520`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `allowNonStaticDevice()` خط `3587`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `removeFromAllowedList()` خط `3711`

### عملیات معکوس

- معکوس lock:
  - `unlockNewConnections()` فقط فلگ محلی را خاموش می‌کند.
- معکوس approve:
  - `removeFromAllowedList()` که rule مجاز را حذف و دوباره restriction را اعمال می‌کند.
- معکوس reject:
  - `unbanClient()` یا `unbanClientWithFingerprint()` بسته به نوع بن

---

## 4. مسدود کردن

### هدف

قطع دسترسی دستگاه به شبکه/اینترنت از چند مسیر همزمان تا صرفاً با تغییر IP یا reconnect ساده نتواند عبور کند.

### مسیرهای واقعی بن در پروژه

#### مسیر A: بن فوری از صفحه جزئیات

1. کاربر در `DeviceDetailScreen` گزینه بن را می‌زند.
2. `_banDeviceInternal()` اجرا می‌شود.
3. `provider.banClientInstant(ip, mac)` صدا زده می‌شود.
4. این مسیر به `service.banClient()` می‌رود.
5. بعد از موفقیت:
   - دستگاه از لیست UI حذف می‌شود
   - `loadBannedClients()` در پس‌زمینه اجرا می‌شود
   - در این مرحله `getBannedClients()` از روی `raw rules` و تطبیق `DHCP/ARP` لیست تب بن‌شده‌ها را می‌سازد
   - کاربر به صفحه اصلی برمی‌گردد

#### مسیر B: بن استاندارد از Provider

1. `provider.banClient()` فراخوانی می‌شود.
2. ابتدا تلاش می‌کند `banClientWithFingerprint()` را اجرا کند.
3. اگر موفق نشد یا خطا داد، fallback به `banClient()` می‌رود.
4. در مسیر fingerprint:
   - fingerprint ساخته می‌شود
   - در `SharedPreferences` ذخیره می‌شود
   - بن اصلی با comment شامل fingerprint انجام می‌شود
5. بعد از بن:
   - دستگاه از لیست connected حذف می‌شود
   - `loadBannedClients()` اجرا می‌شود
   - `getBannedClients()` از `raw rules` و `DHCP/ARP` داده تب banned را بازسازی می‌کند
   - `checkAndBanBannedDevices()` در پس‌زمینه برای reconnectهای بعدی اجرا می‌شود

#### مسیر C: رد دستگاه pending

1. `rejectDevice()` مستقیماً `service.banClient()` را صدا می‌زند.
2. comment این مسیر:
   - `Rejected by user - New connection lock`

### ترتیب دستورهای RouterOS در `banClient()`

1. اگر MAC داده نشده باشد:
   - `/ip/dhcp-server/lease/print`
   - fallback: `/ip/arp/print`
2. اضافه‌کردن rule بن بر اساس IP:
   - `/ip/firewall/raw/add`
3. اضافه‌کردن rule بن بر اساس MAC:
   - `/ip/firewall/raw/add`
4. block-access روی DHCP lease:
   - `/ip/dhcp-server/lease/print`
   - `/ip/dhcp-server/lease/set`
5. enforce روی wireless:
   - `/interface/wireless/access-list/print`
   - اگر rule موجود باشد: `/interface/wireless/access-list/set`
   - اگر موجود نباشد: `/interface/wireless/access-list/add`

### RouterOS API v6 / Script

- دستورات اصلی بن:
  - `/ip/dhcp-server/lease/print`
  - `/ip/arp/print`
  - `/ip/firewall/raw/add`
  - `/ip/dhcp-server/lease/set`
  - `/interface/wireless/access-list/print`
  - `/interface/wireless/access-list/set`
  - `/interface/wireless/access-list/add`
- دستورات مکمل برای بن مجدد دستگاه fingerprint شده:
  - `/ip/firewall/raw/print`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- بن فقط روی یک لایه انجام نشده است
- هم IP و هم MAC لحاظ می‌شود
- DHCP lease block می‌شود
- برای وایرلس access-list هم درگیر می‌شود
- در مسیر fingerprint، امکان بن مجدد بعد از reconnect یا تغییر پارامترهای جزئی وجود دارد

### قبل و بعد از عملیات

- قبل از عملیات:
  - اطلاعات IP و MAC اگر ناقص باشد از DHCP/ARP تکمیل می‌شود
- بعد از عملیات:
  - ruleهای raw ایجاد می‌شوند
  - DHCP lease ممکن است block شود
  - access-list ممکن است `deny/reject` شود
  - دستگاه از لیست متصل‌ها حذف می‌شود
  - در بعضی مسیرها fingerprint ذخیره و auto-ban آینده فعال می‌شود

### نکات مهم

- مسیر `banClientInstant()` که در UI جزئیات استفاده شده، fingerprint ذخیره نمی‌کند.
- مسیر `banClient()` در Provider fingerprint را ذخیره می‌کند.
- `checkAndBanBannedDevices()` فقط برای مسیر fingerprint معنا پیدا می‌کند.

### رفرنس‌های کد

- فرانت:
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_banDeviceInternal()` خط `1632`
- Provider:
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `banClientInstant()` خط `447`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `banClient()` خط `517`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadBannedClients()` خط `409`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `rejectDevice()` خط `1040`
- سرویس:
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `banClientWithFingerprint()` خط `459`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `banClient()` خط `548`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getBannedClients()` خط `1121`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `checkAndBanBannedDevices()` خط `2271`
  - `[lib/services/device_fingerprint_service.dart](lib/services/device_fingerprint_service.dart)` - `saveBannedFingerprint()` خط `17`
  - `[lib/models/device_fingerprint.dart](lib/models/device_fingerprint.dart)` - مدل fingerprint

### عملیات معکوس

- `unbanClient()` یا `unbanClientWithFingerprint()`

---

## 5. رفع مسدود کردن

### هدف

حذف همه لایه‌های محدودسازی که در بن اعمال شده‌اند و بازگرداندن دستگاه به وضعیت عادی یا pending، بسته به lock.

### ترتیب اجرای واقعی

1. کاربر در `DeviceDetailScreen` گزینه رفع مسدودیت را می‌زند.
2. `_unbanDeviceInternal()` اجرا می‌شود.
3. `provider.unbanClient(ip, mac, hostname, ssid)` فراخوانی می‌شود.
4. این متد ابتدا `service.unbanClientWithFingerprint()` را صدا می‌زند.
5. در `unbanClientWithFingerprint()`:
   - fingerprint از داده‌های دستگاه ساخته می‌شود
   - `raw rules` با comment شامل `Auto-banned:` و fingerprint حذف می‌شوند
   - fingerprint از `SharedPreferences` حذف می‌شود
   - سپس `unbanClient()` اجرا می‌شود
6. در `unbanClient()`:
   - اگر MAC داده نشده باشد از DHCP/ARP پیدا می‌شود
   - همه `raw rules` مرتبط حذف می‌شوند
   - DHCP lease بررسی می‌شود
   - اگر `block-access=yes` باشد، به `no` برگردانده می‌شود
   - اگر lease استاتیکی با comment خودکار برای بن ساخته شده باشد، ممکن است حذف شود
   - `wireless access-list` تمیز می‌شود
7. پس از موفقیت:
   - `loadBannedClients()` اجرا می‌شود
   - `getBannedClients()` تب بن‌شده‌ها را دوباره از روی RouterOS می‌سازد
   - `loadClients()` اجرا می‌شود
8. اگر lock فعال باشد:
   - MAC از seen حذف می‌شود
   - دستگاه دوباره به pending approval برمی‌گردد

### ترتیب دستورهای RouterOS در `unbanClient()`

1. پیدا کردن MAC در صورت نیاز:
   - `/ip/dhcp-server/lease/print`
   - fallback: `/ip/arp/print`
2. حذف raw rules:
   - `/ip/firewall/raw/print`
   - `/ip/firewall/raw/remove`
3. اصلاح DHCP:
   - `/ip/dhcp-server/lease/print`
   - در صورت نیاز: `/ip/dhcp-server/lease/set`
   - در بعضی سناریوها: `/ip/dhcp-server/lease/remove`
4. اصلاح wireless access list:
   - `/interface/wireless/access-list/print`
   - `/interface/wireless/access-list/remove`
   - یا `/interface/wireless/access-list/set`

### RouterOS API v6 / Script

- دستورات اصلی:
  - `/ip/dhcp-server/lease/print`
  - `/ip/arp/print`
  - `/ip/firewall/raw/print`
  - `/ip/firewall/raw/remove`
  - `/ip/dhcp-server/lease/set`
  - `/ip/dhcp-server/lease/remove`
  - `/interface/wireless/access-list/print`
  - `/interface/wireless/access-list/remove`
  - `/interface/wireless/access-list/set`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- حذف بن فقط از یک نقطه کافی نیست
- باید هم firewall raw، هم DHCP، هم access-list پاک یا اصلاح شوند
- در مسیر fingerprint، داده مرجع بن آینده نیز باید حذف شود

### قبل و بعد از عملیات

- قبل از عملیات:
  - بسته به مسیر بن، ممکن است fingerprint ذخیره شده باشد یا نباشد
- بعد از عملیات:
  - ruleهای raw حذف می‌شوند
  - block-access DHCP برداشته می‌شود
  - access-list اصلاح یا حذف می‌شود
  - banned list refresh می‌شود
  - اگر lock روشن باشد، دستگاه دوباره نیازمند تایید می‌شود

### رفرنس‌های کد

- فرانت:
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_unbanDeviceInternal()` خط `1745`
- Provider:
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `unbanClient()` خط `677`
- تکمیل refresh:
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadBannedClients()` خط `409`
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `loadClients()` خط `94`
- سرویس:
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `unbanClientWithFingerprint()` خط `849`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `unbanClient()` خط `905`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getBannedClients()` خط `1121`
  - `[lib/services/device_fingerprint_service.dart](lib/services/device_fingerprint_service.dart)` - `removeBannedFingerprint()` خط `76`

### عملیات معکوس

- عملیات معکوس این بخش، دوباره `banClient()` است.

---

## 6. جزئیات دستگاه

### هدف

نمایش داده‌های عملیاتی و مدیریتی هر دستگاه و فراهم کردن نقطه شروع برای عملیات‌های جزئی‌تر مانند بن، رفع بن، وضعیت lease و تنظیم سرعت.

### ترتیب اجرای واقعی

1. کاربر از لیست دستگاه‌ها روی یک کارت وارد `DeviceDetailScreen` می‌شود.
2. در `initState()`:
   - وضعیت اولیه `isStaticLease` از `widget.device` برداشته می‌شود
   - بعضی cacheها preload می‌شوند
3. سپس `_loadAllData` و متدهای تکمیلی اجرا می‌شوند.
4. برای سرعت:
   - ابتدا cache محلی خوانده می‌شود
   - سپس `_loadSpeedLimit()` در پس‌زمینه از RouterOS مقدار واقعی را می‌گیرد
5. برای وضعیت lease:
   - اگر مقدار قطعی در مدل نباشد، `_loadLeaseStatus()` اجرا می‌شود
6. بن و رفع بن و static lease و تنظیم سرعت همگی از همین صفحه قابل شروع هستند.

### RouterOS API v6 / Script

- برای بارگذاری سرعت:
  - `/queue/simple/print`
  - در صورت نیاز برای resolve MAC به IP:
    - `/ip/dhcp-server/lease/print`
    - `/ip/arp/print`
- برای وضعیت static/dynamic lease:
  - `/ip/dhcp-server/lease/print`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- صفحه جزئیات، مرکز عملیات per-device است
- داده‌های زنده‌تر مثل speed و lease status در این صفحه مجدداً از RouterOS خوانده می‌شوند

### قبل و بعد از عملیات

- قبل از عملیات:
  - بخشی از داده از `ClientInfo` ورودی صفحه آمده است
- بعد از عملیات:
  - speed واقعی و lease status در UI دقیق‌تر می‌شود
  - کاربر می‌تواند عملیات مدیریتی بعدی را شروع کند

### نکته مهم

- این صفحه از `getClientsDetailed()` استفاده نمی‌کند.
- داده‌های جزئی با چند call مستقل مثل `getClientSpeed()` و `getLeaseStatus()` گرفته می‌شوند.

### رفرنس‌های کد

- فرانت:
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `initState()` خط `52`
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_loadSpeedLimit()` خط `1098`
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_loadLeaseStatus()` خط `1175`
- سرویس:
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getClientSpeed()` خط `1919`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getLeaseStatus()` خط `9933`

### عملیات معکوس

- این بخش خودش عملیات معکوس مستقل ندارد و بیشتر container عملیات‌های جزئی است.

---

## 7. عملیات تنظیم سرعت

### هدف

ایجاد یا به‌روزرسانی `simple queue` برای دستگاه تا `max-limit` آن کنترل شود.

### ترتیب اجرای واقعی

1. کاربر در صفحه جزئیات، گزینه تنظیم سرعت را انتخاب می‌کند.
2. `_setSpeedLimitInternal(ip, maxLimit)` اجرا می‌شود.
3. `provider.setClientSpeed(target, maxLimit)` صدا زده می‌شود.
4. Provider متد `service.setClientSpeed()` را فراخوانی می‌کند.
5. در سرویس:
   - اگر `target` MAC باشد، IP از DHCP و سپس ARP پیدا می‌شود
   - اگر `target` IP باشد، مستقیم همان استفاده می‌شود
   - نام queue به صورت `DEV-<ip>` ساخته می‌شود
   - ابتدا queue بر اساس `target=<ip>/32` جستجو می‌شود
   - اگر نبود، بر اساس `name=DEV-<ip>` جستجو می‌شود
   - اگر queue پیدا شد، `max-limit` آن update می‌شود
   - اگر پیدا نشد، queue جدید ساخته می‌شود
   - اگر duplicate رخ دهد، دوباره queue پیدا و update می‌شود
6. پس از موفقیت:
   - `refresh()` در پس‌زمینه اجرا می‌شود
   - صفحه جزئیات بعداً دوباره `_loadSpeedLimit()` را اجرا می‌کند تا مقدار واقعی را از RouterOS تایید کند

### RouterOS API v6 / Script

- برای resolve کردن IP:
  - `/ip/dhcp-server/lease/print`
  - `/ip/arp/print`
- برای queue:
  - `/queue/simple/print`
  - `/queue/simple/set`
  - `/queue/simple/add`
- اسکریپت RouterOS:
  - استفاده نشده

### دلیل عملیات

- کنترل مستقیم پهنای باند هر دستگاه
- حفظ queue بر اساس IP/target
- استفاده از fallback by name برای افزایش پایداری

### قبل و بعد از عملیات

- قبل از عملیات:
  - ممکن است مقدار speed از cache آمده باشد
- بعد از عملیات:
  - queue ساخته یا update می‌شود
  - UI refresh می‌شود
  - صفحه جزئیات دوباره مقدار واقعی RouterOS را می‌خواند

### نکات مهم

- UI فعلی برای تنظیم سرعت معمولاً IP را به سرویس می‌دهد.
- متد معکوس `removeClientSpeed()` در سرویس وجود دارد، اما در UI فعلی دکمه مستقیمی برای آن دیده نشد.

### رفرنس‌های کد

- فرانت:
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_setSpeedLimitInternal()` خط `908`
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_loadSpeedLimit()` خط `1098`
- Provider:
  - `[lib/providers/clients_provider.dart](lib/providers/clients_provider.dart)` - `setClientSpeed()` خط `734`
- سرویس:
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `setClientSpeed()` خط `1527`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `removeClientSpeed()` خط `1760`
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `getClientSpeed()` خط `1919`

### عملیات معکوس

- `removeClientSpeed()` وجود دارد، ولی از UI فعلی مستقیماً استفاده نشده است.

---

## عملیات مکمل مهم که روی عملیات‌های اصلی اثر دارند

### A. تبدیل Lease به Static

این عملیات در لیست اصلی شما نبود، اما چون روی رفتار lock و تشخیص دستگاه اثر مستقیم دارد، باید شناخته شود.

#### اثر روی سیستم

- دستگاه‌های static در منطق lock از restriction رد می‌شوند.
- یعنی static کردن lease می‌تواند عملاً دستگاه را از مسیر pending/restrict خارج کند.

#### RouterOS API v6

- `/ip/dhcp-server/lease/print`
- `/ip/dhcp-server/lease/make-static`
- `/ip/dhcp-server/lease/set`

#### رفرنس‌های کد

- فرانت:
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_makeStaticLeaseInternal()` خط `1291`
- سرویس:
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `makeStaticLease()` خط `9763`

### B. حذف Static Lease

#### اثر روی سیستم

- دستگاه دوباره dynamic می‌شود
- در reconnect بعدی ممکن است دوباره تحت منطق lock/pending قرار بگیرد

#### RouterOS API v6

- `/ip/dhcp-server/lease/print`
- `/ip/dhcp-server/lease/remove`

#### رفرنس‌های کد

- فرانت:
  - `[lib/screens/device_detail_screen.dart](lib/screens/device_detail_screen.dart)` - `_removeStaticLeaseInternal()` خط `1419`
- سرویس:
  - `[lib/services/mikrotik_service.dart](lib/services/mikrotik_service.dart)` - `removeStaticLease()` خط `10034`

---

## جمع‌بندی نهایی رفتار سیستم

### مسیر استاندارد runtime

1. ورود از صفحه Login
2. شناسایی Gateway و تنظیم `host`
3. اتصال مستقیم به RouterOS API v6
4. خواندن اطلاعات روتر
5. بارگذاری لیست دستگاه‌ها
6. اعمال فیلترهای local state مانند lock، approved، pending و banned
7. اجرای عملیات per-device مثل ban/unban/detail/speed

### مهم‌ترین واقعیت‌های فنی این نسخه

1. بک‌اند مستقل برای این عملیات‌ها وجود ندارد و Flutter مستقیم به MikroTik وصل می‌شود.
2. اسکریپت `/system/script` در مسیرهای بررسی‌شده به کار نرفته است.
3. Lock New Connections در این نسخه یک state محلی + access-list workflow است، نه قفل سراسری RouterOS.
4. بن از صفحه جزئیات و بن از Provider دقیقاً یکسان نیستند؛ مسیر Provider می‌تواند fingerprint هم ذخیره کند.
5. لیست banned بیشتر از نوع active/observable است، نه آرشیو کامل ruleها.
6. متد حذف speed وجود دارد، اما در UI فعلی expose نشده است.
7. static lease روی رفتار lock اثر مستقیم دارد.
