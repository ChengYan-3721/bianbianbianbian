import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('zh')];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'边边记账'**
  String get appTitle;

  /// No description provided for @tabRecord.
  ///
  /// In zh, this message translates to:
  /// **'记账'**
  String get tabRecord;

  /// No description provided for @tabStats.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get tabStats;

  /// No description provided for @tabLedger.
  ///
  /// In zh, this message translates to:
  /// **'账本'**
  String get tabLedger;

  /// No description provided for @tabMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabMe;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @nextStep.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get nextStep;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get clear;

  /// No description provided for @modify.
  ///
  /// In zh, this message translates to:
  /// **'修改'**
  String get modify;

  /// No description provided for @select.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get select;

  /// No description provided for @know.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get know;

  /// No description provided for @tip.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get tip;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loading;

  /// No description provided for @parsing.
  ///
  /// In zh, this message translates to:
  /// **'解析中…'**
  String get parsing;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get deleted;

  /// No description provided for @required.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get optional;

  /// No description provided for @enabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In zh, this message translates to:
  /// **'关闭中'**
  String get disabled;

  /// No description provided for @notConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get notConfigured;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// No description provided for @txTypeIncome.
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get txTypeIncome;

  /// No description provided for @txTypeExpense.
  ///
  /// In zh, this message translates to:
  /// **'支出'**
  String get txTypeExpense;

  /// No description provided for @txTypeTransfer.
  ///
  /// In zh, this message translates to:
  /// **'转账'**
  String get txTypeTransfer;

  /// No description provided for @txTypeUncategorized.
  ///
  /// In zh, this message translates to:
  /// **'未分类'**
  String get txTypeUncategorized;

  /// No description provided for @periodMonthly.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get periodMonthly;

  /// No description provided for @periodYearly.
  ///
  /// In zh, this message translates to:
  /// **'年'**
  String get periodYearly;

  /// No description provided for @periodMonthBudget.
  ///
  /// In zh, this message translates to:
  /// **'月预算'**
  String get periodMonthBudget;

  /// No description provided for @periodYearBudget.
  ///
  /// In zh, this message translates to:
  /// **'年预算'**
  String get periodYearBudget;

  /// No description provided for @parentKeyIncome.
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get parentKeyIncome;

  /// No description provided for @parentKeyFood.
  ///
  /// In zh, this message translates to:
  /// **'饮食'**
  String get parentKeyFood;

  /// No description provided for @parentKeyShopping.
  ///
  /// In zh, this message translates to:
  /// **'购物'**
  String get parentKeyShopping;

  /// No description provided for @parentKeyTransport.
  ///
  /// In zh, this message translates to:
  /// **'出行'**
  String get parentKeyTransport;

  /// No description provided for @parentKeyEducation.
  ///
  /// In zh, this message translates to:
  /// **'教育'**
  String get parentKeyEducation;

  /// No description provided for @parentKeyEntertainment.
  ///
  /// In zh, this message translates to:
  /// **'娱乐'**
  String get parentKeyEntertainment;

  /// No description provided for @parentKeySocial.
  ///
  /// In zh, this message translates to:
  /// **'人情'**
  String get parentKeySocial;

  /// No description provided for @parentKeyHousing.
  ///
  /// In zh, this message translates to:
  /// **'住房'**
  String get parentKeyHousing;

  /// No description provided for @parentKeyMedical.
  ///
  /// In zh, this message translates to:
  /// **'医药'**
  String get parentKeyMedical;

  /// No description provided for @parentKeyInvestment.
  ///
  /// In zh, this message translates to:
  /// **'投资'**
  String get parentKeyInvestment;

  /// No description provided for @parentKeyOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get parentKeyOther;

  /// No description provided for @quickCatIncome.
  ///
  /// In zh, this message translates to:
  /// **'收'**
  String get quickCatIncome;

  /// No description provided for @quickCatFood.
  ///
  /// In zh, this message translates to:
  /// **'食'**
  String get quickCatFood;

  /// No description provided for @quickCatShopping.
  ///
  /// In zh, this message translates to:
  /// **'购'**
  String get quickCatShopping;

  /// No description provided for @quickCatTransport.
  ///
  /// In zh, this message translates to:
  /// **'行'**
  String get quickCatTransport;

  /// No description provided for @quickCatEducation.
  ///
  /// In zh, this message translates to:
  /// **'育'**
  String get quickCatEducation;

  /// No description provided for @quickCatEntertainment.
  ///
  /// In zh, this message translates to:
  /// **'乐'**
  String get quickCatEntertainment;

  /// No description provided for @quickCatSocial.
  ///
  /// In zh, this message translates to:
  /// **'情'**
  String get quickCatSocial;

  /// No description provided for @quickCatHousing.
  ///
  /// In zh, this message translates to:
  /// **'住'**
  String get quickCatHousing;

  /// No description provided for @quickCatMedical.
  ///
  /// In zh, this message translates to:
  /// **'医'**
  String get quickCatMedical;

  /// No description provided for @quickCatInvestment.
  ///
  /// In zh, this message translates to:
  /// **'投'**
  String get quickCatInvestment;

  /// No description provided for @quickCatOther.
  ///
  /// In zh, this message translates to:
  /// **'其'**
  String get quickCatOther;

  /// No description provided for @accountTypeCash.
  ///
  /// In zh, this message translates to:
  /// **'现金'**
  String get accountTypeCash;

  /// No description provided for @accountTypeDebit.
  ///
  /// In zh, this message translates to:
  /// **'储蓄卡'**
  String get accountTypeDebit;

  /// No description provided for @accountTypeCredit.
  ///
  /// In zh, this message translates to:
  /// **'信用卡'**
  String get accountTypeCredit;

  /// No description provided for @accountTypeThirdParty.
  ///
  /// In zh, this message translates to:
  /// **'第三方支付'**
  String get accountTypeThirdParty;

  /// No description provided for @accountTypeOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get accountTypeOther;

  /// No description provided for @deletedAccount.
  ///
  /// In zh, this message translates to:
  /// **'（已删账户）'**
  String get deletedAccount;

  /// No description provided for @currencyCny.
  ///
  /// In zh, this message translates to:
  /// **'人民币'**
  String get currencyCny;

  /// No description provided for @currencyUsd.
  ///
  /// In zh, this message translates to:
  /// **'美元'**
  String get currencyUsd;

  /// No description provided for @currencyEur.
  ///
  /// In zh, this message translates to:
  /// **'欧元'**
  String get currencyEur;

  /// No description provided for @currencyJpy.
  ///
  /// In zh, this message translates to:
  /// **'日元'**
  String get currencyJpy;

  /// No description provided for @currencyKrw.
  ///
  /// In zh, this message translates to:
  /// **'韩元'**
  String get currencyKrw;

  /// No description provided for @currencyHkd.
  ///
  /// In zh, this message translates to:
  /// **'港币'**
  String get currencyHkd;

  /// No description provided for @currencyTwd.
  ///
  /// In zh, this message translates to:
  /// **'新台币'**
  String get currencyTwd;

  /// No description provided for @currencyGbp.
  ///
  /// In zh, this message translates to:
  /// **'英镑'**
  String get currencyGbp;

  /// No description provided for @currencySgd.
  ///
  /// In zh, this message translates to:
  /// **'新元'**
  String get currencySgd;

  /// No description provided for @currencyCad.
  ///
  /// In zh, this message translates to:
  /// **'加元'**
  String get currencyCad;

  /// No description provided for @currencyAud.
  ///
  /// In zh, this message translates to:
  /// **'澳元'**
  String get currencyAud;

  /// No description provided for @currencyCnyFull.
  ///
  /// In zh, this message translates to:
  /// **'人民币 (CNY)'**
  String get currencyCnyFull;

  /// No description provided for @currencyUsdFull.
  ///
  /// In zh, this message translates to:
  /// **'美元 (USD)'**
  String get currencyUsdFull;

  /// No description provided for @currencyEurFull.
  ///
  /// In zh, this message translates to:
  /// **'欧元 (EUR)'**
  String get currencyEurFull;

  /// No description provided for @currencyJpyFull.
  ///
  /// In zh, this message translates to:
  /// **'日元 (JPY)'**
  String get currencyJpyFull;

  /// No description provided for @currencyKrwFull.
  ///
  /// In zh, this message translates to:
  /// **'韩元 (KRW)'**
  String get currencyKrwFull;

  /// No description provided for @currencyGbpFull.
  ///
  /// In zh, this message translates to:
  /// **'英镑 (GBP)'**
  String get currencyGbpFull;

  /// No description provided for @currencyHkdFull.
  ///
  /// In zh, this message translates to:
  /// **'港币 (HKD)'**
  String get currencyHkdFull;

  /// No description provided for @themeCreamBunny.
  ///
  /// In zh, this message translates to:
  /// **'🐰 奶油兔'**
  String get themeCreamBunny;

  /// No description provided for @themeThickBrownBear.
  ///
  /// In zh, this message translates to:
  /// **'🐻 厚棕熊'**
  String get themeThickBrownBear;

  /// No description provided for @themeMoonlightDark.
  ///
  /// In zh, this message translates to:
  /// **'🌙 月见黑'**
  String get themeMoonlightDark;

  /// No description provided for @themeMintGreen.
  ///
  /// In zh, this message translates to:
  /// **'🍃 薄荷绿'**
  String get themeMintGreen;

  /// No description provided for @fontSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontSizeSmall;

  /// No description provided for @fontSizeStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get fontSizeStandard;

  /// No description provided for @fontSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontSizeLarge;

  /// No description provided for @iconPackSticker.
  ///
  /// In zh, this message translates to:
  /// **'✏️ 手绘贴纸'**
  String get iconPackSticker;

  /// No description provided for @iconPackFlat.
  ///
  /// In zh, this message translates to:
  /// **'📝 扁平简约'**
  String get iconPackFlat;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @loadFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{error}'**
  String loadFailedWithError(String error);

  /// No description provided for @saveFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String saveFailedWithError(String error);

  /// No description provided for @deleteFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String deleteFailedWithError(String error);

  /// No description provided for @readFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'读取失败：{error}'**
  String readFailedWithError(String error);

  /// No description provided for @operationFailedWithError.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String operationFailedWithError(String error);

  /// No description provided for @budgetConflictTotal.
  ///
  /// In zh, this message translates to:
  /// **'该账本的{period}总预算已存在'**
  String budgetConflictTotal(String period);

  /// No description provided for @budgetConflictCategory.
  ///
  /// In zh, this message translates to:
  /// **'该分类的{period}预算已存在'**
  String budgetConflictCategory(String period);

  /// No description provided for @ledgerNameConflict.
  ///
  /// In zh, this message translates to:
  /// **'已存在同名账本「{name}」'**
  String ledgerNameConflict(String name);

  /// No description provided for @meAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get meAppearance;

  /// No description provided for @meReminder.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get meReminder;

  /// No description provided for @meBudget.
  ///
  /// In zh, this message translates to:
  /// **'预算'**
  String get meBudget;

  /// No description provided for @meAssets.
  ///
  /// In zh, this message translates to:
  /// **'资产'**
  String get meAssets;

  /// No description provided for @meMultiCurrency.
  ///
  /// In zh, this message translates to:
  /// **'多币种'**
  String get meMultiCurrency;

  /// No description provided for @meAiInput.
  ///
  /// In zh, this message translates to:
  /// **'快速输入 · AI 增强'**
  String get meAiInput;

  /// No description provided for @meCloudService.
  ///
  /// In zh, this message translates to:
  /// **'云服务'**
  String get meCloudService;

  /// No description provided for @meAttachmentCache.
  ///
  /// In zh, this message translates to:
  /// **'附件缓存'**
  String get meAttachmentCache;

  /// No description provided for @meImportExport.
  ///
  /// In zh, this message translates to:
  /// **'导入 / 导出'**
  String get meImportExport;

  /// No description provided for @meAppLock.
  ///
  /// In zh, this message translates to:
  /// **'应用锁'**
  String get meAppLock;

  /// No description provided for @meTrash.
  ///
  /// In zh, this message translates to:
  /// **'垃圾桶'**
  String get meTrash;

  /// No description provided for @recordTitle.
  ///
  /// In zh, this message translates to:
  /// **'记账'**
  String get recordTitle;

  /// No description provided for @recordSwitchLedger.
  ///
  /// In zh, this message translates to:
  /// **'切换账本'**
  String get recordSwitchLedger;

  /// No description provided for @recordIncome.
  ///
  /// In zh, this message translates to:
  /// **'收入'**
  String get recordIncome;

  /// No description provided for @recordExpense.
  ///
  /// In zh, this message translates to:
  /// **'支出'**
  String get recordExpense;

  /// No description provided for @recordBalance.
  ///
  /// In zh, this message translates to:
  /// **'结余'**
  String get recordBalance;

  /// No description provided for @recordSyncing.
  ///
  /// In zh, this message translates to:
  /// **'同步中…'**
  String get recordSyncing;

  /// No description provided for @recordSyncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败：{error}'**
  String recordSyncFailed(String error);

  /// No description provided for @recordLastSyncedAt.
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String recordLastSyncedAt(String time);

  /// No description provided for @recordNeverSynced.
  ///
  /// In zh, this message translates to:
  /// **'尚未同步'**
  String get recordNeverSynced;

  /// No description provided for @recordJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get recordJustNow;

  /// No description provided for @recordMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}分钟前'**
  String recordMinutesAgo(int count);

  /// No description provided for @recordHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}小时前'**
  String recordHoursAgo(int count);

  /// No description provided for @recordDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}天前'**
  String recordDaysAgo(int count);

  /// No description provided for @recordYearMonth.
  ///
  /// In zh, this message translates to:
  /// **'{year}年{month}月'**
  String recordYearMonth(int year, int month);

  /// No description provided for @recordQuickHint.
  ///
  /// In zh, this message translates to:
  /// **'写点什么，我来帮你记 🐱'**
  String get recordQuickHint;

  /// No description provided for @recordRecognize.
  ///
  /// In zh, this message translates to:
  /// **'识别'**
  String get recordRecognize;

  /// No description provided for @recordStartFirst.
  ///
  /// In zh, this message translates to:
  /// **'开始记第一笔吧 🐱'**
  String get recordStartFirst;

  /// No description provided for @recordSynced.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get recordSynced;

  /// No description provided for @recordNetworkUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'网络不可用'**
  String get recordNetworkUnavailable;

  /// No description provided for @recordSyncFailedMsg.
  ///
  /// In zh, this message translates to:
  /// **'同步失败：{message}'**
  String recordSyncFailedMsg(String message);

  /// No description provided for @recordDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除这条记录？'**
  String get recordDeleteConfirm;

  /// No description provided for @recordDeleteHint.
  ///
  /// In zh, this message translates to:
  /// **'删除后可在后续垃圾桶中恢复。'**
  String get recordDeleteHint;

  /// No description provided for @recordIdleReminder.
  ///
  /// In zh, this message translates to:
  /// **'已经 {days} 天没记账了，快来记一笔吧 🐻'**
  String recordIdleReminder(int days);

  /// No description provided for @recordPleaseInputFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先输入一段话再点识别'**
  String get recordPleaseInputFirst;

  /// No description provided for @recordNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'记一笔'**
  String get recordNewTitle;

  /// No description provided for @recordNewTransferTitle.
  ///
  /// In zh, this message translates to:
  /// **'转账'**
  String get recordNewTransferTitle;

  /// No description provided for @recordNewCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get recordNewCategory;

  /// No description provided for @recordNewSelectCategory.
  ///
  /// In zh, this message translates to:
  /// **'选择分类'**
  String get recordNewSelectCategory;

  /// No description provided for @recordNewDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get recordNewDate;

  /// No description provided for @recordNewNote.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get recordNewNote;

  /// No description provided for @recordNewInputNote.
  ///
  /// In zh, this message translates to:
  /// **'输入备注'**
  String get recordNewInputNote;

  /// No description provided for @recordNewNoteOptional.
  ///
  /// In zh, this message translates to:
  /// **'可留空'**
  String get recordNewNoteOptional;

  /// No description provided for @recordNewSwitchTo.
  ///
  /// In zh, this message translates to:
  /// **'切换'**
  String get recordNewSwitchTo;

  /// No description provided for @recordNewFromAccount.
  ///
  /// In zh, this message translates to:
  /// **'转出账户'**
  String get recordNewFromAccount;

  /// No description provided for @recordNewToAccount.
  ///
  /// In zh, this message translates to:
  /// **'转入账户'**
  String get recordNewToAccount;

  /// No description provided for @recordNewTransferSameError.
  ///
  /// In zh, this message translates to:
  /// **'转出账户和转入账户不能相同'**
  String get recordNewTransferSameError;

  /// No description provided for @recordNewAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get recordNewAdd;

  /// No description provided for @recordNewEditCategory.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get recordNewEditCategory;

  /// No description provided for @recordNewLoadingCategories.
  ///
  /// In zh, this message translates to:
  /// **'加载分类…'**
  String get recordNewLoadingCategories;

  /// No description provided for @recordNewInputAmount.
  ///
  /// In zh, this message translates to:
  /// **'输入金额'**
  String get recordNewInputAmount;

  /// No description provided for @recordNewWallet.
  ///
  /// In zh, this message translates to:
  /// **'钱包'**
  String get recordNewWallet;

  /// No description provided for @recordNewDeleteImage.
  ///
  /// In zh, this message translates to:
  /// **'删除图片'**
  String get recordNewDeleteImage;

  /// No description provided for @recordNewGallery.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get recordNewGallery;

  /// No description provided for @recordNewCamera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get recordNewCamera;

  /// No description provided for @recordNewTransferSettings.
  ///
  /// In zh, this message translates to:
  /// **'转账设置'**
  String get recordNewTransferSettings;

  /// No description provided for @recordNewSelectCurrency.
  ///
  /// In zh, this message translates to:
  /// **'选择币种'**
  String get recordNewSelectCurrency;

  /// No description provided for @recordNewMaxAttachments.
  ///
  /// In zh, this message translates to:
  /// **'最多只能选择{max}张图片'**
  String recordNewMaxAttachments(int max);

  /// No description provided for @recordNewImageTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'单张图片不能超过 10MB'**
  String get recordNewImageTooLarge;

  /// No description provided for @recordNewDuplicateImage.
  ///
  /// In zh, this message translates to:
  /// **'同一张图片不能重复添加'**
  String get recordNewDuplicateImage;

  /// No description provided for @recordSearchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索流水'**
  String get recordSearchTitle;

  /// No description provided for @recordSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'关键词（备注 / 分类 / 账户）'**
  String get recordSearchHint;

  /// No description provided for @recordSearchFilter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get recordSearchFilter;

  /// No description provided for @recordSearchNoDateLimit.
  ///
  /// In zh, this message translates to:
  /// **'不限日期'**
  String get recordSearchNoDateLimit;

  /// No description provided for @recordSearchDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get recordSearchDate;

  /// No description provided for @recordSearchClearDate.
  ///
  /// In zh, this message translates to:
  /// **'清空日期'**
  String get recordSearchClearDate;

  /// No description provided for @recordSearchType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get recordSearchType;

  /// No description provided for @recordSearchAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get recordSearchAll;

  /// No description provided for @recordSearchAmount.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get recordSearchAmount;

  /// No description provided for @recordSearchAmountMin.
  ///
  /// In zh, this message translates to:
  /// **'下限'**
  String get recordSearchAmountMin;

  /// No description provided for @recordSearchAmountMax.
  ///
  /// In zh, this message translates to:
  /// **'上限'**
  String get recordSearchAmountMax;

  /// No description provided for @recordSearchEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词或筛选条件后开始搜索'**
  String get recordSearchEmptyHint;

  /// No description provided for @recordSearchNoResult.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关流水'**
  String get recordSearchNoResult;

  /// No description provided for @recordMonthPrevYear.
  ///
  /// In zh, this message translates to:
  /// **'上一年'**
  String get recordMonthPrevYear;

  /// No description provided for @recordMonthNextYear.
  ///
  /// In zh, this message translates to:
  /// **'下一年'**
  String get recordMonthNextYear;

  /// No description provided for @recordMonthYear.
  ///
  /// In zh, this message translates to:
  /// **'{year} 年'**
  String recordMonthYear(int year);

  /// No description provided for @recordMonthMonth.
  ///
  /// In zh, this message translates to:
  /// **'{month} 月'**
  String recordMonthMonth(int month);

  /// No description provided for @quickConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认记一笔'**
  String get quickConfirmTitle;

  /// No description provided for @quickConfirmLowConfidence.
  ///
  /// In zh, this message translates to:
  /// **'识别置信度较低，请核对'**
  String get quickConfirmLowConfidence;

  /// No description provided for @quickConfirmAiUpdated.
  ///
  /// In zh, this message translates to:
  /// **'AI 已更新'**
  String get quickConfirmAiUpdated;

  /// No description provided for @quickConfirmAiFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 解析失败：{message}'**
  String quickConfirmAiFailed(String message);

  /// No description provided for @quickConfirmAiFailedUnknown.
  ///
  /// In zh, this message translates to:
  /// **'AI 解析失败：{error}'**
  String quickConfirmAiFailedUnknown(String error);

  /// No description provided for @quickConfirmAmount.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get quickConfirmAmount;

  /// No description provided for @quickConfirmCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get quickConfirmCategory;

  /// No description provided for @quickConfirmPleaseSelect.
  ///
  /// In zh, this message translates to:
  /// **'请选择'**
  String get quickConfirmPleaseSelect;

  /// No description provided for @quickConfirmTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get quickConfirmTime;

  /// No description provided for @quickConfirmAiEnhance.
  ///
  /// In zh, this message translates to:
  /// **'AI 增强'**
  String get quickConfirmAiEnhance;

  /// No description provided for @categoryManageTitle.
  ///
  /// In zh, this message translates to:
  /// **'分类管理'**
  String get categoryManageTitle;

  /// No description provided for @categoryEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑分类'**
  String get categoryEditTitle;

  /// No description provided for @categoryAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加分类'**
  String get categoryAddTitle;

  /// No description provided for @categoryReorderTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get categoryReorderTitle;

  /// No description provided for @categoryFavoriteReorderTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get categoryFavoriteReorderTitle;

  /// No description provided for @categoryName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get categoryName;

  /// No description provided for @categoryNameHint.
  ///
  /// In zh, this message translates to:
  /// **'设置分类名称（一级：{parent}）'**
  String categoryNameHint(String parent);

  /// No description provided for @categoryNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入分类名称'**
  String get categoryNameRequired;

  /// No description provided for @categoryIconEmoji.
  ///
  /// In zh, this message translates to:
  /// **'图标 Emoji（可选）'**
  String get categoryIconEmoji;

  /// No description provided for @categoryIconEmojiHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 🍔、🚗、🎁'**
  String get categoryIconEmojiHint;

  /// No description provided for @categoryDuplicateName.
  ///
  /// In zh, this message translates to:
  /// **'该一级分类下已存在同名分类'**
  String get categoryDuplicateName;

  /// No description provided for @categoryAddNew.
  ///
  /// In zh, this message translates to:
  /// **'添加新的分类'**
  String get categoryAddNew;

  /// No description provided for @categoryNoFavorite.
  ///
  /// In zh, this message translates to:
  /// **'还没有收藏分类'**
  String get categoryNoFavorite;

  /// No description provided for @categoryNoCategory.
  ///
  /// In zh, this message translates to:
  /// **'暂无分类'**
  String get categoryNoCategory;

  /// No description provided for @categoryUncollect.
  ///
  /// In zh, this message translates to:
  /// **'取消收藏'**
  String get categoryUncollect;

  /// No description provided for @categoryCollect.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get categoryCollect;

  /// No description provided for @categoryUndoDelete.
  ///
  /// In zh, this message translates to:
  /// **'取消删除'**
  String get categoryUndoDelete;

  /// No description provided for @statsTitle.
  ///
  /// In zh, this message translates to:
  /// **'统计分析'**
  String get statsTitle;

  /// No description provided for @statsExport.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get statsExport;

  /// No description provided for @statsThisMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get statsThisMonth;

  /// No description provided for @statsLastMonth.
  ///
  /// In zh, this message translates to:
  /// **'上月'**
  String get statsLastMonth;

  /// No description provided for @statsThisYear.
  ///
  /// In zh, this message translates to:
  /// **'本年'**
  String get statsThisYear;

  /// No description provided for @statsCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get statsCustom;

  /// No description provided for @statsSelectRange.
  ///
  /// In zh, this message translates to:
  /// **'选择统计区间'**
  String get statsSelectRange;

  /// No description provided for @statsIncomeExpenseLine.
  ///
  /// In zh, this message translates to:
  /// **'收支折线（按日）'**
  String get statsIncomeExpenseLine;

  /// No description provided for @statsChartLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'图表加载失败：{error}'**
  String statsChartLoadFailed(String error);

  /// No description provided for @statsNoIncomeExpenseData.
  ///
  /// In zh, this message translates to:
  /// **'暂无收支数据'**
  String get statsNoIncomeExpenseData;

  /// No description provided for @statsTryAnotherRange.
  ///
  /// In zh, this message translates to:
  /// **'换个区间试试吧 🐱'**
  String get statsTryAnotherRange;

  /// No description provided for @statsExpenseCategoryPie.
  ///
  /// In zh, this message translates to:
  /// **'支出分类占比'**
  String get statsExpenseCategoryPie;

  /// No description provided for @statsNoExpenseData.
  ///
  /// In zh, this message translates to:
  /// **'暂无支出数据'**
  String get statsNoExpenseData;

  /// No description provided for @statsAddExpenseHint.
  ///
  /// In zh, this message translates to:
  /// **'记一笔支出就能看到啦 🐱'**
  String get statsAddExpenseHint;

  /// No description provided for @statsViewBudget.
  ///
  /// In zh, this message translates to:
  /// **'查看预算'**
  String get statsViewBudget;

  /// No description provided for @statsRanking.
  ///
  /// In zh, this message translates to:
  /// **'收支排行榜'**
  String get statsRanking;

  /// No description provided for @statsRankLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'排行榜加载失败：{error}'**
  String statsRankLoadFailed(String error);

  /// No description provided for @statsNoRankData.
  ///
  /// In zh, this message translates to:
  /// **'暂无排行数据'**
  String get statsNoRankData;

  /// No description provided for @statsAddMoreHint.
  ///
  /// In zh, this message translates to:
  /// **'记几笔就能看到排名啦 🐱'**
  String get statsAddMoreHint;

  /// No description provided for @statsHeatmapTitle.
  ///
  /// In zh, this message translates to:
  /// **'支出日历热力图'**
  String get statsHeatmapTitle;

  /// No description provided for @statsHeatmapLegend.
  ///
  /// In zh, this message translates to:
  /// **'颜色越深表示当日支出越高'**
  String get statsHeatmapLegend;

  /// No description provided for @statsHeatmapLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'热力图加载失败：{error}'**
  String statsHeatmapLoadFailed(String error);

  /// No description provided for @statsNoHeatmapData.
  ///
  /// In zh, this message translates to:
  /// **'暂无支出热力数据'**
  String get statsNoHeatmapData;

  /// No description provided for @statsHeatmapHint.
  ///
  /// In zh, this message translates to:
  /// **'记一笔支出就能点亮日历啦 🐱'**
  String get statsHeatmapHint;

  /// No description provided for @statsExportPng.
  ///
  /// In zh, this message translates to:
  /// **'导出 PNG（当前视图截图）'**
  String get statsExportPng;

  /// No description provided for @statsExportCsv.
  ///
  /// In zh, this message translates to:
  /// **'导出 CSV（当前区间明细）'**
  String get statsExportCsv;

  /// No description provided for @statsExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String statsExportFailed(String error);

  /// No description provided for @statsChartNotMounted.
  ///
  /// In zh, this message translates to:
  /// **'图表区尚未挂载'**
  String get statsChartNotMounted;

  /// No description provided for @statsPngTitle.
  ///
  /// In zh, this message translates to:
  /// **'边边记账 · 统计图表'**
  String get statsPngTitle;

  /// No description provided for @statsPngSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'统计区间：{range}'**
  String statsPngSubtitle(String range);

  /// No description provided for @statsCsvTitle.
  ///
  /// In zh, this message translates to:
  /// **'边边记账 · 流水明细'**
  String get statsCsvTitle;

  /// No description provided for @statsCsvSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'统计区间：{range}'**
  String statsCsvSubtitle(String range);

  /// No description provided for @weekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'周一'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'周二'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'周三'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'周四'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'周五'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'周六'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'周日'**
  String get weekdaySun;

  /// No description provided for @weekdayShortMon.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get weekdayShortSun;

  /// No description provided for @dateMonthDayWeekday.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日 {weekday}'**
  String dateMonthDayWeekday(int month, int day, String weekday);

  /// No description provided for @ledgerEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑账本'**
  String get ledgerEditTitle;

  /// No description provided for @ledgerNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建账本'**
  String get ledgerNewTitle;

  /// No description provided for @ledgerNotExist.
  ///
  /// In zh, this message translates to:
  /// **'账本不存在'**
  String get ledgerNotExist;

  /// No description provided for @ledgerName.
  ///
  /// In zh, this message translates to:
  /// **'账本名称'**
  String get ledgerName;

  /// No description provided for @ledgerNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入账本名称'**
  String get ledgerNameRequired;

  /// No description provided for @ledgerCoverEmoji.
  ///
  /// In zh, this message translates to:
  /// **'封面 Emoji'**
  String get ledgerCoverEmoji;

  /// No description provided for @ledgerCoverEmojiHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 📒、💼、✈️'**
  String get ledgerCoverEmojiHint;

  /// No description provided for @ledgerDefaultCurrency.
  ///
  /// In zh, this message translates to:
  /// **'默认币种'**
  String get ledgerDefaultCurrency;

  /// No description provided for @ledgerArchived.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get ledgerArchived;

  /// No description provided for @ledgerArchiveHint.
  ///
  /// In zh, this message translates to:
  /// **'归档后账本将移至归档区，不再显示在切换器中'**
  String get ledgerArchiveHint;

  /// No description provided for @ledgerCannotSave.
  ///
  /// In zh, this message translates to:
  /// **'账本不存在，无法保存'**
  String get ledgerCannotSave;

  /// No description provided for @ledgerNameConflictMsg.
  ///
  /// In zh, this message translates to:
  /// **'已存在同名账本「{name}」，请换一个'**
  String ledgerNameConflictMsg(String name);

  /// No description provided for @ledgerNew.
  ///
  /// In zh, this message translates to:
  /// **'新建账本'**
  String get ledgerNew;

  /// No description provided for @ledgerEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有账本，去创建一个吧 🐱'**
  String get ledgerEmptyHint;

  /// No description provided for @ledgerUnarchive.
  ///
  /// In zh, this message translates to:
  /// **'取消归档'**
  String get ledgerUnarchive;

  /// No description provided for @ledgerArchive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get ledgerArchive;

  /// No description provided for @ledgerConfirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get ledgerConfirmDelete;

  /// No description provided for @ledgerDeleteConfirmMsg.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除账本「{name}」吗？\n\n该账本下的所有流水和预算也将被删除。\n删除后可在垃圾桶中保留 30 天。'**
  String ledgerDeleteConfirmMsg(String name);

  /// No description provided for @ledgerDeleted.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」已删除'**
  String ledgerDeleted(String name);

  /// No description provided for @ledgerTxCountCurrency.
  ///
  /// In zh, this message translates to:
  /// **'{count} 笔流水  ·  {currency}'**
  String ledgerTxCountCurrency(int count, Object currency);

  /// No description provided for @budgetTitle.
  ///
  /// In zh, this message translates to:
  /// **'预算'**
  String get budgetTitle;

  /// No description provided for @budgetNew.
  ///
  /// In zh, this message translates to:
  /// **'新建预算'**
  String get budgetNew;

  /// No description provided for @budgetNotExist.
  ///
  /// In zh, this message translates to:
  /// **'预算不存在'**
  String get budgetNotExist;

  /// No description provided for @budgetPeriod.
  ///
  /// In zh, this message translates to:
  /// **'周期'**
  String get budgetPeriod;

  /// No description provided for @budgetCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get budgetCategory;

  /// No description provided for @budgetTotalNoCategory.
  ///
  /// In zh, this message translates to:
  /// **'总预算（不限分类）'**
  String get budgetTotalNoCategory;

  /// No description provided for @budgetAmount.
  ///
  /// In zh, this message translates to:
  /// **'预算金额'**
  String get budgetAmount;

  /// No description provided for @budgetAmountRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入金额'**
  String get budgetAmountRequired;

  /// No description provided for @budgetAmountPositive.
  ///
  /// In zh, this message translates to:
  /// **'金额必须大于 0'**
  String get budgetAmountPositive;

  /// No description provided for @budgetCarryOver.
  ///
  /// In zh, this message translates to:
  /// **'开启结转'**
  String get budgetCarryOver;

  /// No description provided for @budgetCarryOverHint.
  ///
  /// In zh, this message translates to:
  /// **'未花完金额累加到下个周期'**
  String get budgetCarryOverHint;

  /// No description provided for @budgetDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除预算'**
  String get budgetDeleteConfirm;

  /// No description provided for @budgetDeleteHint.
  ///
  /// In zh, this message translates to:
  /// **'删除后将无法恢复，确定继续？'**
  String get budgetDeleteHint;

  /// No description provided for @budgetEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有预算\n点右下角加一个吧 🐱'**
  String get budgetEmptyHint;

  /// No description provided for @budgetTotal.
  ///
  /// In zh, this message translates to:
  /// **'总预算'**
  String get budgetTotal;

  /// No description provided for @budgetDeletedCategory.
  ///
  /// In zh, this message translates to:
  /// **'（已删除分类）'**
  String get budgetDeletedCategory;

  /// No description provided for @budgetCarryOverLabel.
  ///
  /// In zh, this message translates to:
  /// **' · 结转'**
  String get budgetCarryOverLabel;

  /// No description provided for @budgetAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可用 ¥{amount}'**
  String budgetAvailable(String amount);

  /// No description provided for @budgetSpentOverLimit.
  ///
  /// In zh, this message translates to:
  /// **'已花 ¥{spent} / ¥{limit}'**
  String budgetSpentOverLimit(String spent, String limit);

  /// No description provided for @budgetProgressCalculating.
  ///
  /// In zh, this message translates to:
  /// **'进度计算中…'**
  String get budgetProgressCalculating;

  /// No description provided for @budgetProgressFailed.
  ///
  /// In zh, this message translates to:
  /// **'进度计算失败：{error}'**
  String budgetProgressFailed(String error);

  /// No description provided for @budgetYearStartFrom.
  ///
  /// In zh, this message translates to:
  /// **'年起'**
  String get budgetYearStartFrom;

  /// No description provided for @budgetCarryStart.
  ///
  /// In zh, this message translates to:
  /// **'结转起始'**
  String get budgetCarryStart;

  /// No description provided for @budgetCarryStartHint.
  ///
  /// In zh, this message translates to:
  /// **'选择更早的月份可让那时之后的剩余结转到本月'**
  String get budgetCarryStartHint;

  /// No description provided for @budgetSelectCarryStartMonth.
  ///
  /// In zh, this message translates to:
  /// **'选择结转起始月份'**
  String get budgetSelectCarryStartMonth;

  /// No description provided for @accountEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑账户'**
  String get accountEditTitle;

  /// No description provided for @accountNewTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建账户'**
  String get accountNewTitle;

  /// No description provided for @accountNotExist.
  ///
  /// In zh, this message translates to:
  /// **'账户不存在'**
  String get accountNotExist;

  /// No description provided for @accountName.
  ///
  /// In zh, this message translates to:
  /// **'账户名称'**
  String get accountName;

  /// No description provided for @accountNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：现金、工商银行卡'**
  String get accountNameHint;

  /// No description provided for @accountNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入账户名称'**
  String get accountNameRequired;

  /// No description provided for @accountType.
  ///
  /// In zh, this message translates to:
  /// **'账户类型'**
  String get accountType;

  /// No description provided for @accountIconEmoji.
  ///
  /// In zh, this message translates to:
  /// **'图标 Emoji（可选）'**
  String get accountIconEmoji;

  /// No description provided for @accountIconEmojiHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 💰、💳、🏦'**
  String get accountIconEmojiHint;

  /// No description provided for @accountInitialBalance.
  ///
  /// In zh, this message translates to:
  /// **'初始余额'**
  String get accountInitialBalance;

  /// No description provided for @accountInitialBalanceHint.
  ///
  /// In zh, this message translates to:
  /// **'可为负（信用卡欠款填负值）'**
  String get accountInitialBalanceHint;

  /// No description provided for @accountBalanceInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入合法的数字'**
  String get accountBalanceInvalid;

  /// No description provided for @accountDefaultCurrency.
  ///
  /// In zh, this message translates to:
  /// **'默认币种'**
  String get accountDefaultCurrency;

  /// No description provided for @accountBillingDay.
  ///
  /// In zh, this message translates to:
  /// **'账单日（1-28）'**
  String get accountBillingDay;

  /// No description provided for @accountBillingDayHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 5'**
  String get accountBillingDayHint;

  /// No description provided for @accountRepaymentDay.
  ///
  /// In zh, this message translates to:
  /// **'还款日（1-28）'**
  String get accountRepaymentDay;

  /// No description provided for @accountRepaymentDayHint.
  ///
  /// In zh, this message translates to:
  /// **'例如 22'**
  String get accountRepaymentDayHint;

  /// No description provided for @accountIncludeInTotal.
  ///
  /// In zh, this message translates to:
  /// **'计入总资产'**
  String get accountIncludeInTotal;

  /// No description provided for @accountIncludeInTotalHint.
  ///
  /// In zh, this message translates to:
  /// **'关闭后该账户余额不参与总资产合计'**
  String get accountIncludeInTotalHint;

  /// No description provided for @accountDayRangeError.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1-28 的整数'**
  String get accountDayRangeError;

  /// No description provided for @accountCannotSave.
  ///
  /// In zh, this message translates to:
  /// **'账户不存在，无法保存'**
  String get accountCannotSave;

  /// No description provided for @accountListNew.
  ///
  /// In zh, this message translates to:
  /// **'新建账户'**
  String get accountListNew;

  /// No description provided for @accountDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除账户'**
  String get accountDeleteConfirmTitle;

  /// No description provided for @accountDeleteConfirmMsg.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除账户「{name}」吗？\\n\\n该账户下的流水将自动挂到「已删账户」占位。\\n删除后可在垃圾桶中保留 30 天。'**
  String accountDeleteConfirmMsg(String name);

  /// No description provided for @accountDeleted.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」已删除'**
  String accountDeleted(String name);

  /// No description provided for @accountTotalAssets.
  ///
  /// In zh, this message translates to:
  /// **'总资产（当前账本）'**
  String get accountTotalAssets;

  /// No description provided for @accountEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'还没有账户\n点右下角加一个吧 🐱'**
  String get accountEmptyHint;

  /// No description provided for @accountNotInTotal.
  ///
  /// In zh, this message translates to:
  /// **' · 不计入总资产'**
  String get accountNotInTotal;

  /// No description provided for @accountBillingDayDisplay.
  ///
  /// In zh, this message translates to:
  /// **'账单日 {day} 号'**
  String accountBillingDayDisplay(int day);

  /// No description provided for @accountRepaymentDayDisplay.
  ///
  /// In zh, this message translates to:
  /// **'还款日 {day} 号'**
  String accountRepaymentDayDisplay(int day);

  /// No description provided for @lockTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用锁'**
  String get lockTitle;

  /// No description provided for @lockEnterPin.
  ///
  /// In zh, this message translates to:
  /// **'请输入 PIN 解锁边边记账'**
  String get lockEnterPin;

  /// No description provided for @lockEnterCurrentPinToDisable.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前 PIN 以关闭应用锁'**
  String get lockEnterCurrentPinToDisable;

  /// No description provided for @lockEnterCurrentPinToVerify.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前 PIN 以验证身份'**
  String get lockEnterCurrentPinToVerify;

  /// No description provided for @lockForgotPin.
  ///
  /// In zh, this message translates to:
  /// **'忘记 PIN'**
  String get lockForgotPin;

  /// No description provided for @lockForgotPinMsg.
  ///
  /// In zh, this message translates to:
  /// **'忘记 PIN 后无法通过应用内方式重置。\n如需继续使用，只能：\n\n1. 清除本应用全部数据（卸载或清除数据），重新开始；\n2. 如有云端备份，重装后可恢复数据。\n\n请注意：清除数据将丢失所有本地记账内容。'**
  String get lockForgotPinMsg;

  /// No description provided for @lockAcknowledgeAndDisable.
  ///
  /// In zh, this message translates to:
  /// **'我已知晓，关闭应用锁'**
  String get lockAcknowledgeAndDisable;

  /// No description provided for @lockEnableAppLock.
  ///
  /// In zh, this message translates to:
  /// **'启用应用锁'**
  String get lockEnableAppLock;

  /// No description provided for @lockEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启 · PIN 已设置'**
  String get lockEnabled;

  /// No description provided for @lockDisabling.
  ///
  /// In zh, this message translates to:
  /// **'关闭中 · 启动 / 切回前台时不再要求 PIN'**
  String get lockDisabling;

  /// No description provided for @lockChangePin.
  ///
  /// In zh, this message translates to:
  /// **'修改 PIN'**
  String get lockChangePin;

  /// No description provided for @lockDisableHint.
  ///
  /// In zh, this message translates to:
  /// **'关闭应用锁；如需清空本地数据请先确认云端有最新备份'**
  String get lockDisableHint;

  /// No description provided for @lockSecurityNote.
  ///
  /// In zh, this message translates to:
  /// **'安全说明'**
  String get lockSecurityNote;

  /// No description provided for @lockSecurityNoteMsg.
  ///
  /// In zh, this message translates to:
  /// **'PIN 存储在设备安全硬件中（Android Keystore / iOS Keychain），以加盐哈希形式保存，无法被逆向读取。\n\n生物识别解锁由操作系统原生 API 提供认证，本应用不接触指纹/面容原始数据。\n\n后台超时锁屏依赖 App 生命周期事件，如果系统强制杀进程则无法触发。'**
  String get lockSecurityNoteMsg;

  /// No description provided for @lockVerifyBiometric.
  ///
  /// In zh, this message translates to:
  /// **'验证身份以启用生物识别解锁'**
  String get lockVerifyBiometric;

  /// No description provided for @lockBiometricEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get lockBiometricEnabled;

  /// No description provided for @lockBiometricCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消，未启用生物识别'**
  String get lockBiometricCancelled;

  /// No description provided for @lockBiometricLockedOut.
  ///
  /// In zh, this message translates to:
  /// **'生物识别被系统临时锁定，请稍后再试'**
  String get lockBiometricLockedOut;

  /// No description provided for @lockBiometricNotAvailable.
  ///
  /// In zh, this message translates to:
  /// **'当前设备暂不可用'**
  String get lockBiometricNotAvailable;

  /// No description provided for @lockBiometricNotRecognized.
  ///
  /// In zh, this message translates to:
  /// **'验证未通过，未启用生物识别'**
  String get lockBiometricNotRecognized;

  /// No description provided for @lockBiometricTitle.
  ///
  /// In zh, this message translates to:
  /// **'生物识别'**
  String get lockBiometricTitle;

  /// No description provided for @lockBiometricDetecting.
  ///
  /// In zh, this message translates to:
  /// **'正在检测设备…'**
  String get lockBiometricDetecting;

  /// No description provided for @lockBiometricDetectFailed.
  ///
  /// In zh, this message translates to:
  /// **'检测失败：{error}'**
  String lockBiometricDetectFailed(String error);

  /// No description provided for @lockBiometricNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'本设备不支持生物识别'**
  String get lockBiometricNotSupported;

  /// No description provided for @lockBiometricNotEnrolled.
  ///
  /// In zh, this message translates to:
  /// **'请先在系统设置录入指纹 / 面容'**
  String get lockBiometricNotEnrolled;

  /// No description provided for @lockBiometricReadingPrefs.
  ///
  /// In zh, this message translates to:
  /// **'正在读取偏好…'**
  String get lockBiometricReadingPrefs;

  /// No description provided for @lockBiometricEnabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'已开启 · 解锁时优先弹出系统面板'**
  String get lockBiometricEnabledDesc;

  /// No description provided for @lockBiometricDisabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'解锁时仅使用 PIN（开启需要先验证一次）'**
  String get lockBiometricDisabledDesc;

  /// No description provided for @lockLockNow.
  ///
  /// In zh, this message translates to:
  /// **'立即锁定'**
  String get lockLockNow;

  /// No description provided for @lockSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒'**
  String lockSeconds(int count);

  /// No description provided for @lockMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟'**
  String lockMinutes(int count);

  /// No description provided for @lockHours.
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时'**
  String lockHours(int count);

  /// No description provided for @lockBackgroundTimeout.
  ///
  /// In zh, this message translates to:
  /// **'后台超时锁定'**
  String get lockBackgroundTimeout;

  /// No description provided for @lockLockNowDesc.
  ///
  /// In zh, this message translates to:
  /// **'立即锁定 · 任何后台→前台切换都会要求 PIN'**
  String get lockLockNowDesc;

  /// No description provided for @lockTimeoutDesc.
  ///
  /// In zh, this message translates to:
  /// **'{label} · 后台超过该时长后回到前台需要 PIN'**
  String lockTimeoutDesc(String label);

  /// No description provided for @lockPrivacyMode.
  ///
  /// In zh, this message translates to:
  /// **'隐私模式'**
  String get lockPrivacyMode;

  /// No description provided for @lockPrivacyEnabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'已开启 · 多任务预览模糊 + Android 阻止截屏'**
  String get lockPrivacyEnabledDesc;

  /// No description provided for @lockPrivacyDisabledDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭中 · 多任务切换器可见 App 当前画面'**
  String get lockPrivacyDisabledDesc;

  /// No description provided for @pinSetupNew.
  ///
  /// In zh, this message translates to:
  /// **'设置应用锁 PIN'**
  String get pinSetupNew;

  /// No description provided for @pinSetupChange.
  ///
  /// In zh, this message translates to:
  /// **'修改应用锁 PIN'**
  String get pinSetupChange;

  /// No description provided for @pinSetupHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 {min}-{max} 位数字 PIN，避免使用生日等易猜组合。'**
  String pinSetupHint(int min, int max);

  /// No description provided for @pinSetupConfirmHint.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入相同 PIN 以确认。'**
  String get pinSetupConfirmHint;

  /// No description provided for @pinSetupMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入不一致，请重新设置'**
  String get pinSetupMismatch;

  /// No description provided for @pinNewLabel.
  ///
  /// In zh, this message translates to:
  /// **'新 PIN'**
  String get pinNewLabel;

  /// No description provided for @pinConfirmLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认 PIN'**
  String get pinConfirmLabel;

  /// No description provided for @pinValidationError.
  ///
  /// In zh, this message translates to:
  /// **'PIN 必须为 {min}-{max} 位数字'**
  String pinValidationError(int min, int max);

  /// No description provided for @pinDigitsOnly.
  ///
  /// In zh, this message translates to:
  /// **'PIN 仅允许数字'**
  String get pinDigitsOnly;

  /// No description provided for @pinUnlockTitle.
  ///
  /// In zh, this message translates to:
  /// **'请输入应用锁 PIN'**
  String get pinUnlockTitle;

  /// No description provided for @pinUnlockBiometricVerify.
  ///
  /// In zh, this message translates to:
  /// **'验证身份以解锁边边记账'**
  String get pinUnlockBiometricVerify;

  /// No description provided for @pinUnlockBiometricLockedOut.
  ///
  /// In zh, this message translates to:
  /// **'生物识别已被系统临时锁定，请改用 PIN'**
  String get pinUnlockBiometricLockedOut;

  /// No description provided for @pinUnlockBiometricUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'生物识别暂不可用，请改用 PIN'**
  String get pinUnlockBiometricUnavailable;

  /// No description provided for @pinUnlockBiometricFailed.
  ///
  /// In zh, this message translates to:
  /// **'生物识别未通过，请改用 PIN'**
  String get pinUnlockBiometricFailed;

  /// No description provided for @pinUnlockTooManyErrors.
  ///
  /// In zh, this message translates to:
  /// **'错误次数过多，已进入冷却'**
  String get pinUnlockTooManyErrors;

  /// No description provided for @pinUnlockAttemptsLeft.
  ///
  /// In zh, this message translates to:
  /// **'PIN 错误，剩余尝试次数 {left}'**
  String pinUnlockAttemptsLeft(int left);

  /// No description provided for @pinUnlockCooldown.
  ///
  /// In zh, this message translates to:
  /// **'冷却中（{seconds} 秒）'**
  String pinUnlockCooldown(int seconds);

  /// No description provided for @pinUnlockBiometricHint.
  ///
  /// In zh, this message translates to:
  /// **'请按提示完成生物识别…'**
  String get pinUnlockBiometricHint;

  /// No description provided for @pinUnlockBiometricButton.
  ///
  /// In zh, this message translates to:
  /// **'使用指纹 / 面容解锁'**
  String get pinUnlockBiometricButton;

  /// No description provided for @importExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入 / 导出'**
  String get importExportTitle;

  /// No description provided for @importExportExport.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get importExportExport;

  /// No description provided for @importExportExportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'CSV / JSON / 加密 .bbbak'**
  String get importExportExportSubtitle;

  /// No description provided for @importExportImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importExportImport;

  /// No description provided for @importExportImportSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持本 App 导出的 JSON / CSV / .bbbak'**
  String get importExportImportSubtitle;

  /// No description provided for @exportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get exportTitle;

  /// No description provided for @exportFormat.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get exportFormat;

  /// No description provided for @exportEncrypted.
  ///
  /// In zh, this message translates to:
  /// **'加密'**
  String get exportEncrypted;

  /// No description provided for @exportRange.
  ///
  /// In zh, this message translates to:
  /// **'范围'**
  String get exportRange;

  /// No description provided for @exportCurrentLedger.
  ///
  /// In zh, this message translates to:
  /// **'当前账本'**
  String get exportCurrentLedger;

  /// No description provided for @exportAllLedgers.
  ///
  /// In zh, this message translates to:
  /// **'全部账本'**
  String get exportAllLedgers;

  /// No description provided for @exportCurrentLedgerHint.
  ///
  /// In zh, this message translates to:
  /// **'仅当前选中账本'**
  String get exportCurrentLedgerHint;

  /// No description provided for @exportAllLedgersHint.
  ///
  /// In zh, this message translates to:
  /// **'包含所有未删除账本(含归档)'**
  String get exportAllLedgersHint;

  /// No description provided for @exportTimeRange.
  ///
  /// In zh, this message translates to:
  /// **'时间区间'**
  String get exportTimeRange;

  /// No description provided for @exportAllTime.
  ///
  /// In zh, this message translates to:
  /// **'全部时间'**
  String get exportAllTime;

  /// No description provided for @exportCustomTime.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get exportCustomTime;

  /// No description provided for @exporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导出…'**
  String get exporting;

  /// No description provided for @exportAndShare.
  ///
  /// In zh, this message translates to:
  /// **'导出并分享'**
  String get exportAndShare;

  /// No description provided for @exportCsvDesc.
  ///
  /// In zh, this message translates to:
  /// **'Excel / Numbers 直接打开'**
  String get exportCsvDesc;

  /// No description provided for @exportJsonDesc.
  ///
  /// In zh, this message translates to:
  /// **'结构化全量备份(可被「导入」恢复)'**
  String get exportJsonDesc;

  /// No description provided for @exportBbbakDesc.
  ///
  /// In zh, this message translates to:
  /// **'加密备份包(.bbbak)：JSON + AES-256 密码加密，仅本 App 能导入'**
  String get exportBbbakDesc;

  /// No description provided for @exportPasswordWarning.
  ///
  /// In zh, this message translates to:
  /// **'该密码用于解密备份。一旦丢失，备份内容将永远无法恢复——请使用密码管理器记录或写在安全的纸上，不要只存在脑子里。'**
  String get exportPasswordWarning;

  /// No description provided for @exportPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get exportPassword;

  /// No description provided for @exportShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get exportShowPassword;

  /// No description provided for @exportHidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get exportHidePassword;

  /// No description provided for @exportReEnterPassword.
  ///
  /// In zh, this message translates to:
  /// **'再次输入密码'**
  String get exportReEnterPassword;

  /// No description provided for @exportPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入不一致'**
  String get exportPasswordMismatch;

  /// No description provided for @exportCurrentLedgerNotExist.
  ///
  /// In zh, this message translates to:
  /// **'当前账本不存在'**
  String get exportCurrentLedgerNotExist;

  /// No description provided for @exportNoLedgerToExport.
  ///
  /// In zh, this message translates to:
  /// **'没有可导出的账本'**
  String get exportNoLedgerToExport;

  /// No description provided for @exportedFile.
  ///
  /// In zh, this message translates to:
  /// **'已导出：{filename}'**
  String exportedFile(String filename);

  /// No description provided for @exportShareSubject.
  ///
  /// In zh, this message translates to:
  /// **'边边记账导出'**
  String get exportShareSubject;

  /// No description provided for @exportShareText.
  ///
  /// In zh, this message translates to:
  /// **'边边记账数据导出 ({format})'**
  String exportShareText(String format);

  /// No description provided for @importTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get importTitle;

  /// No description provided for @importWritingDb.
  ///
  /// In zh, this message translates to:
  /// **'正在写入数据库…'**
  String get importWritingDb;

  /// No description provided for @importSupportedFormats.
  ///
  /// In zh, this message translates to:
  /// **'支持的文件格式'**
  String get importSupportedFormats;

  /// No description provided for @importJsonDesc.
  ///
  /// In zh, this message translates to:
  /// **'JSON：本 App 导出的结构化备份（推荐）'**
  String get importJsonDesc;

  /// No description provided for @importBbbakDesc.
  ///
  /// In zh, this message translates to:
  /// **'.bbbak：本 App 导出的加密备份（需要密码）'**
  String get importBbbakDesc;

  /// No description provided for @importCsvDesc.
  ///
  /// In zh, this message translates to:
  /// **'CSV：本 App 导出的表格（按账本名匹配）'**
  String get importCsvDesc;

  /// No description provided for @importThirdPartyDesc.
  ///
  /// In zh, this message translates to:
  /// **'第三方账单：钱迹 / 微信 / 支付宝 CSV（自动识别）'**
  String get importThirdPartyDesc;

  /// No description provided for @importThirdPartyTip.
  ///
  /// In zh, this message translates to:
  /// **'提示：第三方账单会被识别为单一账本，自动归入当前账本；分类按关键词推测，不能命中的归到「其他」。'**
  String get importThirdPartyTip;

  /// No description provided for @importSelectFile.
  ///
  /// In zh, this message translates to:
  /// **'选择备份文件'**
  String get importSelectFile;

  /// No description provided for @importFilePathError.
  ///
  /// In zh, this message translates to:
  /// **'文件路径不可读'**
  String get importFilePathError;

  /// No description provided for @importSelectFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择文件失败：{error}'**
  String importSelectFileFailed(String error);

  /// No description provided for @importSelectedFile.
  ///
  /// In zh, this message translates to:
  /// **'已选择：{name}'**
  String importSelectedFile(String name);

  /// No description provided for @importEncryptedFileHint.
  ///
  /// In zh, this message translates to:
  /// **'此文件已加密。请输入导出时设置的密码。'**
  String get importEncryptedFileHint;

  /// No description provided for @importPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get importPassword;

  /// No description provided for @importDecryptAndPreview.
  ///
  /// In zh, this message translates to:
  /// **'解密并预览'**
  String get importDecryptAndPreview;

  /// No description provided for @importInternalError.
  ///
  /// In zh, this message translates to:
  /// **'内部状态错误：缺少文件字节或类型'**
  String get importInternalError;

  /// No description provided for @importPasswordWrong.
  ///
  /// In zh, this message translates to:
  /// **'密码错误。请检查密码是否正确，或文件是否被损坏。'**
  String get importPasswordWrong;

  /// No description provided for @importFormatUnrecognized.
  ///
  /// In zh, this message translates to:
  /// **'文件格式不识别（{message}）。请检查是否选错文件。'**
  String importFormatUnrecognized(String message);

  /// No description provided for @importParseFailed.
  ///
  /// In zh, this message translates to:
  /// **'解析失败：{error}'**
  String importParseFailed(String error);

  /// No description provided for @importFileLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get importFileLabel;

  /// No description provided for @importRecognizedAs.
  ///
  /// In zh, this message translates to:
  /// **'识别为'**
  String get importRecognizedAs;

  /// No description provided for @importLedgerCount.
  ///
  /// In zh, this message translates to:
  /// **'账本数'**
  String get importLedgerCount;

  /// No description provided for @importTxCount.
  ///
  /// In zh, this message translates to:
  /// **'流水数'**
  String get importTxCount;

  /// No description provided for @importUnmappedCategoryTip.
  ///
  /// In zh, this message translates to:
  /// **'其中 {count} 条按关键词未匹配到本地分类，已归入「其他」。'**
  String importUnmappedCategoryTip(int count);

  /// No description provided for @importExportTime.
  ///
  /// In zh, this message translates to:
  /// **'导出时间'**
  String get importExportTime;

  /// No description provided for @importSourceDevice.
  ///
  /// In zh, this message translates to:
  /// **'来源设备'**
  String get importSourceDevice;

  /// No description provided for @importSampleRows.
  ///
  /// In zh, this message translates to:
  /// **'前 {count} 行预览'**
  String importSampleRows(int count);

  /// No description provided for @importNoTxInBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份内不含流水'**
  String get importNoTxInBackup;

  /// No description provided for @importDedupStrategy.
  ///
  /// In zh, this message translates to:
  /// **'去重策略'**
  String get importDedupStrategy;

  /// No description provided for @importDedupSkip.
  ///
  /// In zh, this message translates to:
  /// **'跳过已存在'**
  String get importDedupSkip;

  /// No description provided for @importDedupSkipDesc.
  ///
  /// In zh, this message translates to:
  /// **'ID 相同时跳过，不覆盖已有数据（最安全）'**
  String get importDedupSkipDesc;

  /// No description provided for @importDedupOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖'**
  String get importDedupOverwrite;

  /// No description provided for @importDedupOverwriteDesc.
  ///
  /// In zh, this message translates to:
  /// **'ID 相同时用备份覆盖本地（备份优先）'**
  String get importDedupOverwriteDesc;

  /// No description provided for @importDedupAllNew.
  ///
  /// In zh, this message translates to:
  /// **'全部作为新记录'**
  String get importDedupAllNew;

  /// No description provided for @importDedupAllNewDesc.
  ///
  /// In zh, this message translates to:
  /// **'忽略 ID，所有记录重新生成 ID 写入（可能产生重复）'**
  String get importDedupAllNewDesc;

  /// No description provided for @importConfirmImport.
  ///
  /// In zh, this message translates to:
  /// **'确认导入'**
  String get importConfirmImport;

  /// No description provided for @importWriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'写入失败：{error}'**
  String importWriteFailed(String error);

  /// No description provided for @importComplete.
  ///
  /// In zh, this message translates to:
  /// **'导入完成'**
  String get importComplete;

  /// No description provided for @importUpsertCount.
  ///
  /// In zh, this message translates to:
  /// **'{label}'**
  String importUpsertCount(String label);

  /// No description provided for @importLedgerUpsert.
  ///
  /// In zh, this message translates to:
  /// **'账本 {count} 条 upsert'**
  String importLedgerUpsert(int count);

  /// No description provided for @importCategoryUpsert.
  ///
  /// In zh, this message translates to:
  /// **'分类 {count} 条 upsert'**
  String importCategoryUpsert(int count);

  /// No description provided for @importAccountUpsert.
  ///
  /// In zh, this message translates to:
  /// **'账户 {count} 条 upsert'**
  String importAccountUpsert(int count);

  /// No description provided for @importTxWrite.
  ///
  /// In zh, this message translates to:
  /// **'流水 {written} 条写入 / {skipped} 条跳过'**
  String importTxWrite(int written, int skipped);

  /// No description provided for @importBudgetUpsert.
  ///
  /// In zh, this message translates to:
  /// **'预算 {count} 条 upsert'**
  String importBudgetUpsert(int count);

  /// No description provided for @importLedgerNotMatched.
  ///
  /// In zh, this message translates to:
  /// **'提示：账本「{name}」未匹配到，已归入当前账本。'**
  String importLedgerNotMatched(String name);

  /// No description provided for @importContinueOther.
  ///
  /// In zh, this message translates to:
  /// **'继续导入其他文件'**
  String get importContinueOther;

  /// No description provided for @importUnknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get importUnknownError;

  /// No description provided for @importReselect.
  ///
  /// In zh, this message translates to:
  /// **'重新选择'**
  String get importReselect;

  /// No description provided for @importBbbakLabel.
  ///
  /// In zh, this message translates to:
  /// **'加密备份 (.bbbak)'**
  String get importBbbakLabel;

  /// No description provided for @syncTitle.
  ///
  /// In zh, this message translates to:
  /// **'云服务'**
  String get syncTitle;

  /// No description provided for @syncEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用云同步'**
  String get syncEnable;

  /// No description provided for @syncCurrentBackend.
  ///
  /// In zh, this message translates to:
  /// **'当前后端：{name}'**
  String syncCurrentBackend(String name);

  /// No description provided for @syncDisabled.
  ///
  /// In zh, this message translates to:
  /// **'关闭中——数据仅保存在本机'**
  String get syncDisabled;

  /// No description provided for @syncSelfHostedWebdav.
  ///
  /// In zh, this message translates to:
  /// **'自托管 WebDAV 服务'**
  String get syncSelfHostedWebdav;

  /// No description provided for @syncS3Compatible.
  ///
  /// In zh, this message translates to:
  /// **'S3 兼容存储'**
  String get syncS3Compatible;

  /// No description provided for @syncS3Desc.
  ///
  /// In zh, this message translates to:
  /// **'Cloudflare R2, AWS S3, MinIO 等'**
  String get syncS3Desc;

  /// No description provided for @syncUseSupabase.
  ///
  /// In zh, this message translates to:
  /// **'使用 Supabase 后端'**
  String get syncUseSupabase;

  /// No description provided for @syncLastTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'上次连接测试失败，点击右侧设置重新配置'**
  String get syncLastTestFailed;

  /// No description provided for @syncNotConfiguredShort.
  ///
  /// In zh, this message translates to:
  /// **'（未配置）'**
  String get syncNotConfiguredShort;

  /// No description provided for @syncUseIcloud.
  ///
  /// In zh, this message translates to:
  /// **'使用 iCloud Drive 同步'**
  String get syncUseIcloud;

  /// No description provided for @syncIcloudUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'iCloud 不可用，请检查系统设置'**
  String get syncIcloudUnavailable;

  /// No description provided for @syncSwitchConfirm.
  ///
  /// In zh, this message translates to:
  /// **'切换云服务?'**
  String get syncSwitchConfirm;

  /// No description provided for @syncSwitchHint.
  ///
  /// In zh, this message translates to:
  /// **'切换服务后，需要重新进行首次同步。'**
  String get syncSwitchHint;

  /// No description provided for @syncMigrateAttachments.
  ///
  /// In zh, this message translates to:
  /// **'迁移附件到新后端？'**
  String get syncMigrateAttachments;

  /// No description provided for @syncMigrateAttachmentsHint.
  ///
  /// In zh, this message translates to:
  /// **'迁移会将已上传的附件从旧后端下载后重新上传到新后端。此过程可能耗时较长，取决于附件数量与网络状况。\n\n如果选择「暂不迁移」，已上传的附件仍保留在旧后端，新上传的附件会存到新后端。'**
  String get syncMigrateAttachmentsHint;

  /// No description provided for @syncSkipMigration.
  ///
  /// In zh, this message translates to:
  /// **'暂不迁移'**
  String get syncSkipMigration;

  /// No description provided for @syncMigrate.
  ///
  /// In zh, this message translates to:
  /// **'迁移'**
  String get syncMigrate;

  /// No description provided for @syncSwitchNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'切换失败：{type} 尚未配置，请先点击右侧设置图标完成配置'**
  String syncSwitchNotConfigured(String type);

  /// No description provided for @syncSwitchedWithMigration.
  ///
  /// In zh, this message translates to:
  /// **'已切换到 {type}（已标记 {migrated} 条流水的附件待重传）'**
  String syncSwitchedWithMigration(String type, int migrated);

  /// No description provided for @syncSwitched.
  ///
  /// In zh, this message translates to:
  /// **'已切换到 {type}'**
  String syncSwitched(String type);

  /// No description provided for @syncDisableConfirm.
  ///
  /// In zh, this message translates to:
  /// **'关闭云同步?'**
  String get syncDisableConfirm;

  /// No description provided for @syncDisableHint.
  ///
  /// In zh, this message translates to:
  /// **'关闭后将仅使用本机数据，已上传到云端的备份不受影响。'**
  String get syncDisableHint;

  /// No description provided for @syncCloudDisabled.
  ///
  /// In zh, this message translates to:
  /// **'云同步已关闭'**
  String get syncCloudDisabled;

  /// No description provided for @syncPleaseConfigureFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先在下方任选一个云服务并完成配置'**
  String get syncPleaseConfigureFirst;

  /// No description provided for @syncEnabledWith.
  ///
  /// In zh, this message translates to:
  /// **'已启用云同步：{type}'**
  String syncEnabledWith(String type);

  /// No description provided for @syncLocalStorage.
  ///
  /// In zh, this message translates to:
  /// **'本地存储'**
  String get syncLocalStorage;

  /// No description provided for @syncConfigSavedAndTested.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存并通过连接测试'**
  String get syncConfigSavedAndTested;

  /// No description provided for @syncConfigSavedTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存，但连接测试失败：{error}'**
  String syncConfigSavedTestFailed(String error);

  /// No description provided for @syncConfigInvalid.
  ///
  /// In zh, this message translates to:
  /// **'配置无效'**
  String get syncConfigInvalid;

  /// No description provided for @syncProviderInitNull.
  ///
  /// In zh, this message translates to:
  /// **'Provider 初始化返回空'**
  String get syncProviderInitNull;

  /// No description provided for @syncConfigSupabase.
  ///
  /// In zh, this message translates to:
  /// **'配置 Supabase'**
  String get syncConfigSupabase;

  /// No description provided for @syncCustomName.
  ///
  /// In zh, this message translates to:
  /// **'自定义名称'**
  String get syncCustomName;

  /// No description provided for @syncCustomNameHint.
  ///
  /// In zh, this message translates to:
  /// **'用作卡片标题（可选）'**
  String get syncCustomNameHint;

  /// No description provided for @syncConfigWebdav.
  ///
  /// In zh, this message translates to:
  /// **'配置 WebDAV'**
  String get syncConfigWebdav;

  /// No description provided for @syncWebdavUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get syncWebdavUsername;

  /// No description provided for @syncWebdavPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get syncWebdavPassword;

  /// No description provided for @syncWebdavRemotePath.
  ///
  /// In zh, this message translates to:
  /// **'远程路径'**
  String get syncWebdavRemotePath;

  /// No description provided for @syncConfigS3.
  ///
  /// In zh, this message translates to:
  /// **'配置 S3'**
  String get syncConfigS3;

  /// No description provided for @syncS3CustomNameHint.
  ///
  /// In zh, this message translates to:
  /// **'用作卡片标题与云端文件夹名（可选）'**
  String get syncS3CustomNameHint;

  /// No description provided for @syncLedgerLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'账本加载失败：{error}'**
  String syncLedgerLoadFailed(String error);

  /// No description provided for @syncInitFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步服务初始化失败：{error}'**
  String syncInitFailed(String error);

  /// No description provided for @syncUploaded.
  ///
  /// In zh, this message translates to:
  /// **'已上传到云端'**
  String get syncUploaded;

  /// No description provided for @syncRestoreFromCloud.
  ///
  /// In zh, this message translates to:
  /// **'从云端恢复'**
  String get syncRestoreFromCloud;

  /// No description provided for @syncRestoreConfirmMsg.
  ///
  /// In zh, this message translates to:
  /// **'当前账本的本地流水与预算将被云端备份覆盖...'**
  String get syncRestoreConfirmMsg;

  /// No description provided for @syncRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get syncRestore;

  /// No description provided for @syncRestoredCount.
  ///
  /// In zh, this message translates to:
  /// **'已恢复 {count} 条流水'**
  String syncRestoredCount(int count);

  /// No description provided for @syncRestored.
  ///
  /// In zh, this message translates to:
  /// **'已从云端恢复'**
  String get syncRestored;

  /// No description provided for @syncDeleteCloudBackup.
  ///
  /// In zh, this message translates to:
  /// **'删除云端备份'**
  String get syncDeleteCloudBackup;

  /// No description provided for @syncDeleteCloudConfirm.
  ///
  /// In zh, this message translates to:
  /// **'云端的此账本备份将被删除。本地数据不受影响。继续？'**
  String get syncDeleteCloudConfirm;

  /// No description provided for @syncCloudDeleted.
  ///
  /// In zh, this message translates to:
  /// **'云端备份已删除'**
  String get syncCloudDeleted;

  /// No description provided for @syncRefreshStatus.
  ///
  /// In zh, this message translates to:
  /// **'刷新状态'**
  String get syncRefreshStatus;

  /// No description provided for @syncFetchingStatus.
  ///
  /// In zh, this message translates to:
  /// **'正在获取云端状态…'**
  String get syncFetchingStatus;

  /// No description provided for @syncStatusFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'状态获取失败：{error}'**
  String syncStatusFetchFailed(String error);

  /// No description provided for @syncUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传'**
  String get syncUpload;

  /// No description provided for @syncDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get syncDownload;

  /// No description provided for @syncDeleteCloudBackupShort.
  ///
  /// In zh, this message translates to:
  /// **'删除云端备份'**
  String get syncDeleteCloudBackupShort;

  /// No description provided for @syncStatusNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get syncStatusNotConfigured;

  /// No description provided for @syncStatusNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get syncStatusNotLoggedIn;

  /// No description provided for @syncStatusNoBackup.
  ///
  /// In zh, this message translates to:
  /// **'云端无备份'**
  String get syncStatusNoBackup;

  /// No description provided for @syncStatusSynced.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusLocalNewer.
  ///
  /// In zh, this message translates to:
  /// **'本地较新（建议上传）'**
  String get syncStatusLocalNewer;

  /// No description provided for @syncStatusCloudNewer.
  ///
  /// In zh, this message translates to:
  /// **'云端较新（建议下载）'**
  String get syncStatusCloudNewer;

  /// No description provided for @syncStatusDiverged.
  ///
  /// In zh, this message translates to:
  /// **'本地与云端不一致'**
  String get syncStatusDiverged;

  /// No description provided for @syncStatusUploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中…'**
  String get syncStatusUploading;

  /// No description provided for @syncStatusDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中…'**
  String get syncStatusDownloading;

  /// No description provided for @syncStatusError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get syncStatusError;

  /// No description provided for @syncStatusUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get syncStatusUnknown;

  /// No description provided for @syncLastSyncAt.
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String syncLastSyncAt(String time);

  /// No description provided for @syncLocalCloudCount.
  ///
  /// In zh, this message translates to:
  /// **'本地 {local} · 云端 {cloud}'**
  String syncLocalCloudCount(int local, int cloud);

  /// No description provided for @syncTriggerInProgress.
  ///
  /// In zh, this message translates to:
  /// **'同步进行中'**
  String get syncTriggerInProgress;

  /// No description provided for @syncTriggerNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置云服务'**
  String get syncTriggerNotConfigured;

  /// No description provided for @syncTriggerNetworkUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'网络不可用'**
  String get syncTriggerNetworkUnavailable;

  /// No description provided for @trashTitle.
  ///
  /// In zh, this message translates to:
  /// **'垃圾桶'**
  String get trashTitle;

  /// No description provided for @reminderTitle.
  ///
  /// In zh, this message translates to:
  /// **'提醒'**
  String get reminderTitle;

  /// No description provided for @reminderDailyTitle.
  ///
  /// In zh, this message translates to:
  /// **'每日记账提醒'**
  String get reminderDailyTitle;

  /// No description provided for @reminderDailyOn.
  ///
  /// In zh, this message translates to:
  /// **'每天 {time} 提醒你记一笔'**
  String reminderDailyOn(String time);

  /// No description provided for @reminderOff.
  ///
  /// In zh, this message translates to:
  /// **'未开启'**
  String get reminderOff;

  /// No description provided for @reminderTime.
  ///
  /// In zh, this message translates to:
  /// **'提醒时间'**
  String get reminderTime;

  /// No description provided for @reminderTest.
  ///
  /// In zh, this message translates to:
  /// **'测试提醒'**
  String get reminderTest;

  /// No description provided for @reminderTestHint.
  ///
  /// In zh, this message translates to:
  /// **'立即发送一条测试通知'**
  String get reminderTestHint;

  /// No description provided for @reminderEnableHint.
  ///
  /// In zh, this message translates to:
  /// **'开启后，每天在设定时间会收到一条可爱的记账提醒 🐻\n如果通知没有按时出现，请检查系统通知权限设置。'**
  String get reminderEnableHint;

  /// No description provided for @reminderPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'通知权限被拒绝，无法开启提醒'**
  String get reminderPermissionDenied;

  /// No description provided for @reminderSelectTime.
  ///
  /// In zh, this message translates to:
  /// **'选择提醒时间'**
  String get reminderSelectTime;

  /// No description provided for @reminderEnabledAt.
  ///
  /// In zh, this message translates to:
  /// **'已开启，每天 {time} 提醒你'**
  String reminderEnabledAt(String time);

  /// No description provided for @reminderDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭每日提醒'**
  String get reminderDisabled;

  /// No description provided for @reminderTimeUpdated.
  ///
  /// In zh, this message translates to:
  /// **'提醒时间已更新为 {time}'**
  String reminderTimeUpdated(String time);

  /// No description provided for @reminderTestSent.
  ///
  /// In zh, this message translates to:
  /// **'测试通知已发送 🐻'**
  String get reminderTestSent;

  /// No description provided for @reminderNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'每日记账提醒'**
  String get reminderNotificationTitle;

  /// No description provided for @reminderNotificationBody.
  ///
  /// In zh, this message translates to:
  /// **'每天定时提醒你记一笔'**
  String get reminderNotificationBody;

  /// No description provided for @reminderTestNotification.
  ///
  /// In zh, this message translates to:
  /// **'这是一条测试提醒 🐻 记账时间到啦！'**
  String get reminderTestNotification;

  /// No description provided for @widgetAppName.
  ///
  /// In zh, this message translates to:
  /// **'边边记账'**
  String get widgetAppName;

  /// No description provided for @attachmentNotSynced.
  ///
  /// In zh, this message translates to:
  /// **'未同步'**
  String get attachmentNotSynced;

  /// No description provided for @attachmentCacheTitle.
  ///
  /// In zh, this message translates to:
  /// **'附件缓存'**
  String get attachmentCacheTitle;

  /// No description provided for @attachmentCacheCurrentUsage.
  ///
  /// In zh, this message translates to:
  /// **'当前占用'**
  String get attachmentCacheCurrentUsage;

  /// No description provided for @attachmentCacheCalculating.
  ///
  /// In zh, this message translates to:
  /// **'计算中…'**
  String get attachmentCacheCalculating;

  /// No description provided for @attachmentCacheUsage.
  ///
  /// In zh, this message translates to:
  /// **'{used} / {limit} 上限'**
  String attachmentCacheUsage(String used, String limit);

  /// No description provided for @attachmentCacheClear.
  ///
  /// In zh, this message translates to:
  /// **'清除缓存'**
  String get attachmentCacheClear;

  /// No description provided for @attachmentCacheClearDesc.
  ///
  /// In zh, this message translates to:
  /// **'删除本地缓存的附件文件，不影响原图与云端备份'**
  String get attachmentCacheClearDesc;

  /// No description provided for @attachmentCacheClearConfirm.
  ///
  /// In zh, this message translates to:
  /// **'清除附件缓存？'**
  String get attachmentCacheClearConfirm;

  /// No description provided for @attachmentCacheClearConfirmMsg.
  ///
  /// In zh, this message translates to:
  /// **'只删除本地缓存文件，不影响您原始保存的图片与云端备份。下次查看流水时会重新从云端下载。'**
  String get attachmentCacheClearConfirmMsg;

  /// No description provided for @attachmentCacheCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除约 {size}'**
  String attachmentCacheCleared(String size);

  /// No description provided for @attachmentCacheLazyLoadDesc.
  ///
  /// In zh, this message translates to:
  /// **'附件懒加载：仅当查看流水详情时才从云端下载图片，节省流量。系统在空间紧张时会自动清理缓存目录，下次查看会重新下载。'**
  String get attachmentCacheLazyLoadDesc;

  /// No description provided for @multiCurrencyTitle.
  ///
  /// In zh, this message translates to:
  /// **'多币种'**
  String get multiCurrencyTitle;

  /// No description provided for @multiCurrencyRefreshNow.
  ///
  /// In zh, this message translates to:
  /// **'立即刷新汇率'**
  String get multiCurrencyRefreshNow;

  /// No description provided for @multiCurrencyRefreshed.
  ///
  /// In zh, this message translates to:
  /// **'汇率已更新'**
  String get multiCurrencyRefreshed;

  /// No description provided for @multiCurrencyRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'联网失败，使用现有快照'**
  String get multiCurrencyRefreshFailed;

  /// No description provided for @multiCurrencyAutoRestored.
  ///
  /// In zh, this message translates to:
  /// **'{code} 已恢复自动刷新'**
  String multiCurrencyAutoRestored(String code);

  /// No description provided for @multiCurrencyManualSet.
  ///
  /// In zh, this message translates to:
  /// **'{code} 汇率已手动设为 {rate}'**
  String multiCurrencyManualSet(String code, String rate);

  /// No description provided for @multiCurrencyEnable.
  ///
  /// In zh, this message translates to:
  /// **'开启多币种'**
  String get multiCurrencyEnable;

  /// No description provided for @multiCurrencyEnableHint.
  ///
  /// In zh, this message translates to:
  /// **'开启后，记账页可选择币种；统计按账本默认币种换算展示。'**
  String get multiCurrencyEnableHint;

  /// No description provided for @multiCurrencyBuiltIn.
  ///
  /// In zh, this message translates to:
  /// **'内置币种'**
  String get multiCurrencyBuiltIn;

  /// No description provided for @multiCurrencyRateManagement.
  ///
  /// In zh, this message translates to:
  /// **'汇率管理'**
  String get multiCurrencyRateManagement;

  /// No description provided for @multiCurrencyRateHint.
  ///
  /// In zh, this message translates to:
  /// **'点击行可手动设置汇率；标记为「手动」的行不会被自动刷新覆盖。'**
  String get multiCurrencyRateHint;

  /// No description provided for @multiCurrencyBase.
  ///
  /// In zh, this message translates to:
  /// **'基准'**
  String get multiCurrencyBase;

  /// No description provided for @multiCurrencyManual.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get multiCurrencyManual;

  /// No description provided for @multiCurrencyAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get multiCurrencyAuto;

  /// No description provided for @multiCurrencyUpdatedAt.
  ///
  /// In zh, this message translates to:
  /// **'更新于 {time}'**
  String multiCurrencyUpdatedAt(String time);

  /// No description provided for @multiCurrencyInputPositive.
  ///
  /// In zh, this message translates to:
  /// **'请输入正数（例如 7.20）'**
  String get multiCurrencyInputPositive;

  /// No description provided for @multiCurrencySetRate.
  ///
  /// In zh, this message translates to:
  /// **'设置 {code} 汇率'**
  String multiCurrencySetRate(String code);

  /// No description provided for @multiCurrencyRateQuestion.
  ///
  /// In zh, this message translates to:
  /// **'1 {code} 等于多少 CNY？'**
  String multiCurrencyRateQuestion(String code);

  /// No description provided for @multiCurrencyRateExample.
  ///
  /// In zh, this message translates to:
  /// **'例如 7.20'**
  String get multiCurrencyRateExample;

  /// No description provided for @multiCurrencyManualOverrideHint.
  ///
  /// In zh, this message translates to:
  /// **'当前为手动覆盖，自动刷新不会修改它。'**
  String get multiCurrencyManualOverrideHint;

  /// No description provided for @multiCurrencyResetToAuto.
  ///
  /// In zh, this message translates to:
  /// **'重置为自动'**
  String get multiCurrencyResetToAuto;

  /// No description provided for @multiCurrencyCnyBaseError.
  ///
  /// In zh, this message translates to:
  /// **'CNY 是基准币种，不可手动覆盖'**
  String get multiCurrencyCnyBaseError;

  /// No description provided for @multiCurrencyRateMustBePositive.
  ///
  /// In zh, this message translates to:
  /// **'汇率必须为正数'**
  String get multiCurrencyRateMustBePositive;

  /// No description provided for @aiInputTitle.
  ///
  /// In zh, this message translates to:
  /// **'快速输入 · AI 增强'**
  String get aiInputTitle;

  /// No description provided for @aiInputEnable.
  ///
  /// In zh, this message translates to:
  /// **'启用 AI 增强'**
  String get aiInputEnable;

  /// No description provided for @aiInputEnableHint.
  ///
  /// In zh, this message translates to:
  /// **'开启后，本地解析置信度低时确认卡片会出现 \"✨ AI 增强\" 按钮，调用你配置的 LLM 兜底解析。'**
  String get aiInputEnableHint;

  /// No description provided for @aiInputApiConfig.
  ///
  /// In zh, this message translates to:
  /// **'API 配置'**
  String get aiInputApiConfig;

  /// No description provided for @aiInputApiHint.
  ///
  /// In zh, this message translates to:
  /// **'使用 OpenAI 兼容协议（chat/completions）。endpoint 完整 URL，例如：'**
  String get aiInputApiHint;

  /// No description provided for @aiInputHidden.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get aiInputHidden;

  /// No description provided for @aiInputShown.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get aiInputShown;

  /// No description provided for @aiInputPromptTemplate.
  ///
  /// In zh, this message translates to:
  /// **'Prompt 模板（可选）'**
  String get aiInputPromptTemplate;

  /// No description provided for @aiInputPromptPlaceholderHint.
  ///
  /// In zh, this message translates to:
  /// **'占位符 {NOW} / {TEXT} / {CATEGORIES} 会在调用时替换。留空使用内置默认模板。'**
  String aiInputPromptPlaceholderHint(
    Object CATEGORIES,
    Object NOW,
    Object TEXT,
  );

  /// No description provided for @aiInputPromptTemplateLabel.
  ///
  /// In zh, this message translates to:
  /// **'Prompt 模板'**
  String get aiInputPromptTemplateLabel;

  /// No description provided for @aiInputSaved.
  ///
  /// In zh, this message translates to:
  /// **'AI 增强配置已保存'**
  String get aiInputSaved;

  /// No description provided for @aiInputNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置 AI 增强（需启用并填写 endpoint / key / model）'**
  String get aiInputNotConfigured;

  /// No description provided for @aiInputEndpointInvalid.
  ///
  /// In zh, this message translates to:
  /// **'endpoint 不是合法 URL：{endpoint}'**
  String aiInputEndpointInvalid(String endpoint);

  /// No description provided for @aiInputTimeout.
  ///
  /// In zh, this message translates to:
  /// **'网络请求超时'**
  String get aiInputTimeout;

  /// No description provided for @aiInputNetworkFailed.
  ///
  /// In zh, this message translates to:
  /// **'网络请求失败：{error}'**
  String aiInputNetworkFailed(String error);

  /// No description provided for @aiInputHttpError.
  ///
  /// In zh, this message translates to:
  /// **'LLM 返回 HTTP {status}'**
  String aiInputHttpError(int status);

  /// No description provided for @aiInputInvalidJson.
  ///
  /// In zh, this message translates to:
  /// **'LLM 响应不是合法 JSON：{error}'**
  String aiInputInvalidJson(String error);

  /// No description provided for @aiInputResponseNotObject.
  ///
  /// In zh, this message translates to:
  /// **'LLM 响应根不是 JSON 对象'**
  String get aiInputResponseNotObject;

  /// No description provided for @aiInputMissingChoices.
  ///
  /// In zh, this message translates to:
  /// **'LLM 响应缺少 choices'**
  String get aiInputMissingChoices;

  /// No description provided for @aiInputChoiceNotObject.
  ///
  /// In zh, this message translates to:
  /// **'LLM 响应 choice 非对象'**
  String get aiInputChoiceNotObject;

  /// No description provided for @aiInputMissingMessage.
  ///
  /// In zh, this message translates to:
  /// **'LLM 响应缺少 message'**
  String get aiInputMissingMessage;

  /// No description provided for @aiInputContentNotString.
  ///
  /// In zh, this message translates to:
  /// **'LLM 响应 content 非字符串'**
  String get aiInputContentNotString;

  /// No description provided for @aiInputContentInvalidJson.
  ///
  /// In zh, this message translates to:
  /// **'LLM 返回的 content 不是合法 JSON：{error}'**
  String aiInputContentInvalidJson(String error);

  /// No description provided for @aiInputContentNotObject.
  ///
  /// In zh, this message translates to:
  /// **'LLM 返回 content 根不是 JSON 对象'**
  String get aiInputContentNotObject;

  /// No description provided for @aiInputAmountTypeError.
  ///
  /// In zh, this message translates to:
  /// **'amount 字段类型非法：{type}'**
  String aiInputAmountTypeError(String type);

  /// No description provided for @aiInputAmountInvalid.
  ///
  /// In zh, this message translates to:
  /// **'amount 不是有效正数：{value}'**
  String aiInputAmountInvalid(String value);

  /// No description provided for @aiInputParentKeyTypeError.
  ///
  /// In zh, this message translates to:
  /// **'category_parent_key 字段类型非法：{type}'**
  String aiInputParentKeyTypeError(String type);

  /// No description provided for @aiInputParentKeyInvalid.
  ///
  /// In zh, this message translates to:
  /// **'category_parent_key 取值非法：{value}'**
  String aiInputParentKeyInvalid(String value);

  /// No description provided for @aiInputDateTypeError.
  ///
  /// In zh, this message translates to:
  /// **'occurred_at 字段类型非法：{type}'**
  String aiInputDateTypeError(String type);

  /// No description provided for @aiInputDateInvalid.
  ///
  /// In zh, this message translates to:
  /// **'occurred_at 不是合法 ISO 日期：{value}'**
  String aiInputDateInvalid(String value);

  /// No description provided for @aiInputNoteTypeError.
  ///
  /// In zh, this message translates to:
  /// **'note 字段类型非法：{type}'**
  String aiInputNoteTypeError(String type);

  /// No description provided for @themeTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get themeTitle;

  /// No description provided for @themeLabel.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get themeLabel;

  /// No description provided for @themeSwitchHint.
  ///
  /// In zh, this message translates to:
  /// **'切换后所有页面即时生效，包括图表与图标底色'**
  String get themeSwitchHint;

  /// No description provided for @themeFontSize.
  ///
  /// In zh, this message translates to:
  /// **'字号'**
  String get themeFontSize;

  /// No description provided for @themeFontSizeHint.
  ///
  /// In zh, this message translates to:
  /// **'大字号会在系统字号基础上再放大 15%，小字号缩小 15%'**
  String get themeFontSizeHint;

  /// No description provided for @themeIconPack.
  ///
  /// In zh, this message translates to:
  /// **'分类图标'**
  String get themeIconPack;

  /// No description provided for @themeIconPackSwitchHint.
  ///
  /// In zh, this message translates to:
  /// **'切换后分类网格与流水列表图标即时更新；自定义图标不受影响'**
  String get themeIconPackSwitchHint;

  /// No description provided for @themePrimary.
  ///
  /// In zh, this message translates to:
  /// **'主色'**
  String get themePrimary;

  /// No description provided for @themeContainer.
  ///
  /// In zh, this message translates to:
  /// **'容器'**
  String get themeContainer;

  /// No description provided for @themeTertiary.
  ///
  /// In zh, this message translates to:
  /// **'辅助'**
  String get themeTertiary;

  /// No description provided for @themeSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get themeSuccess;

  /// No description provided for @themeWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get themeWarning;

  /// No description provided for @themeError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get themeError;

  /// No description provided for @colorSemanticPrimary.
  ///
  /// In zh, this message translates to:
  /// **'主色'**
  String get colorSemanticPrimary;

  /// No description provided for @colorSemanticContainer.
  ///
  /// In zh, this message translates to:
  /// **'容器'**
  String get colorSemanticContainer;

  /// No description provided for @colorSemanticTertiary.
  ///
  /// In zh, this message translates to:
  /// **'辅助'**
  String get colorSemanticTertiary;

  /// No description provided for @colorSemanticSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get colorSemanticSuccess;

  /// No description provided for @colorSemanticWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get colorSemanticWarning;

  /// No description provided for @colorSemanticError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get colorSemanticError;

  /// No description provided for @dateFormatRelative.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日'**
  String dateFormatRelative(int month, int day);

  /// No description provided for @dateHeatmapCell.
  ///
  /// In zh, this message translates to:
  /// **'{date}\n支出：¥...'**
  String dateHeatmapCell(String date);

  /// No description provided for @trashTabRecords.
  ///
  /// In zh, this message translates to:
  /// **'流水'**
  String get trashTabRecords;

  /// No description provided for @trashTabCategories.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get trashTabCategories;

  /// No description provided for @trashTabAccounts.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get trashTabAccounts;

  /// No description provided for @trashTabLedgers.
  ///
  /// In zh, this message translates to:
  /// **'账本'**
  String get trashTabLedgers;

  /// No description provided for @trashClearCurrent.
  ///
  /// In zh, this message translates to:
  /// **'清空当前分类'**
  String get trashClearCurrent;

  /// No description provided for @trashConfirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确认清空？'**
  String get trashConfirmClear;

  /// No description provided for @trashClearConfirmMsg.
  ///
  /// In zh, this message translates to:
  /// **'将永久删除全部已软删的「{label}」（无法恢复）。'**
  String trashClearConfirmMsg(String label);

  /// No description provided for @trashPermanentDelete.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get trashPermanentDelete;

  /// No description provided for @trashCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空「{label}」垃圾桶'**
  String trashCleared(String label);

  /// No description provided for @trashClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空失败：{error}'**
  String trashClearFailed(String error);

  /// No description provided for @trashNoDeletedRecords.
  ///
  /// In zh, this message translates to:
  /// **'没有已删流水'**
  String get trashNoDeletedRecords;

  /// No description provided for @trashNoDeletedCategories.
  ///
  /// In zh, this message translates to:
  /// **'没有已删分类'**
  String get trashNoDeletedCategories;

  /// No description provided for @trashNoDeletedAccounts.
  ///
  /// In zh, this message translates to:
  /// **'没有已删账户'**
  String get trashNoDeletedAccounts;

  /// No description provided for @trashNoDeletedLedgers.
  ///
  /// In zh, this message translates to:
  /// **'没有已删账本'**
  String get trashNoDeletedLedgers;

  /// No description provided for @trashRestored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复 1 条流水'**
  String get trashRestored;

  /// No description provided for @trashRestoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：{error}'**
  String trashRestoreFailed(String error);

  /// No description provided for @trashPurgeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'永久删除这条流水？'**
  String get trashPurgeConfirm;

  /// No description provided for @trashPurged.
  ///
  /// In zh, this message translates to:
  /// **'已永久删除'**
  String get trashPurged;

  /// No description provided for @trashPurgeFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String trashPurgeFailed(String error);

  /// No description provided for @trashRestoredCategory.
  ///
  /// In zh, this message translates to:
  /// **'已恢复分类「{name}」'**
  String trashRestoredCategory(String name);

  /// No description provided for @trashPurgeCategoryConfirm.
  ///
  /// In zh, this message translates to:
  /// **'永久删除分类「{name}」？'**
  String trashPurgeCategoryConfirm(String name);

  /// No description provided for @trashRestoredAccount.
  ///
  /// In zh, this message translates to:
  /// **'已恢复账户「{name}」'**
  String trashRestoredAccount(String name);

  /// No description provided for @trashPurgeAccountConfirm.
  ///
  /// In zh, this message translates to:
  /// **'永久删除账户「{name}」？'**
  String trashPurgeAccountConfirm(String name);

  /// No description provided for @trashRestoredLedger.
  ///
  /// In zh, this message translates to:
  /// **'已恢复账本「{name}」'**
  String trashRestoredLedger(String name);

  /// No description provided for @trashPurgeLedgerConfirm.
  ///
  /// In zh, this message translates to:
  /// **'永久删除账本「{name}」？\n该账本下所有流水和预算也会一并永久删除（无法恢复）。'**
  String trashPurgeLedgerConfirm(String name);

  /// No description provided for @trashPurgedLedger.
  ///
  /// In zh, this message translates to:
  /// **'已永久删除账本'**
  String get trashPurgedLedger;

  /// No description provided for @trashRemainingDays.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {days} 天 · 删于 {date}'**
  String trashRemainingDays(int days, String date);

  /// No description provided for @trashRestore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get trashRestore;

  /// No description provided for @trashAutoCleanHint.
  ///
  /// In zh, this message translates to:
  /// **'已软删 30 天后会自动清理'**
  String get trashAutoCleanHint;

  /// No description provided for @trashConfirmPermanentDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认永久删除？'**
  String get trashConfirmPermanentDelete;

  /// No description provided for @trashLedgerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'账本 · 恢复时会一并复活级联删除的流水/预算'**
  String get trashLedgerSubtitle;

  /// No description provided for @trashTxSubtitleTransfer.
  ///
  /// In zh, this message translates to:
  /// **'{date} · 转账'**
  String trashTxSubtitleTransfer(String date);

  /// No description provided for @detailType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get detailType;

  /// No description provided for @detailTransferFrom.
  ///
  /// In zh, this message translates to:
  /// **'转出'**
  String get detailTransferFrom;

  /// No description provided for @detailTransferTo.
  ///
  /// In zh, this message translates to:
  /// **'转入'**
  String get detailTransferTo;

  /// No description provided for @detailAccount.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get detailAccount;

  /// No description provided for @detailTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get detailTime;

  /// No description provided for @detailImages.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get detailImages;

  /// No description provided for @detailCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get detailCopy;

  /// No description provided for @confirmOk.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirmOk;

  /// No description provided for @syncNotConfiguredFormat.
  ///
  /// In zh, this message translates to:
  /// **'{defaultText}（未配置）'**
  String syncNotConfiguredFormat(String defaultText);

  /// No description provided for @syncMigrateAttachmentsDetail.
  ///
  /// In zh, this message translates to:
  /// **'当前后端已上传 {count} 张附件。\n\n切换后新附件会上传到 {type}，但已在旧后端的附件不会跨设备访问。\n\n选择「迁移」会在下次同步时把这些附件重新上传到新后端（耗时较长，取决于网络与图片数量）；选择「暂不迁移」则旧附件保留在旧后端，可稍后切回去再用。'**
  String syncMigrateAttachmentsDetail(int count, String type);

  /// No description provided for @syncError.
  ///
  /// In zh, this message translates to:
  /// **'错误: {error}'**
  String syncError(String error);

  /// No description provided for @syncSwitchFailed.
  ///
  /// In zh, this message translates to:
  /// **'切换失败: {error}'**
  String syncSwitchFailed(String error);

  /// No description provided for @exportBbbakLabel.
  ///
  /// In zh, this message translates to:
  /// **'加密备份 .bbbak'**
  String get exportBbbakLabel;

  /// No description provided for @importCsvThirdPartyDesc.
  ///
  /// In zh, this message translates to:
  /// **'第三方账单不含本 App 的 ID，会作为「全部新记录」导入；账本归入当前账本，账户列若与现有账户同名会被关联，否则置空。'**
  String get importCsvThirdPartyDesc;

  /// No description provided for @importCsvNoIdDesc.
  ///
  /// In zh, this message translates to:
  /// **'CSV 文件不含 ID，只能作为「全部新记录」导入；账本/分类/账户按名称匹配，匹配不到时归到当前账本，分类/账户列空。'**
  String get importCsvNoIdDesc;

  /// No description provided for @pinUnlockSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'请输入应用锁 PIN'**
  String get pinUnlockSubtitle;

  /// No description provided for @ledgerDefaultName.
  ///
  /// In zh, this message translates to:
  /// **'账本'**
  String get ledgerDefaultName;

  /// No description provided for @statsTooltipDateFormat.
  ///
  /// In zh, this message translates to:
  /// **'M月d日'**
  String get statsTooltipDateFormat;

  /// No description provided for @a11yRecordHomeNewFab.
  ///
  /// In zh, this message translates to:
  /// **'记一笔'**
  String get a11yRecordHomeNewFab;

  /// No description provided for @a11yRecordHomeSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索流水'**
  String get a11yRecordHomeSearch;

  /// No description provided for @a11yRecordHomeSwapCurrency.
  ///
  /// In zh, this message translates to:
  /// **'切换主副币种'**
  String get a11yRecordHomeSwapCurrency;

  /// No description provided for @a11yRecordHomePrevMonth.
  ///
  /// In zh, this message translates to:
  /// **'上一月'**
  String get a11yRecordHomePrevMonth;

  /// No description provided for @a11yRecordHomeNextMonth.
  ///
  /// In zh, this message translates to:
  /// **'下一月'**
  String get a11yRecordHomeNextMonth;

  /// No description provided for @a11yRecordHomeDismissReminder.
  ///
  /// In zh, this message translates to:
  /// **'关闭提示'**
  String get a11yRecordHomeDismissReminder;

  /// No description provided for @a11yRecordNewBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get a11yRecordNewBack;

  /// No description provided for @a11yQuickConfirmClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get a11yQuickConfirmClose;

  /// No description provided for @a11yCloudServiceConfigure.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get a11yCloudServiceConfigure;

  /// No description provided for @a11yAttachmentImage.
  ///
  /// In zh, this message translates to:
  /// **'已添加图片'**
  String get a11yAttachmentImage;

  /// No description provided for @meAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get meAbout;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @aboutAppName.
  ///
  /// In zh, this message translates to:
  /// **'边边记账'**
  String get aboutAppName;

  /// No description provided for @aboutAppTagline.
  ///
  /// In zh, this message translates to:
  /// **'温暖陪伴你每一笔记录 🐱'**
  String get aboutAppTagline;

  /// No description provided for @aboutAppVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get aboutAppVersion;

  /// No description provided for @aboutAppVersionValue.
  ///
  /// In zh, this message translates to:
  /// **'{version}（构建 {build}）'**
  String aboutAppVersionValue(String version, String build);

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutTermsOfService.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get aboutTermsOfService;

  /// No description provided for @aboutLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get aboutLicenses;

  /// No description provided for @aboutLicensesLegalese.
  ///
  /// In zh, this message translates to:
  /// **'本应用使用了若干开源组件，特此致谢。'**
  String get aboutLicensesLegalese;

  /// No description provided for @aboutRevokeConsent.
  ///
  /// In zh, this message translates to:
  /// **'撤回同意'**
  String get aboutRevokeConsent;

  /// No description provided for @aboutRevokeConsentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'撤回后退出应用，下次启动需要重新同意'**
  String get aboutRevokeConsentSubtitle;

  /// No description provided for @aboutRevokeConsentConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'撤回同意？'**
  String get aboutRevokeConsentConfirmTitle;

  /// No description provided for @aboutRevokeConsentConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'撤回后将立即退出应用，下次启动会重新征求您的同意。已记录的本地数据不会被清除。'**
  String get aboutRevokeConsentConfirmMessage;

  /// No description provided for @aboutRevokeConsentConfirm.
  ///
  /// In zh, this message translates to:
  /// **'撤回并退出'**
  String get aboutRevokeConsentConfirm;

  /// No description provided for @privacyConsentTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策与用户协议'**
  String get privacyConsentTitle;

  /// No description provided for @privacyConsentIntro.
  ///
  /// In zh, this message translates to:
  /// **'感谢使用边边记账。在开始使用前，请阅读以下隐私政策与用户协议。点击「同意并继续」表示您已阅读并同意本政策。'**
  String get privacyConsentIntro;

  /// No description provided for @privacyConsentDataSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'我们收集哪些数据'**
  String get privacyConsentDataSectionTitle;

  /// No description provided for @privacyConsentDataSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'本应用为离线优先记账工具：流水、账本、分类、账户、预算、附件等数据默认仅保存在您的设备本地，存于 SQLCipher 加密的 SQLite 数据库中。仅当您主动开启云同步时，相应数据才会上传至您指定的云服务（您自建的 Supabase / WebDAV / S3 / iCloud Drive 等）。'**
  String get privacyConsentDataSectionBody;

  /// No description provided for @privacyConsentUsageSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据用途'**
  String get privacyConsentUsageSectionTitle;

  /// No description provided for @privacyConsentUsageSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'数据仅用于您本人的记账、统计、预算与提醒功能；本应用不进行任何形式的广告投放、用户画像、行为分析或第三方分享。'**
  String get privacyConsentUsageSectionBody;

  /// No description provided for @privacyConsentStorageSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'存储位置'**
  String get privacyConsentStorageSectionTitle;

  /// No description provided for @privacyConsentStorageSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'本地数据存于设备文档目录的加密 SQLite 文件中；数据库密钥保存在系统 Keystore（Android）/ Keychain（iOS），永不离开设备。云同步数据存于您自行配置的云服务，本应用作者不接触任何用户数据。'**
  String get privacyConsentStorageSectionBody;

  /// No description provided for @privacyConsentSharingSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据共享'**
  String get privacyConsentSharingSectionTitle;

  /// No description provided for @privacyConsentSharingSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'我们不会将您的数据共享给任何第三方。云同步、AI 增强等可选功能会按您的配置向您指定的服务（如您自建的 Supabase、您填写的 LLM API）发送相应数据；这些请求由您直接发起，对方为您选择的服务提供商，与本应用作者无关。'**
  String get privacyConsentSharingSectionBody;

  /// No description provided for @privacyConsentRightsSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'您的权利'**
  String get privacyConsentRightsSectionTitle;

  /// No description provided for @privacyConsentRightsSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'您可随时通过「我的 → 关于 → 撤回同意」撤回本次授权；撤回后应用会退出，下次启动需要重新同意才能继续使用。所有本地数据可通过「导入 / 导出」功能完整导出或一键清除；流水删除走垃圾桶，可在 30 天内恢复。'**
  String get privacyConsentRightsSectionBody;

  /// No description provided for @privacyConsentContactSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'联系方式'**
  String get privacyConsentContactSectionTitle;

  /// No description provided for @privacyConsentContactSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'如对本政策有疑问，可通过应用源码仓库的 Issue 反馈。'**
  String get privacyConsentContactSectionBody;

  /// No description provided for @privacyConsentVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'政策版本'**
  String get privacyConsentVersionLabel;

  /// No description provided for @privacyConsentVersionValue.
  ///
  /// In zh, this message translates to:
  /// **'1.0（2026-05-14 生效）'**
  String get privacyConsentVersionValue;

  /// No description provided for @privacyConsentAccept.
  ///
  /// In zh, this message translates to:
  /// **'同意并继续'**
  String get privacyConsentAccept;

  /// No description provided for @privacyConsentReject.
  ///
  /// In zh, this message translates to:
  /// **'不同意'**
  String get privacyConsentReject;

  /// No description provided for @privacyConsentRejectAlertTitle.
  ///
  /// In zh, this message translates to:
  /// **'未同意将无法使用'**
  String get privacyConsentRejectAlertTitle;

  /// No description provided for @privacyConsentRejectAlertMessage.
  ///
  /// In zh, this message translates to:
  /// **'未同意隐私政策与用户协议将无法使用本应用。点击「退出」立即关闭应用；点击「再次阅读」回到政策文本。'**
  String get privacyConsentRejectAlertMessage;

  /// No description provided for @privacyConsentRejectAlertExit.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get privacyConsentRejectAlertExit;

  /// No description provided for @privacyConsentRejectAlertReread.
  ///
  /// In zh, this message translates to:
  /// **'再次阅读'**
  String get privacyConsentRejectAlertReread;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get termsOfServiceTitle;

  /// No description provided for @termsOfServiceIntro.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用边边记账。使用本应用即表示您同意以下条款。'**
  String get termsOfServiceIntro;

  /// No description provided for @termsOfServiceLicenseSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用许可'**
  String get termsOfServiceLicenseSectionTitle;

  /// No description provided for @termsOfServiceLicenseSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'本应用免费提供给您用于个人记账用途。在遵守本协议的前提下，您可在自己的设备上安装、使用、复制本应用。'**
  String get termsOfServiceLicenseSectionBody;

  /// No description provided for @termsOfServiceResponsibilitySectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户责任'**
  String get termsOfServiceResponsibilitySectionTitle;

  /// No description provided for @termsOfServiceResponsibilitySectionBody.
  ///
  /// In zh, this message translates to:
  /// **'您应妥善保管设备与同步凭证；因您本人疏忽（如丢失设备、泄露同步凭证、忘记密码导致无法解密）造成的数据损失，本应用作者不承担责任。请定期使用「导入 / 导出」功能备份重要数据。'**
  String get termsOfServiceResponsibilitySectionBody;

  /// No description provided for @termsOfServiceDisclaimerSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'免责声明'**
  String get termsOfServiceDisclaimerSectionTitle;

  /// No description provided for @termsOfServiceDisclaimerSectionBody.
  ///
  /// In zh, this message translates to:
  /// **'本应用按「现状」提供，作者不对应用的可用性、准确性、完整性作出任何明示或默示的担保。在适用法律允许的最大范围内，作者不对因使用本应用而产生的任何直接或间接损失承担责任。'**
  String get termsOfServiceDisclaimerSectionBody;

  /// No description provided for @termsOfServiceVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'协议版本'**
  String get termsOfServiceVersionLabel;

  /// No description provided for @termsOfServiceVersionValue.
  ///
  /// In zh, this message translates to:
  /// **'1.0（2026-05-14 生效）'**
  String get termsOfServiceVersionValue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
