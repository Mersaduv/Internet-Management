import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_localizations.dart';
import '../utils/app_theme.dart';
import '../utils/main_navigation.dart';
import '../widgets/app_page_bar.dart';
import '../widgets/desktop_content.dart';

/// صفحه راهنمای مشترکین — آموزش مرحله‌به‌مرحله عملیات‌ها
class SubscriberHelpScreen extends StatelessWidget {
  const SubscriberHelpScreen({super.key});

  static const List<String> _supportPhones = ['0795336608', '0700336608'];

  void _goToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).pop();
    mainBottomTabRequest.value = tabIndex;
  }

  Future<void> _openWifiSettings(BuildContext context) async {
    await Navigator.of(context).pushNamed('/wifi-settings');
  }

  Future<void> _copyPhone(BuildContext context, String phone) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.phoneCopied ?? 'شماره کپی شد'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = AppTheme.primaryFor(theme.brightness);

    return Scaffold(
      appBar: AppPageBar(
        title: l10n?.subscriberHelp ?? 'راهنمای مشترکین',
      ),
      body: Container(
        color: colorScheme.surfaceContainerHighest,
        child: DesktopContent(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: ListView(
            children: [
              _IntroCard(
                primary: primary,
                title: l10n?.subscriberHelpIntroTitle ??
                    'راهنمای ساده استفاده از برنامه',
                body: l10n?.subscriberHelpIntroBody ??
                    'هر بخش را به‌ترتیب بخوانید. کنار هر دکمه، آیکون همان دکمه در برنامه نشان داده شده تا سریع پیدا کنید چه کاری انجام می‌دهد و از کجا باز می‌شود.',
              ),
              const SizedBox(height: 16),

              // —— ۱. مدیریت دستگاه‌ها (اولویت اول)
              _GuideSection(
                primary: primary,
                number: '۱',
                icon: Icons.home_rounded,
                title: l10n?.helpDevicesSectionTitle ??
                    'مدیریت دستگاه‌ها (صفحه خانه)',
                subtitle: l10n?.helpDevicesSectionSubtitle ??
                    'اولویت اول — دیدن و کنترل دستگاه‌های وصل‌شده به شبکه',
                whereFrom: l10n?.helpDevicesWhere ??
                    'از کجا: نوار پایین → آیکون خانه',
                whereIcon: Icons.home_rounded,
                steps: [
                  _HelpAction(
                    icon: Icons.home_rounded,
                    title: l10n?.helpDevActHomeTitle ?? 'آیکون خانه',
                    detail: l10n?.helpDevActHomeDetail ??
                        'در نوار پایین برنامه، اولین آیکون (خانه) را بزنید تا صفحه اصلی باز شود.',
                  ),
                  _HelpAction(
                    icon: Icons.router,
                    title: l10n?.helpDevActRouterTitle ?? 'اطلاعات روتر (بالای صفحه)',
                    detail: l10n?.helpDevActRouterDetail ??
                        'بالای صفحه نام روتر و کاربر را می‌بینید. فقط برای اطلاع است؛ دکمه‌ای برای فشار دادن نیست.',
                  ),
                  _HelpAction(
                    icon: Icons.lock,
                    title: l10n?.helpDevActLockTitle ?? 'دکمه قفل اتصال جدید',
                    detail: l10n?.helpDevActLockDetail ??
                        'این دکمه زیر اطلاعات روتر است. اگر روشن باشد، دستگاه‌های تازه‌وارد محدود می‌شوند. دوباره بزنید تا باز شود.',
                  ),
                  _HelpAction(
                    icon: Icons.devices,
                    title: l10n?.helpDevActConnectedTitle ?? 'زبانه «متصل»',
                    detail: l10n?.helpDevActConnectedDetail ??
                        'آیکون چند دستگاه — فهرست گوشی‌ها و لپ‌تاپ‌هایی که الان به شبکه وصل‌اند را نشان می‌دهد.',
                  ),
                  _HelpAction(
                    icon: Icons.block,
                    title: l10n?.helpDevActBannedTitle ?? 'زبانه «مسدود»',
                    detail: l10n?.helpDevActBannedDetail ??
                        'آیکون دایره با خط — دستگاه‌هایی که قبلاً مسدود کرده‌اید اینجاست.',
                  ),
                  _HelpAction(
                    icon: Icons.refresh,
                    title: l10n?.helpDevActRefreshTitle ?? 'کشیدن صفحه به پایین',
                    detail: l10n?.helpDevActRefreshDetail ??
                        'لیست را با انگشت به پایین بکشید تا تازه‌سازی شود و دستگاه‌های جدید دیده شوند.',
                  ),
                  _HelpAction(
                    icon: Icons.touch_app_rounded,
                    title: l10n?.helpDevActTapTitle ?? 'لمس روی یک دستگاه',
                    detail: l10n?.helpDevActTapDetail ??
                        'روی نام یا ردیف دستگاه بزنید تا صفحه جزئیات باز شود (سرعت، مسدودسازی و …).',
                  ),
                  _HelpAction(
                    icon: Icons.speed,
                    title: l10n?.helpDevActSpeedTitle ?? 'محدود کردن سرعت',
                    detail: l10n?.helpDevActSpeedDetail ??
                        'داخل صفحه دستگاه، سرعت دانلود/آپلود را تنظیم و ذخیره کنید.',
                  ),
                  _HelpAction(
                    icon: Icons.block,
                    title: l10n?.helpDevActBanTitle ?? 'مسدود کردن دستگاه',
                    detail: l10n?.helpDevActBanDetail ??
                        'در همان صفحه جزئیات، گزینه مسدودسازی را بزنید تا دستگاه از اینترنت قطع شود و به زبانه «مسدود» برود.',
                  ),
                  _HelpAction(
                    icon: Icons.lock_open,
                    title: l10n?.helpDevActUnbanTitle ?? 'رفع مسدودیت',
                    detail: l10n?.helpDevActUnbanDetail ??
                        'در زبانه «مسدود»، آیکون قفل باز کنار دستگاه را بزنید تا دوباره آزاد شود.',
                  ),
                ],
                actionLabel: l10n?.helpOpenHome ?? 'رفتن به صفحه خانه',
                actionIcon: Icons.home_rounded,
                onAction: () => _goToTab(context, 0),
              ),
              const SizedBox(height: 16),

              // —— ۲. تنظیمات وای‌فای
              _GuideSection(
                primary: primary,
                number: '۲',
                icon: Icons.wifi_rounded,
                title: l10n?.helpWifiSectionTitle ?? 'تنظیمات وای‌فای',
                subtitle: l10n?.helpWifiSectionSubtitle ??
                    'اولویت دوم — تغییر نام شبکه و رمز وای‌فای',
                whereFrom: l10n?.helpWifiWhere ??
                    'از کجا: نوار پایین → تنظیمات → تنظیمات وایفای',
                whereIcon: Icons.settings_rounded,
                steps: [
                  _HelpAction(
                    icon: Icons.settings_rounded,
                    title: l10n?.helpWifiActSettingsTitle ?? 'آیکون تنظیمات',
                    detail: l10n?.helpWifiActSettingsDetail ??
                        'در نوار پایین، آخرین آیکون (چرخ‌دنده) را بزنید تا صفحه تنظیمات باز شود.',
                  ),
                  _HelpAction(
                    icon: Icons.wifi,
                    title: l10n?.helpWifiActItemTitle ?? 'گزینه «تنظیمات وایفای»',
                    detail: l10n?.helpWifiActItemDetail ??
                        'اولین گزینه در لیست تنظیمات است. روی آن بزنید تا صفحه تغییر نام و رمز باز شود.',
                  ),
                  _HelpAction(
                    icon: Icons.badge_outlined,
                    title: l10n?.helpWifiActSsidTitle ?? 'نام شبکه (SSID)',
                    detail: l10n?.helpWifiActSsidDetail ??
                        'نامی که گوشی‌ها در لیست وای‌فای می‌بینند. می‌توانید عوض کنید.',
                  ),
                  _HelpAction(
                    icon: Icons.password_rounded,
                    title: l10n?.helpWifiActPassTitle ?? 'رمز عبور',
                    detail: l10n?.helpWifiActPassDetail ??
                        'رمز جدید را وارد کنید. معمولاً حداقل ۸ کاراکتر لازم است.',
                  ),
                  _HelpAction(
                    icon: Icons.visibility_off_rounded,
                    title: l10n?.helpWifiActHideTitle ?? 'مخفی کردن نام شبکه',
                    detail: l10n?.helpWifiActHideDetail ??
                        'اگر روشن باشد، نام شبکه در لیست وای‌فای دیده نمی‌شود (اختیاری).',
                  ),
                  _HelpAction(
                    icon: Icons.save_rounded,
                    title: l10n?.helpWifiActSaveTitle ?? 'دکمه ذخیره',
                    detail: l10n?.helpWifiActSaveDetail ??
                        'بعد از پر کردن فیلدها، ذخیره را بزنید و صبر کنید تا پیام موفقیت بیاید.',
                  ),
                  _HelpAction(
                    icon: Icons.phonelink_setup_rounded,
                    title: l10n?.helpWifiActReconnectTitle ?? 'وصل شدن دوباره دستگاه‌ها',
                    detail: l10n?.helpWifiActReconnectDetail ??
                        'بعد از تغییر رمز، همه گوشی‌ها و لپ‌تاپ‌ها باید با رمز جدید دوباره وصل شوند.',
                  ),
                  _HelpAction(
                    icon: Icons.web_asset_rounded,
                    title: l10n?.helpWifiActWebTitle ?? 'بعضی آنتن‌ها (LHG / SXT / …)',
                    detail: l10n?.helpWifiActWebDetail ??
                        'در برخی مدل‌ها به‌جای فرم، صفحه مرورگر داخلی باز می‌شود. همان‌جا نام و رمز را عوض کنید.',
                  ),
                ],
                actionLabel:
                    l10n?.helpOpenWifiSettings ?? 'باز کردن تنظیمات وای‌فای',
                actionIcon: Icons.wifi_rounded,
                onAction: () => _openWifiSettings(context),
              ),
              const SizedBox(height: 16),

              // —— ۳. سرویس اینترنت
              _GuideSection(
                primary: primary,
                number: '۳',
                icon: Icons.public_rounded,
                title: l10n?.helpInternetSectionTitle ?? 'سرویس اینترنت',
                subtitle: l10n?.helpInternetSectionSubtitle ??
                    'دیدن پنل کاربری و وضعیت اشتراک',
                whereFrom: l10n?.helpInternetWhere ??
                    'از کجا: نوار پایین → آیکون کره زمین',
                whereIcon: Icons.public_rounded,
                steps: [
                  _HelpAction(
                    icon: Icons.public_rounded,
                    title: l10n?.helpNetActTabTitle ?? 'آیکون سرویس انترنت',
                    detail: l10n?.helpNetActTabDetail ??
                        'دومین آیکون نوار پایین (کره) را بزنید. پنل کاربری خودکار باز می‌شود.',
                  ),
                  _HelpAction(
                    icon: Icons.login_rounded,
                    title: l10n?.helpNetActLoginTitle ?? 'ورود به پنل',
                    detail: l10n?.helpNetActLoginDetail ??
                        'با نام کاربری و رمز اختصاصی خود وارد شوید تا وضعیت اشتراک را ببینید.',
                  ),
                  _HelpAction(
                    icon: Icons.arrow_back_rounded,
                    title: l10n?.helpNetActBackTitle ?? 'دکمه بازگشت (هدر)',
                    detail: l10n?.helpNetActBackDetail ??
                        'آیکون فلش چپ در بالای صفحه — صفحه قبلی داخل پنل را نشان می‌دهد.',
                  ),
                  _HelpAction(
                    icon: Icons.arrow_forward_rounded,
                    title: l10n?.helpNetActForwardTitle ?? 'دکمه جلو (هدر)',
                    detail: l10n?.helpNetActForwardDetail ??
                        'آیکون فلش راست — اگر قبلاً برگشته باشید، دوباره جلو می‌رود.',
                  ),
                  _HelpAction(
                    icon: Icons.refresh_rounded,
                    title: l10n?.helpNetActReloadTitle ?? 'دکمه تازه‌سازی',
                    detail: l10n?.helpNetActReloadDetail ??
                        'آیکون دایره فلش‌دار — صفحه پنل را دوباره بارگذاری می‌کند.',
                  ),
                  _HelpAction(
                    icon: Icons.link_rounded,
                    title: l10n?.helpNetActLinkTitle ?? 'دکمه تغییر آدرس',
                    detail: l10n?.helpNetActLinkDetail ??
                        'آیکون لینک در هدر — فقط اگر لازم شد آدرس پنل را عوض کنید.',
                  ),
                ],
                actionLabel:
                    l10n?.helpOpenInternetService ?? 'باز کردن سرویس اینترنت',
                actionIcon: Icons.public_rounded,
                onAction: () => _goToTab(context, 1),
              ),
              const SizedBox(height: 16),

              // —— ۴. بسته‌ها
              _GuideSection(
                primary: primary,
                number: '۴',
                icon: Icons.style_rounded,
                title: l10n?.helpPackagesSectionTitle ?? 'بسته‌های اینترنتی',
                subtitle: l10n?.helpPackagesSectionSubtitle ??
                    'مشاهده انواع بسته و سرعت‌ها',
                whereFrom: l10n?.helpPackagesWhere ??
                    'از کجا: نوار پایین → آیکون بسته‌ها',
                whereIcon: Icons.style_rounded,
                steps: [
                  _HelpAction(
                    icon: Icons.style_rounded,
                    title: l10n?.helpPkgActTabTitle ?? 'آیکون بسته‌ها',
                    detail: l10n?.helpPkgActTabDetail ??
                        'سومین آیکون نوار پایین را بزنید تا فهرست بسته‌ها باز شود.',
                  ),
                  _HelpAction(
                    icon: Icons.tab_rounded,
                    title: l10n?.helpPkgActTabsTitle ?? 'زبانه‌های بالا',
                    detail: l10n?.helpPkgActTabsDetail ??
                        'بین نامحدود، حجمی و ددیکیت جابه‌جا شوید و سرعت و مدت هر بسته را ببینید.',
                  ),
                ],
                actionLabel: l10n?.helpOpenPackages ?? 'رفتن به بسته‌ها',
                actionIcon: Icons.style_rounded,
                onAction: () => _goToTab(context, 2),
              ),
              const SizedBox(height: 16),

              _TipsCard(
                primary: primary,
                title: l10n?.helpTipsTitle ?? 'نکات ساده',
                tips: [
                  l10n?.helpTip1 ??
                      'قبل از کار با برنامه، به وای‌فای همان شبکه روتر وصل باشید.',
                  l10n?.helpTip2 ??
                      'اگر لیست دستگاه‌ها خالی بود، صفحه را به پایین بکشید یا کمی صبر کنید.',
                  l10n?.helpTip3 ??
                      'بعد از عوض کردن رمز وای‌فای، دستگاه‌ها را با رمز جدید وصل کنید.',
                  l10n?.helpTip4 ??
                      'اگر پنل سرویس باز نشد، دکمه تازه‌سازی (دایره فلش‌دار) را بزنید.',
                  l10n?.helpTip5 ??
                      'برای مشکل ورود یا رمز فراموش‌شده، با پشتیبانی تماس بگیرید.',
                ],
              ),
              const SizedBox(height: 16),
              _SupportCard(
                primary: primary,
                title: l10n?.helpSupportTitle ?? 'تماس با پشتیبانی',
                subtitle: l10n?.helpSupportSubtitle ??
                    'برای کپی شماره، روی آن ضربه بزنید',
                phones: _supportPhones,
                onCopy: (phone) => _copyPhone(context, phone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpAction {
  const _HelpAction({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.primary,
    required this.title,
    required this.body,
  });

  final Color primary;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.35 : 0.92,
            ),
            AppTheme.navyMid.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.45 : 0.85,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.primary,
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.whereFrom,
    required this.whereIcon,
    required this.steps,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final Color primary;
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  final String whereFrom;
  final IconData whereIcon;
  final List<_HelpAction> steps;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1.5,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.tintFor(theme.brightness),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$number. $title',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.tintFor(theme.brightness),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Icon(whereIcon, size: 18, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      whereFrom,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ...steps.asMap().entries.map((entry) {
              return _ActionStepTile(
                index: entry.key + 1,
                action: entry.value,
                primary: primary,
              );
            }),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.arrow_forward_rounded),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionStepTile extends StatelessWidget {
  const _ActionStepTile({
    required this.index,
    required this.action,
    required this.primary,
  });

  final int index;
  final _HelpAction action;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.successSurfaceFor(theme.brightness),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.successBorderFor(theme.brightness),
                  ),
                ),
                child: Icon(
                  action.icon,
                  size: 18,
                  color: AppTheme.successForegroundFor(theme.brightness),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$index',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.35 : 0.55,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.5,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({
    required this.primary,
    required this.title,
    required this.tips,
  });

  final Color primary;
  final String title;
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1.5,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: primary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.primary,
    required this.title,
    required this.subtitle,
    required this.phones,
    required this.onCopy,
  });

  final Color primary;
  final String title;
  final String subtitle;
  final List<String> phones;
  final void Function(String phone) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 1.5,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.tintFor(theme.brightness),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.headset_mic_rounded, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...phones.map(
              (phone) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.65,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onCopy(phone),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_in_talk_rounded, color: primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              phone,
                              textDirection: TextDirection.ltr,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.copy_rounded,
                            color: primary.withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
