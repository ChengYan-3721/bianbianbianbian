// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '边边记账';

  @override
  String get tabRecord => '记账';

  @override
  String get tabStats => '统计';

  @override
  String get tabLedger => '账本';

  @override
  String get tabMe => '我的';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get add => '添加';

  @override
  String get confirm => '确认';

  @override
  String get close => '关闭';

  @override
  String get nextStep => '下一步';

  @override
  String get reset => '重置';

  @override
  String get refresh => '刷新';

  @override
  String get done => '完成';

  @override
  String get clear => '清空';

  @override
  String get modify => '修改';

  @override
  String get select => '选择';

  @override
  String get know => '知道了';

  @override
  String get tip => '提示';

  @override
  String get loading => '加载中…';

  @override
  String get parsing => '解析中…';

  @override
  String get noData => '暂无数据';

  @override
  String get deleted => '已删除';

  @override
  String get required => '必填';

  @override
  String get optional => '可选';

  @override
  String get enabled => '已开启';

  @override
  String get disabled => '关闭中';

  @override
  String get notConfigured => '未配置';

  @override
  String get unknown => '未知';

  @override
  String get error => '错误';

  @override
  String get txTypeIncome => '收入';

  @override
  String get txTypeExpense => '支出';

  @override
  String get txTypeTransfer => '转账';

  @override
  String get txTypeUncategorized => '未分类';

  @override
  String get periodMonthly => '月';

  @override
  String get periodYearly => '年';

  @override
  String get periodMonthBudget => '月预算';

  @override
  String get periodYearBudget => '年预算';

  @override
  String get parentKeyIncome => '收入';

  @override
  String get parentKeyFood => '饮食';

  @override
  String get parentKeyShopping => '购物';

  @override
  String get parentKeyTransport => '出行';

  @override
  String get parentKeyEducation => '教育';

  @override
  String get parentKeyEntertainment => '娱乐';

  @override
  String get parentKeySocial => '人情';

  @override
  String get parentKeyHousing => '住房';

  @override
  String get parentKeyMedical => '医药';

  @override
  String get parentKeyInvestment => '投资';

  @override
  String get parentKeyOther => '其他';

  @override
  String get quickCatIncome => '收';

  @override
  String get quickCatFood => '食';

  @override
  String get quickCatShopping => '购';

  @override
  String get quickCatTransport => '行';

  @override
  String get quickCatEducation => '育';

  @override
  String get quickCatEntertainment => '乐';

  @override
  String get quickCatSocial => '情';

  @override
  String get quickCatHousing => '住';

  @override
  String get quickCatMedical => '医';

  @override
  String get quickCatInvestment => '投';

  @override
  String get quickCatOther => '其';

  @override
  String get accountTypeCash => '现金';

  @override
  String get accountTypeDebit => '储蓄卡';

  @override
  String get accountTypeCredit => '信用卡';

  @override
  String get accountTypeThirdParty => '第三方支付';

  @override
  String get accountTypeOther => '其他';

  @override
  String get deletedAccount => '（已删账户）';

  @override
  String get currencyCny => '人民币';

  @override
  String get currencyUsd => '美元';

  @override
  String get currencyEur => '欧元';

  @override
  String get currencyJpy => '日元';

  @override
  String get currencyKrw => '韩元';

  @override
  String get currencyHkd => '港币';

  @override
  String get currencyTwd => '新台币';

  @override
  String get currencyGbp => '英镑';

  @override
  String get currencySgd => '新元';

  @override
  String get currencyCad => '加元';

  @override
  String get currencyAud => '澳元';

  @override
  String get currencyCnyFull => '人民币 (CNY)';

  @override
  String get currencyUsdFull => '美元 (USD)';

  @override
  String get currencyEurFull => '欧元 (EUR)';

  @override
  String get currencyJpyFull => '日元 (JPY)';

  @override
  String get currencyKrwFull => '韩元 (KRW)';

  @override
  String get currencyGbpFull => '英镑 (GBP)';

  @override
  String get currencyHkdFull => '港币 (HKD)';

  @override
  String get themeCreamBunny => '🐰 奶油兔';

  @override
  String get themeThickBrownBear => '🐻 厚棕熊';

  @override
  String get themeMoonlightDark => '🌙 月见黑';

  @override
  String get themeMintGreen => '🍃 薄荷绿';

  @override
  String get fontSizeSmall => '小';

  @override
  String get fontSizeStandard => '标准';

  @override
  String get fontSizeLarge => '大';

  @override
  String get iconPackSticker => '✏️ 手绘贴纸';

  @override
  String get iconPackFlat => '📝 扁平简约';

  @override
  String get loadFailed => '加载失败';

  @override
  String loadFailedWithError(String error) {
    return '加载失败：$error';
  }

  @override
  String saveFailedWithError(String error) {
    return '保存失败：$error';
  }

  @override
  String deleteFailedWithError(String error) {
    return '删除失败：$error';
  }

  @override
  String readFailedWithError(String error) {
    return '读取失败：$error';
  }

  @override
  String operationFailedWithError(String error) {
    return '操作失败：$error';
  }

  @override
  String budgetConflictTotal(String period) {
    return '该账本的$period总预算已存在';
  }

  @override
  String budgetConflictCategory(String period) {
    return '该分类的$period预算已存在';
  }

  @override
  String ledgerNameConflict(String name) {
    return '已存在同名账本「$name」';
  }

  @override
  String get meAppearance => '外观';

  @override
  String get meReminder => '提醒';

  @override
  String get meBudget => '预算';

  @override
  String get meAssets => '资产';

  @override
  String get meMultiCurrency => '多币种';

  @override
  String get meAiInput => '快速输入 · AI 增强';

  @override
  String get meCloudService => '云服务';

  @override
  String get meAttachmentCache => '附件缓存';

  @override
  String get meImportExport => '导入 / 导出';

  @override
  String get meAppLock => '应用锁';

  @override
  String get meTrash => '垃圾桶';

  @override
  String get recordTitle => '记账';

  @override
  String get recordSwitchLedger => '切换账本';

  @override
  String get recordIncome => '收入';

  @override
  String get recordExpense => '支出';

  @override
  String get recordBalance => '结余';

  @override
  String get recordSyncing => '同步中…';

  @override
  String recordSyncFailed(String error) {
    return '同步失败：$error';
  }

  @override
  String recordLastSyncedAt(String time) {
    return '上次同步：$time';
  }

  @override
  String get recordNeverSynced => '尚未同步';

  @override
  String get recordJustNow => '刚刚';

  @override
  String recordMinutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String recordHoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String recordDaysAgo(int count) {
    return '$count天前';
  }

  @override
  String recordYearMonth(int year, int month) {
    return '$year年$month月';
  }

  @override
  String get recordQuickHint => '写点什么，我来帮你记 🐰';

  @override
  String get recordRecognize => '识别';

  @override
  String get recordStartFirst => '开始记第一笔吧 🐰';

  @override
  String get recordSynced => '已同步';

  @override
  String get recordNetworkUnavailable => '网络不可用';

  @override
  String recordSyncFailedMsg(String message) {
    return '同步失败：$message';
  }

  @override
  String get recordDeleteConfirm => '删除这条记录？';

  @override
  String get recordDeleteHint => '删除后可在后续垃圾桶中恢复。';

  @override
  String recordIdleReminder(int days) {
    return '已经 $days 天没记账了，快来记一笔吧 🐻';
  }

  @override
  String get recordPleaseInputFirst => '请先输入一段话再点识别';

  @override
  String get recordNewTitle => '记一笔';

  @override
  String get recordNewTransferTitle => '转账';

  @override
  String get recordNewCategory => '分类';

  @override
  String get recordNewSelectCategory => '选择分类';

  @override
  String get recordNewDate => '日期';

  @override
  String get recordNewNote => '备注';

  @override
  String get recordNewInputNote => '输入备注';

  @override
  String get recordNewNoteOptional => '可留空';

  @override
  String get recordNewSwitchTo => '切换';

  @override
  String get recordNewFromAccount => '转出账户';

  @override
  String get recordNewToAccount => '转入账户';

  @override
  String get recordNewTransferSameError => '转出账户和转入账户不能相同';

  @override
  String get recordNewAdd => '添加';

  @override
  String get recordNewEditCategory => '编辑';

  @override
  String get recordNewLoadingCategories => '加载分类…';

  @override
  String get recordNewInputAmount => '输入金额';

  @override
  String get recordNewWallet => '钱包';

  @override
  String get recordNewDeleteImage => '删除图片';

  @override
  String get recordNewGallery => '相册';

  @override
  String get recordNewCamera => '拍照';

  @override
  String get recordNewTransferSettings => '转账设置';

  @override
  String get recordNewSelectCurrency => '选择币种';

  @override
  String recordNewMaxAttachments(int max) {
    return '最多只能选择$max张图片';
  }

  @override
  String get recordNewImageTooLarge => '单张图片不能超过 10MB';

  @override
  String get recordNewDuplicateImage => '同一张图片不能重复添加';

  @override
  String get recordSearchTitle => '搜索流水';

  @override
  String get recordSearchHint => '关键词（备注 / 分类 / 账户）';

  @override
  String get recordSearchFilter => '筛选';

  @override
  String get recordSearchNoDateLimit => '不限日期';

  @override
  String get recordSearchDate => '日期';

  @override
  String get recordSearchClearDate => '清空日期';

  @override
  String get recordSearchType => '类型';

  @override
  String get recordSearchAll => '全部';

  @override
  String get recordSearchAmount => '金额';

  @override
  String get recordSearchAmountMin => '下限';

  @override
  String get recordSearchAmountMax => '上限';

  @override
  String get recordSearchEmptyHint => '输入关键词或筛选条件后开始搜索';

  @override
  String get recordSearchNoResult => '没有找到相关流水';

  @override
  String get recordMonthPrevYear => '上一年';

  @override
  String get recordMonthNextYear => '下一年';

  @override
  String recordMonthYear(int year) {
    return '$year 年';
  }

  @override
  String recordMonthMonth(int month) {
    return '$month 月';
  }

  @override
  String get quickConfirmTitle => '确认记一笔';

  @override
  String get quickConfirmLowConfidence => '识别置信度较低，请核对';

  @override
  String get quickConfirmAiUpdated => 'AI 已更新';

  @override
  String quickConfirmAiFailed(String message) {
    return 'AI 解析失败：$message';
  }

  @override
  String quickConfirmAiFailedUnknown(String error) {
    return 'AI 解析失败：$error';
  }

  @override
  String get quickConfirmAmount => '金额';

  @override
  String get quickConfirmCategory => '分类';

  @override
  String get quickConfirmPleaseSelect => '请选择';

  @override
  String get quickConfirmTime => '时间';

  @override
  String get quickConfirmAiEnhance => 'AI 增强';

  @override
  String get categoryManageTitle => '分类管理';

  @override
  String get categoryEditTitle => '编辑分类';

  @override
  String get categoryAddTitle => '添加分类';

  @override
  String get categoryReorderTitle => '排序';

  @override
  String get categoryFavoriteReorderTitle => '排序';

  @override
  String get categoryName => '名称';

  @override
  String categoryNameHint(String parent) {
    return '设置分类名称（一级：$parent）';
  }

  @override
  String get categoryNameRequired => '请输入分类名称';

  @override
  String get categoryIconEmoji => '图标 Emoji（可选）';

  @override
  String get categoryIconEmojiHint => '例如 🍔、🚗、🎁';

  @override
  String get categoryDuplicateName => '该一级分类下已存在同名分类';

  @override
  String get categoryAddNew => '添加新的分类';

  @override
  String get categoryNoFavorite => '还没有收藏分类';

  @override
  String get categoryNoCategory => '暂无分类';

  @override
  String get categoryUncollect => '取消收藏';

  @override
  String get categoryCollect => '收藏';

  @override
  String get categoryUndoDelete => '取消删除';

  @override
  String get statsTitle => '统计分析';

  @override
  String get statsExport => '导出';

  @override
  String get statsThisMonth => '本月';

  @override
  String get statsLastMonth => '上月';

  @override
  String get statsThisYear => '本年';

  @override
  String get statsCustom => '自定义';

  @override
  String get statsSelectRange => '选择统计区间';

  @override
  String get statsIncomeExpenseLine => '收支折线（按日）';

  @override
  String statsChartLoadFailed(String error) {
    return '图表加载失败：$error';
  }

  @override
  String get statsNoIncomeExpenseData => '暂无收支数据';

  @override
  String get statsTryAnotherRange => '换个区间试试吧 🐰';

  @override
  String get statsExpenseCategoryPie => '支出分类占比';

  @override
  String get statsNoExpenseData => '暂无支出数据';

  @override
  String get statsAddExpenseHint => '记一笔支出就能看到啦 🐰';

  @override
  String get statsViewBudget => '查看预算';

  @override
  String get statsRanking => '收支排行榜';

  @override
  String statsRankLoadFailed(String error) {
    return '排行榜加载失败：$error';
  }

  @override
  String get statsNoRankData => '暂无排行数据';

  @override
  String get statsAddMoreHint => '记几笔就能看到排名啦 🐰';

  @override
  String get statsHeatmapTitle => '支出日历热力图';

  @override
  String get statsHeatmapLegend => '颜色越深表示当日支出越高';

  @override
  String statsHeatmapLoadFailed(String error) {
    return '热力图加载失败：$error';
  }

  @override
  String get statsNoHeatmapData => '暂无支出热力数据';

  @override
  String get statsHeatmapHint => '记一笔支出就能点亮日历啦 🐰';

  @override
  String get statsExportPng => '导出 PNG（当前视图截图）';

  @override
  String get statsExportCsv => '导出 CSV（当前区间明细）';

  @override
  String statsExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get statsChartNotMounted => '图表区尚未挂载';

  @override
  String get statsPngTitle => '边边记账 · 统计图表';

  @override
  String statsPngSubtitle(String range) {
    return '统计区间：$range';
  }

  @override
  String get statsCsvTitle => '边边记账 · 流水明细';

  @override
  String statsCsvSubtitle(String range) {
    return '统计区间：$range';
  }

  @override
  String get weekdayMon => '周一';

  @override
  String get weekdayTue => '周二';

  @override
  String get weekdayWed => '周三';

  @override
  String get weekdayThu => '周四';

  @override
  String get weekdayFri => '周五';

  @override
  String get weekdaySat => '周六';

  @override
  String get weekdaySun => '周日';

  @override
  String get weekdayShortMon => '一';

  @override
  String get weekdayShortTue => '二';

  @override
  String get weekdayShortWed => '三';

  @override
  String get weekdayShortThu => '四';

  @override
  String get weekdayShortFri => '五';

  @override
  String get weekdayShortSat => '六';

  @override
  String get weekdayShortSun => '日';

  @override
  String dateMonthDayWeekday(int month, int day, String weekday) {
    return '$month月$day日 $weekday';
  }

  @override
  String get ledgerEditTitle => '编辑账本';

  @override
  String get ledgerNewTitle => '新建账本';

  @override
  String get ledgerNotExist => '账本不存在';

  @override
  String get ledgerName => '账本名称';

  @override
  String get ledgerNameRequired => '请输入账本名称';

  @override
  String get ledgerCoverEmoji => '封面 Emoji';

  @override
  String get ledgerCoverEmojiHint => '例如 📒、💼、✈️';

  @override
  String get ledgerDefaultCurrency => '默认币种';

  @override
  String get ledgerArchived => '归档';

  @override
  String get ledgerArchiveHint => '归档后账本将移至归档区，不再显示在切换器中';

  @override
  String get ledgerCannotSave => '账本不存在，无法保存';

  @override
  String ledgerNameConflictMsg(String name) {
    return '已存在同名账本「$name」，请换一个';
  }

  @override
  String get ledgerNew => '新建账本';

  @override
  String get ledgerEmptyHint => '还没有账本，去创建一个吧 🐰';

  @override
  String get ledgerUnarchive => '取消归档';

  @override
  String get ledgerArchive => '归档';

  @override
  String get ledgerConfirmDelete => '确认删除';

  @override
  String ledgerDeleteConfirmMsg(String name) {
    return '确定要删除账本「$name」吗？\n\n该账本下的所有流水和预算也将被删除。\n删除后可在垃圾桶中保留 30 天。';
  }

  @override
  String ledgerDeleted(String name) {
    return '「$name」已删除';
  }

  @override
  String ledgerTxCountCurrency(int count, Object currency) {
    return '$count 笔流水  ·  $currency';
  }

  @override
  String get budgetTitle => '预算';

  @override
  String get budgetNew => '新建预算';

  @override
  String get budgetNotExist => '预算不存在';

  @override
  String get budgetPeriod => '周期';

  @override
  String get budgetCategory => '分类';

  @override
  String get budgetTotalNoCategory => '总预算（不限分类）';

  @override
  String get budgetAmount => '预算金额';

  @override
  String get budgetAmountRequired => '请输入金额';

  @override
  String get budgetAmountPositive => '金额必须大于 0';

  @override
  String get budgetCarryOver => '开启结转';

  @override
  String get budgetCarryOverHint => '未花完金额累加到下个周期';

  @override
  String get budgetDeleteConfirm => '删除预算';

  @override
  String get budgetDeleteHint => '删除后将无法恢复，确定继续？';

  @override
  String get budgetEmptyHint => '还没有预算\n点右下角加一个吧 🐰';

  @override
  String get budgetTotal => '总预算';

  @override
  String get budgetDeletedCategory => '（已删除分类）';

  @override
  String get budgetCarryOverLabel => ' · 结转';

  @override
  String budgetAvailable(String amount) {
    return '可用 ¥$amount';
  }

  @override
  String budgetSpentOverLimit(String spent, String limit) {
    return '已花 ¥$spent / ¥$limit';
  }

  @override
  String get budgetProgressCalculating => '进度计算中…';

  @override
  String budgetProgressFailed(String error) {
    return '进度计算失败：$error';
  }

  @override
  String get budgetYearStartFrom => '年起';

  @override
  String get budgetCarryStart => '结转起始';

  @override
  String get budgetCarryStartHint => '选择更早的月份可让那时之后的剩余结转到本月';

  @override
  String get budgetSelectCarryStartMonth => '选择结转起始月份';

  @override
  String get accountEditTitle => '编辑账户';

  @override
  String get accountNewTitle => '新建账户';

  @override
  String get accountNotExist => '账户不存在';

  @override
  String get accountName => '账户名称';

  @override
  String get accountNameHint => '例如：现金、工商银行卡';

  @override
  String get accountNameRequired => '请输入账户名称';

  @override
  String get accountType => '账户类型';

  @override
  String get accountIconEmoji => '图标 Emoji（可选）';

  @override
  String get accountIconEmojiHint => '例如 💰、💳、🏦';

  @override
  String get accountInitialBalance => '初始余额';

  @override
  String get accountInitialBalanceHint => '可为负（信用卡欠款填负值）';

  @override
  String get accountBalanceInvalid => '请输入合法的数字';

  @override
  String get accountDefaultCurrency => '默认币种';

  @override
  String get accountBillingDay => '账单日（1-28）';

  @override
  String get accountBillingDayHint => '例如 5';

  @override
  String get accountRepaymentDay => '还款日（1-28）';

  @override
  String get accountRepaymentDayHint => '例如 22';

  @override
  String get accountIncludeInTotal => '计入总资产';

  @override
  String get accountIncludeInTotalHint => '关闭后该账户余额不参与总资产合计';

  @override
  String get accountDayRangeError => '请输入 1-28 的整数';

  @override
  String get accountCannotSave => '账户不存在，无法保存';

  @override
  String get accountListNew => '新建账户';

  @override
  String get accountDeleteConfirmTitle => '删除账户';

  @override
  String accountDeleteConfirmMsg(String name) {
    return '确定要删除账户「$name」吗？\\n\\n该账户下的流水将自动挂到「已删账户」占位。\\n删除后可在垃圾桶中保留 30 天。';
  }

  @override
  String accountDeleted(String name) {
    return '「$name」已删除';
  }

  @override
  String get accountTotalAssets => '总资产（当前账本）';

  @override
  String get accountEmptyHint => '还没有账户\n点右下角加一个吧 🐰';

  @override
  String get accountNotInTotal => ' · 不计入总资产';

  @override
  String accountBillingDayDisplay(int day) {
    return '账单日 $day 号';
  }

  @override
  String accountRepaymentDayDisplay(int day) {
    return '还款日 $day 号';
  }

  @override
  String get lockTitle => '应用锁';

  @override
  String get lockEnterPin => '请输入 PIN 解锁边边记账';

  @override
  String get lockEnterCurrentPinToDisable => '请输入当前 PIN 以关闭应用锁';

  @override
  String get lockEnterCurrentPinToVerify => '请输入当前 PIN 以验证身份';

  @override
  String get lockForgotPin => '忘记 PIN';

  @override
  String get lockForgotPinMsg =>
      '忘记 PIN 后无法通过应用内方式重置。\n如需继续使用，只能：\n\n1. 清除本应用全部数据（卸载或清除数据），重新开始；\n2. 如有云端备份，重装后可恢复数据。\n\n请注意：清除数据将丢失所有本地记账内容。';

  @override
  String get lockAcknowledgeAndDisable => '我已知晓，关闭应用锁';

  @override
  String get lockEnableAppLock => '启用应用锁';

  @override
  String get lockEnabled => '已开启 · PIN 已设置';

  @override
  String get lockDisabling => '关闭中 · 启动 / 切回前台时不再要求 PIN';

  @override
  String get lockChangePin => '修改 PIN';

  @override
  String get lockDisableHint => '关闭应用锁；如需清空本地数据请先确认云端有最新备份';

  @override
  String get lockSecurityNote => '安全说明';

  @override
  String get lockSecurityNoteMsg =>
      'PIN 存储在设备安全硬件中（Android Keystore / iOS Keychain），以加盐哈希形式保存，无法被逆向读取。\n\n生物识别解锁由操作系统原生 API 提供认证，本应用不接触指纹/面容原始数据。\n\n后台超时锁屏依赖 App 生命周期事件，如果系统强制杀进程则无法触发。';

  @override
  String get lockVerifyBiometric => '验证身份以启用生物识别解锁';

  @override
  String get lockBiometricEnabled => '已启用';

  @override
  String get lockBiometricCancelled => '已取消，未启用生物识别';

  @override
  String get lockBiometricLockedOut => '生物识别被系统临时锁定，请稍后再试';

  @override
  String get lockBiometricNotAvailable => '当前设备暂不可用';

  @override
  String get lockBiometricNotRecognized => '验证未通过，未启用生物识别';

  @override
  String get lockBiometricTitle => '生物识别';

  @override
  String get lockBiometricDetecting => '正在检测设备…';

  @override
  String lockBiometricDetectFailed(String error) {
    return '检测失败：$error';
  }

  @override
  String get lockBiometricNotSupported => '本设备不支持生物识别';

  @override
  String get lockBiometricNotEnrolled => '请先在系统设置录入指纹 / 面容';

  @override
  String get lockBiometricReadingPrefs => '正在读取偏好…';

  @override
  String get lockBiometricEnabledDesc => '已开启 · 解锁时优先弹出系统面板';

  @override
  String get lockBiometricDisabledDesc => '解锁时仅使用 PIN（开启需要先验证一次）';

  @override
  String get lockLockNow => '立即锁定';

  @override
  String lockSeconds(int count) {
    return '$count 秒';
  }

  @override
  String lockMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String lockHours(int count) {
    return '$count 小时';
  }

  @override
  String get lockBackgroundTimeout => '后台超时锁定';

  @override
  String get lockLockNowDesc => '立即锁定 · 任何后台→前台切换都会要求 PIN';

  @override
  String lockTimeoutDesc(String label) {
    return '$label · 后台超过该时长后回到前台需要 PIN';
  }

  @override
  String get lockPrivacyMode => '隐私模式';

  @override
  String get lockPrivacyEnabledDesc => '已开启 · 多任务预览模糊 + Android 阻止截屏';

  @override
  String get lockPrivacyDisabledDesc => '关闭中 · 多任务切换器可见 App 当前画面';

  @override
  String get pinSetupNew => '设置应用锁 PIN';

  @override
  String get pinSetupChange => '修改应用锁 PIN';

  @override
  String pinSetupHint(int min, int max) {
    return '请输入 $min-$max 位数字 PIN，避免使用生日等易猜组合。';
  }

  @override
  String get pinSetupConfirmHint => '请再次输入相同 PIN 以确认。';

  @override
  String get pinSetupMismatch => '两次输入不一致，请重新设置';

  @override
  String get pinNewLabel => '新 PIN';

  @override
  String get pinConfirmLabel => '确认 PIN';

  @override
  String pinValidationError(int min, int max) {
    return 'PIN 必须为 $min-$max 位数字';
  }

  @override
  String get pinDigitsOnly => 'PIN 仅允许数字';

  @override
  String get pinUnlockTitle => '请输入应用锁 PIN';

  @override
  String get pinUnlockBiometricVerify => '验证身份以解锁边边记账';

  @override
  String get pinUnlockBiometricLockedOut => '生物识别已被系统临时锁定，请改用 PIN';

  @override
  String get pinUnlockBiometricUnavailable => '生物识别暂不可用，请改用 PIN';

  @override
  String get pinUnlockBiometricFailed => '生物识别未通过，请改用 PIN';

  @override
  String get pinUnlockTooManyErrors => '错误次数过多，已进入冷却';

  @override
  String pinUnlockAttemptsLeft(int left) {
    return 'PIN 错误，剩余尝试次数 $left';
  }

  @override
  String pinUnlockCooldown(int seconds) {
    return '冷却中（$seconds 秒）';
  }

  @override
  String get pinUnlockBiometricHint => '请按提示完成生物识别…';

  @override
  String get pinUnlockBiometricButton => '使用指纹 / 面容解锁';

  @override
  String get importExportTitle => '导入 / 导出';

  @override
  String get importExportExport => '导出';

  @override
  String get importExportExportSubtitle => 'CSV / JSON / 加密 .bbbak';

  @override
  String get importExportImport => '导入';

  @override
  String get importExportImportSubtitle => '支持本 App 导出的 JSON / CSV / .bbbak';

  @override
  String get exportTitle => '导出';

  @override
  String get exportFormat => '格式';

  @override
  String get exportEncrypted => '加密';

  @override
  String get exportRange => '范围';

  @override
  String get exportCurrentLedger => '当前账本';

  @override
  String get exportAllLedgers => '全部账本';

  @override
  String get exportCurrentLedgerHint => '仅当前选中账本';

  @override
  String get exportAllLedgersHint => '包含所有未删除账本(含归档)';

  @override
  String get exportTimeRange => '时间区间';

  @override
  String get exportAllTime => '全部时间';

  @override
  String get exportCustomTime => '自定义';

  @override
  String get exporting => '正在导出…';

  @override
  String get exportAndShare => '导出并分享';

  @override
  String get exportCsvDesc => 'Excel / Numbers 直接打开';

  @override
  String get exportJsonDesc => '结构化全量备份(可被「导入」恢复)';

  @override
  String get exportBbbakDesc => '加密备份包(.bbbak)：JSON + AES-256 密码加密，仅本 App 能导入';

  @override
  String get exportPasswordWarning =>
      '该密码用于解密备份。一旦丢失，备份内容将永远无法恢复——请使用密码管理器记录或写在安全的纸上，不要只存在脑子里。';

  @override
  String get exportPassword => '密码';

  @override
  String get exportShowPassword => '显示密码';

  @override
  String get exportHidePassword => '隐藏密码';

  @override
  String get exportReEnterPassword => '再次输入密码';

  @override
  String get exportPasswordMismatch => '两次输入不一致';

  @override
  String get exportCurrentLedgerNotExist => '当前账本不存在';

  @override
  String get exportNoLedgerToExport => '没有可导出的账本';

  @override
  String exportedFile(String filename) {
    return '已导出：$filename';
  }

  @override
  String get exportShareSubject => '边边记账导出';

  @override
  String exportShareText(String format) {
    return '边边记账数据导出 ($format)';
  }

  @override
  String get importTitle => '导入';

  @override
  String get importWritingDb => '正在写入数据库…';

  @override
  String get importSupportedFormats => '支持的文件格式';

  @override
  String get importJsonDesc => 'JSON：本 App 导出的结构化备份（推荐）';

  @override
  String get importBbbakDesc => '.bbbak：本 App 导出的加密备份（需要密码）';

  @override
  String get importCsvDesc => 'CSV：本 App 导出的表格（按账本名匹配）';

  @override
  String get importThirdPartyDesc => '第三方账单：钱迹 / 微信 / 支付宝 CSV（自动识别）';

  @override
  String get importThirdPartyTip =>
      '提示：第三方账单会被识别为单一账本，自动归入当前账本；分类按关键词推测，不能命中的归到「其他」。';

  @override
  String get importSelectFile => '选择备份文件';

  @override
  String get importFilePathError => '文件路径不可读';

  @override
  String importSelectFileFailed(String error) {
    return '选择文件失败：$error';
  }

  @override
  String importSelectedFile(String name) {
    return '已选择：$name';
  }

  @override
  String get importEncryptedFileHint => '此文件已加密。请输入导出时设置的密码。';

  @override
  String get importPassword => '密码';

  @override
  String get importDecryptAndPreview => '解密并预览';

  @override
  String get importInternalError => '内部状态错误：缺少文件字节或类型';

  @override
  String get importPasswordWrong => '密码错误。请检查密码是否正确，或文件是否被损坏。';

  @override
  String importFormatUnrecognized(String message) {
    return '文件格式不识别（$message）。请检查是否选错文件。';
  }

  @override
  String importParseFailed(String error) {
    return '解析失败：$error';
  }

  @override
  String get importFileLabel => '文件';

  @override
  String get importRecognizedAs => '识别为';

  @override
  String get importLedgerCount => '账本数';

  @override
  String get importTxCount => '流水数';

  @override
  String importUnmappedCategoryTip(int count) {
    return '其中 $count 条按关键词未匹配到本地分类，已归入「其他」。';
  }

  @override
  String get importExportTime => '导出时间';

  @override
  String get importSourceDevice => '来源设备';

  @override
  String importSampleRows(int count) {
    return '前 $count 行预览';
  }

  @override
  String get importNoTxInBackup => '备份内不含流水';

  @override
  String get importDedupStrategy => '去重策略';

  @override
  String get importDedupSkip => '跳过已存在';

  @override
  String get importDedupSkipDesc => 'ID 相同时跳过，不覆盖已有数据（最安全）';

  @override
  String get importDedupOverwrite => '覆盖';

  @override
  String get importDedupOverwriteDesc => 'ID 相同时用备份覆盖本地（备份优先）';

  @override
  String get importDedupAllNew => '全部作为新记录';

  @override
  String get importDedupAllNewDesc => '忽略 ID，所有记录重新生成 ID 写入（可能产生重复）';

  @override
  String get importConfirmImport => '确认导入';

  @override
  String importWriteFailed(String error) {
    return '写入失败：$error';
  }

  @override
  String get importComplete => '导入完成';

  @override
  String importUpsertCount(String label) {
    return '$label';
  }

  @override
  String importLedgerUpsert(int count) {
    return '账本 $count 条 upsert';
  }

  @override
  String importCategoryUpsert(int count) {
    return '分类 $count 条 upsert';
  }

  @override
  String importAccountUpsert(int count) {
    return '账户 $count 条 upsert';
  }

  @override
  String importTxWrite(int written, int skipped) {
    return '流水 $written 条写入 / $skipped 条跳过';
  }

  @override
  String importBudgetUpsert(int count) {
    return '预算 $count 条 upsert';
  }

  @override
  String importLedgerNotMatched(String name) {
    return '提示：账本「$name」未匹配到，已归入当前账本。';
  }

  @override
  String get importContinueOther => '继续导入其他文件';

  @override
  String get importUnknownError => '未知错误';

  @override
  String get importReselect => '重新选择';

  @override
  String get importBbbakLabel => '加密备份 (.bbbak)';

  @override
  String get syncTitle => '云服务';

  @override
  String get syncEnable => '启用云同步';

  @override
  String syncCurrentBackend(String name) {
    return '当前后端：$name';
  }

  @override
  String get syncDisabled => '关闭中——数据仅保存在本机';

  @override
  String get syncSelfHostedWebdav => '自托管 WebDAV 服务';

  @override
  String get syncS3Compatible => 'S3 兼容存储';

  @override
  String get syncS3Desc => 'Cloudflare R2, AWS S3, MinIO 等';

  @override
  String get syncUseSupabase => '使用 Supabase 后端';

  @override
  String get syncLastTestFailed => '上次连接测试失败，点击右侧设置重新配置';

  @override
  String get syncNotConfiguredShort => '（未配置）';

  @override
  String get syncUseIcloud => '使用 iCloud Drive 同步';

  @override
  String get syncIcloudUnavailable => 'iCloud 不可用，请检查系统设置';

  @override
  String get syncSwitchConfirm => '切换云服务?';

  @override
  String get syncSwitchHint => '切换服务后，需要重新进行首次同步。';

  @override
  String get syncMigrateAttachments => '迁移附件到新后端？';

  @override
  String get syncMigrateAttachmentsHint =>
      '迁移会将已上传的附件从旧后端下载后重新上传到新后端。此过程可能耗时较长，取决于附件数量与网络状况。\n\n如果选择「暂不迁移」，已上传的附件仍保留在旧后端，新上传的附件会存到新后端。';

  @override
  String get syncSkipMigration => '暂不迁移';

  @override
  String get syncMigrate => '迁移';

  @override
  String syncSwitchNotConfigured(String type) {
    return '切换失败：$type 尚未配置，请先点击右侧设置图标完成配置';
  }

  @override
  String syncSwitchedWithMigration(String type, int migrated) {
    return '已切换到 $type（已标记 $migrated 条流水的附件待重传）';
  }

  @override
  String syncSwitched(String type) {
    return '已切换到 $type';
  }

  @override
  String get syncDisableConfirm => '关闭云同步?';

  @override
  String get syncDisableHint => '关闭后将仅使用本机数据，已上传到云端的备份不受影响。';

  @override
  String get syncCloudDisabled => '云同步已关闭';

  @override
  String get syncPleaseConfigureFirst => '请先在下方任选一个云服务并完成配置';

  @override
  String syncEnabledWith(String type) {
    return '已启用云同步：$type';
  }

  @override
  String get syncLocalStorage => '本地存储';

  @override
  String get syncConfigSavedAndTested => '配置已保存并通过连接测试';

  @override
  String syncConfigSavedTestFailed(String error) {
    return '配置已保存，但连接测试失败：$error';
  }

  @override
  String get syncConfigInvalid => '配置无效';

  @override
  String get syncProviderInitNull => 'Provider 初始化返回空';

  @override
  String get syncConfigSupabase => '配置 Supabase';

  @override
  String get syncCustomName => '自定义名称';

  @override
  String get syncCustomNameHint => '用作卡片标题（可选）';

  @override
  String get syncConfigWebdav => '配置 WebDAV';

  @override
  String get syncWebdavUsername => '用户名';

  @override
  String get syncWebdavPassword => '密码';

  @override
  String get syncWebdavRemotePath => '远程路径';

  @override
  String get syncConfigS3 => '配置 S3';

  @override
  String get syncS3CustomNameHint => '用作卡片标题与云端文件夹名（可选）';

  @override
  String syncLedgerLoadFailed(String error) {
    return '账本加载失败：$error';
  }

  @override
  String syncInitFailed(String error) {
    return '同步服务初始化失败：$error';
  }

  @override
  String get syncUploaded => '已上传到云端';

  @override
  String get syncRestoreFromCloud => '从云端恢复';

  @override
  String get syncRestoreConfirmMsg => '当前账本的本地流水与预算将被云端备份覆盖...';

  @override
  String get syncRestore => '恢复';

  @override
  String syncRestoredCount(int count) {
    return '已恢复 $count 条流水';
  }

  @override
  String get syncRestored => '已从云端恢复';

  @override
  String get syncDeleteCloudBackup => '删除云端备份';

  @override
  String get syncDeleteCloudConfirm => '云端的此账本备份将被删除。本地数据不受影响。继续？';

  @override
  String get syncCloudDeleted => '云端备份已删除';

  @override
  String get syncRefreshStatus => '刷新状态';

  @override
  String get syncFetchingStatus => '正在获取云端状态…';

  @override
  String syncStatusFetchFailed(String error) {
    return '状态获取失败：$error';
  }

  @override
  String get syncUpload => '上传';

  @override
  String get syncDownload => '下载';

  @override
  String get syncDeleteCloudBackupShort => '删除云端备份';

  @override
  String get syncStatusNotConfigured => '未配置';

  @override
  String get syncStatusNotLoggedIn => '未登录';

  @override
  String get syncStatusNoBackup => '云端无备份';

  @override
  String get syncStatusSynced => '已同步';

  @override
  String get syncStatusLocalNewer => '本地较新（建议上传）';

  @override
  String get syncStatusCloudNewer => '云端较新（建议下载）';

  @override
  String get syncStatusDiverged => '本地与云端不一致';

  @override
  String get syncStatusUploading => '上传中…';

  @override
  String get syncStatusDownloading => '下载中…';

  @override
  String get syncStatusError => '错误';

  @override
  String get syncStatusUnknown => '未知';

  @override
  String syncLastSyncAt(String time) {
    return '上次同步：$time';
  }

  @override
  String syncLocalCloudCount(int local, int cloud) {
    return '本地 $local · 云端 $cloud';
  }

  @override
  String get syncTriggerInProgress => '同步进行中';

  @override
  String get syncTriggerNotConfigured => '未配置云服务';

  @override
  String get syncTriggerNetworkUnavailable => '网络不可用';

  @override
  String get trashTitle => '垃圾桶';

  @override
  String get reminderTitle => '提醒';

  @override
  String get reminderDailyTitle => '每日记账提醒';

  @override
  String reminderDailyOn(String time) {
    return '每天 $time 提醒你记一笔';
  }

  @override
  String get reminderOff => '未开启';

  @override
  String get reminderTime => '提醒时间';

  @override
  String get reminderTest => '测试提醒';

  @override
  String get reminderTestHint => '立即发送一条测试通知';

  @override
  String get reminderEnableHint =>
      '开启后，每天在设定时间会收到一条可爱的记账提醒 🐻\n如果通知没有按时出现，请检查系统通知权限设置。';

  @override
  String get reminderPermissionDenied => '通知权限被拒绝，无法开启提醒';

  @override
  String get reminderSelectTime => '选择提醒时间';

  @override
  String reminderEnabledAt(String time) {
    return '已开启，每天 $time 提醒你';
  }

  @override
  String get reminderDisabled => '已关闭每日提醒';

  @override
  String reminderTimeUpdated(String time) {
    return '提醒时间已更新为 $time';
  }

  @override
  String get reminderTestSent => '测试通知已发送 🐻';

  @override
  String get reminderNotificationTitle => '每日记账提醒';

  @override
  String get reminderNotificationBody => '每天定时提醒你记一笔';

  @override
  String get reminderTestNotification => '这是一条测试提醒 🐻 记账时间到啦！';

  @override
  String get widgetAppName => '边边记账';

  @override
  String get attachmentNotSynced => '未同步';

  @override
  String get attachmentCacheTitle => '附件缓存';

  @override
  String get attachmentCacheCurrentUsage => '当前占用';

  @override
  String get attachmentCacheCalculating => '计算中…';

  @override
  String attachmentCacheUsage(String used, String limit) {
    return '$used / $limit 上限';
  }

  @override
  String get attachmentCacheClear => '清除缓存';

  @override
  String get attachmentCacheClearDesc => '删除本地缓存的附件文件，不影响原图与云端备份';

  @override
  String get attachmentCacheClearConfirm => '清除附件缓存？';

  @override
  String get attachmentCacheClearConfirmMsg =>
      '只删除本地缓存文件，不影响您原始保存的图片与云端备份。下次查看流水时会重新从云端下载。';

  @override
  String attachmentCacheCleared(String size) {
    return '已清除约 $size';
  }

  @override
  String get attachmentCacheLazyLoadDesc =>
      '附件懒加载：仅当查看流水详情时才从云端下载图片，节省流量。系统在空间紧张时会自动清理缓存目录，下次查看会重新下载。';

  @override
  String get multiCurrencyTitle => '多币种';

  @override
  String get multiCurrencyRefreshNow => '立即刷新汇率';

  @override
  String get multiCurrencyRefreshed => '汇率已更新';

  @override
  String get multiCurrencyRefreshFailed => '联网失败，使用现有快照';

  @override
  String multiCurrencyAutoRestored(String code) {
    return '$code 已恢复自动刷新';
  }

  @override
  String multiCurrencyManualSet(String code, String rate) {
    return '$code 汇率已手动设为 $rate';
  }

  @override
  String get multiCurrencyEnable => '开启多币种';

  @override
  String get multiCurrencyEnableHint => '开启后，记账页可选择币种；统计按账本默认币种换算展示。';

  @override
  String get multiCurrencyBuiltIn => '内置币种';

  @override
  String get multiCurrencyRateManagement => '汇率管理';

  @override
  String get multiCurrencyRateHint => '点击行可手动设置汇率；标记为「手动」的行不会被自动刷新覆盖。';

  @override
  String get multiCurrencyBase => '基准';

  @override
  String get multiCurrencyManual => '手动';

  @override
  String get multiCurrencyAuto => '自动';

  @override
  String multiCurrencyUpdatedAt(String time) {
    return '更新于 $time';
  }

  @override
  String get multiCurrencyInputPositive => '请输入正数（例如 7.20）';

  @override
  String multiCurrencySetRate(String code) {
    return '设置 $code 汇率';
  }

  @override
  String multiCurrencyRateQuestion(String code) {
    return '1 $code 等于多少 CNY？';
  }

  @override
  String get multiCurrencyRateExample => '例如 7.20';

  @override
  String get multiCurrencyManualOverrideHint => '当前为手动覆盖，自动刷新不会修改它。';

  @override
  String get multiCurrencyResetToAuto => '重置为自动';

  @override
  String get multiCurrencyCnyBaseError => 'CNY 是基准币种，不可手动覆盖';

  @override
  String get multiCurrencyRateMustBePositive => '汇率必须为正数';

  @override
  String get aiInputTitle => '快速输入 · AI 增强';

  @override
  String get aiInputEnable => '启用 AI 增强';

  @override
  String get aiInputEnableHint =>
      '开启后，本地解析置信度低时确认卡片会出现 \"✨ AI 增强\" 按钮，调用你配置的 LLM 兜底解析。';

  @override
  String get aiInputApiConfig => 'API 配置';

  @override
  String get aiInputApiHint =>
      '使用 OpenAI 兼容协议（chat/completions）。endpoint 完整 URL，例如：';

  @override
  String get aiInputHidden => '隐藏';

  @override
  String get aiInputShown => '显示';

  @override
  String get aiInputPromptTemplate => 'Prompt 模板（可选）';

  @override
  String aiInputPromptPlaceholderHint(
    Object CATEGORIES,
    Object NOW,
    Object TEXT,
  ) {
    return '占位符 $NOW / $TEXT / $CATEGORIES 会在调用时替换。留空使用内置默认模板。';
  }

  @override
  String get aiInputPromptTemplateLabel => 'Prompt 模板';

  @override
  String get aiInputSaved => 'AI 增强配置已保存';

  @override
  String get aiInputNotConfigured => '未配置 AI 增强（需启用并填写 endpoint / key / model）';

  @override
  String aiInputEndpointInvalid(String endpoint) {
    return 'endpoint 不是合法 URL：$endpoint';
  }

  @override
  String get aiInputTimeout => '网络请求超时';

  @override
  String aiInputNetworkFailed(String error) {
    return '网络请求失败：$error';
  }

  @override
  String aiInputHttpError(int status) {
    return 'LLM 返回 HTTP $status';
  }

  @override
  String aiInputInvalidJson(String error) {
    return 'LLM 响应不是合法 JSON：$error';
  }

  @override
  String get aiInputResponseNotObject => 'LLM 响应根不是 JSON 对象';

  @override
  String get aiInputMissingChoices => 'LLM 响应缺少 choices';

  @override
  String get aiInputChoiceNotObject => 'LLM 响应 choice 非对象';

  @override
  String get aiInputMissingMessage => 'LLM 响应缺少 message';

  @override
  String get aiInputContentNotString => 'LLM 响应 content 非字符串';

  @override
  String aiInputContentInvalidJson(String error) {
    return 'LLM 返回的 content 不是合法 JSON：$error';
  }

  @override
  String get aiInputContentNotObject => 'LLM 返回 content 根不是 JSON 对象';

  @override
  String aiInputAmountTypeError(String type) {
    return 'amount 字段类型非法：$type';
  }

  @override
  String aiInputAmountInvalid(String value) {
    return 'amount 不是有效正数：$value';
  }

  @override
  String aiInputParentKeyTypeError(String type) {
    return 'category_parent_key 字段类型非法：$type';
  }

  @override
  String aiInputParentKeyInvalid(String value) {
    return 'category_parent_key 取值非法：$value';
  }

  @override
  String aiInputDateTypeError(String type) {
    return 'occurred_at 字段类型非法：$type';
  }

  @override
  String aiInputDateInvalid(String value) {
    return 'occurred_at 不是合法 ISO 日期：$value';
  }

  @override
  String aiInputNoteTypeError(String type) {
    return 'note 字段类型非法：$type';
  }

  @override
  String get themeTitle => '外观';

  @override
  String get themeLabel => '主题';

  @override
  String get themeSwitchHint => '切换后所有页面即时生效，包括图表与图标底色';

  @override
  String get themeFontSize => '字号';

  @override
  String get themeFontSizeHint => '大字号会在系统字号基础上再放大 15%，小字号缩小 15%';

  @override
  String get themeIconPack => '分类图标';

  @override
  String get themeIconPackSwitchHint => '切换后分类网格与流水列表图标即时更新；自定义图标不受影响';

  @override
  String get themePrimary => '主色';

  @override
  String get themeContainer => '容器';

  @override
  String get themeTertiary => '辅助';

  @override
  String get themeSuccess => '成功';

  @override
  String get themeWarning => '警告';

  @override
  String get themeError => '错误';

  @override
  String get colorSemanticPrimary => '主色';

  @override
  String get colorSemanticContainer => '容器';

  @override
  String get colorSemanticTertiary => '辅助';

  @override
  String get colorSemanticSuccess => '成功';

  @override
  String get colorSemanticWarning => '警告';

  @override
  String get colorSemanticError => '错误';

  @override
  String dateFormatRelative(int month, int day) {
    return '$month月$day日';
  }

  @override
  String dateHeatmapCell(String date) {
    return '$date\n支出：¥...';
  }

  @override
  String get trashTabRecords => '流水';

  @override
  String get trashTabCategories => '分类';

  @override
  String get trashTabAccounts => '账户';

  @override
  String get trashTabLedgers => '账本';

  @override
  String get trashClearCurrent => '清空当前分类';

  @override
  String get trashConfirmClear => '确认清空？';

  @override
  String trashClearConfirmMsg(String label) {
    return '将永久删除全部已软删的「$label」（无法恢复）。';
  }

  @override
  String get trashPermanentDelete => '永久删除';

  @override
  String trashCleared(String label) {
    return '已清空「$label」垃圾桶';
  }

  @override
  String trashClearFailed(String error) {
    return '清空失败：$error';
  }

  @override
  String get trashNoDeletedRecords => '没有已删流水';

  @override
  String get trashNoDeletedCategories => '没有已删分类';

  @override
  String get trashNoDeletedAccounts => '没有已删账户';

  @override
  String get trashNoDeletedLedgers => '没有已删账本';

  @override
  String get trashRestored => '已恢复 1 条流水';

  @override
  String trashRestoreFailed(String error) {
    return '恢复失败：$error';
  }

  @override
  String get trashPurgeConfirm => '永久删除这条流水？';

  @override
  String get trashPurged => '已永久删除';

  @override
  String trashPurgeFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String trashRestoredCategory(String name) {
    return '已恢复分类「$name」';
  }

  @override
  String trashPurgeCategoryConfirm(String name) {
    return '永久删除分类「$name」？';
  }

  @override
  String trashRestoredAccount(String name) {
    return '已恢复账户「$name」';
  }

  @override
  String trashPurgeAccountConfirm(String name) {
    return '永久删除账户「$name」？';
  }

  @override
  String trashRestoredLedger(String name) {
    return '已恢复账本「$name」';
  }

  @override
  String trashPurgeLedgerConfirm(String name) {
    return '永久删除账本「$name」？\n该账本下所有流水和预算也会一并永久删除（无法恢复）。';
  }

  @override
  String get trashPurgedLedger => '已永久删除账本';

  @override
  String trashRemainingDays(int days, String date) {
    return '剩余 $days 天 · 删于 $date';
  }

  @override
  String get trashRestore => '恢复';

  @override
  String get trashAutoCleanHint => '已软删 30 天后会自动清理';

  @override
  String get trashConfirmPermanentDelete => '确认永久删除？';

  @override
  String get trashLedgerSubtitle => '账本 · 恢复时会一并复活级联删除的流水/预算';

  @override
  String trashTxSubtitleTransfer(String date) {
    return '$date · 转账';
  }

  @override
  String get detailType => '类型';

  @override
  String get detailTransferFrom => '转出';

  @override
  String get detailTransferTo => '转入';

  @override
  String get detailAccount => '账户';

  @override
  String get detailTime => '时间';

  @override
  String get detailImages => '图片';

  @override
  String get detailCopy => '复制';

  @override
  String get confirmOk => '确定';

  @override
  String syncNotConfiguredFormat(String defaultText) {
    return '$defaultText（未配置）';
  }

  @override
  String syncMigrateAttachmentsDetail(int count, String type) {
    return '当前后端已上传 $count 张附件。\n\n切换后新附件会上传到 $type，但已在旧后端的附件不会跨设备访问。\n\n选择「迁移」会在下次同步时把这些附件重新上传到新后端（耗时较长，取决于网络与图片数量）；选择「暂不迁移」则旧附件保留在旧后端，可稍后切回去再用。';
  }

  @override
  String syncError(String error) {
    return '错误: $error';
  }

  @override
  String syncSwitchFailed(String error) {
    return '切换失败: $error';
  }

  @override
  String get exportBbbakLabel => '加密备份 .bbbak';

  @override
  String get importCsvThirdPartyDesc =>
      '第三方账单不含本 App 的 ID，会作为「全部新记录」导入；账本归入当前账本，账户列若与现有账户同名会被关联，否则置空。';

  @override
  String get importCsvNoIdDesc =>
      'CSV 文件不含 ID，只能作为「全部新记录」导入；账本/分类/账户按名称匹配，匹配不到时归到当前账本，分类/账户列空。';

  @override
  String get pinUnlockSubtitle => '请输入应用锁 PIN';

  @override
  String get ledgerDefaultName => '账本';

  @override
  String get statsTooltipDateFormat => 'M月d日';

  @override
  String get a11yRecordHomeNewFab => '记一笔';

  @override
  String get a11yRecordHomeSearch => '搜索流水';

  @override
  String get a11yRecordHomeSwapCurrency => '切换主副币种';

  @override
  String get a11yRecordHomePrevMonth => '上一月';

  @override
  String get a11yRecordHomeNextMonth => '下一月';

  @override
  String get a11yRecordHomeDismissReminder => '关闭提示';

  @override
  String get a11yRecordNewBack => '返回';

  @override
  String get a11yQuickConfirmClose => '关闭';

  @override
  String get a11yCloudServiceConfigure => '配置';

  @override
  String get a11yAttachmentImage => '已添加图片';

  @override
  String get meAbout => '关于';

  @override
  String get about => '关于';

  @override
  String get aboutAppName => '边边记账';

  @override
  String get aboutAppTagline => '温暖陪伴你每一笔记录 🐰';

  @override
  String get aboutAppVersion => '版本';

  @override
  String aboutAppVersionValue(String version, String build) {
    return '$version（构建 $build）';
  }

  @override
  String get aboutPrivacyPolicy => '隐私政策';

  @override
  String get aboutTermsOfService => '用户协议';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get aboutLicensesLegalese => '本应用使用了若干开源组件，特此致谢。';

  @override
  String get aboutRevokeConsent => '撤回同意';

  @override
  String get aboutRevokeConsentSubtitle => '撤回后退出应用，下次启动需要重新同意';

  @override
  String get aboutRevokeConsentConfirmTitle => '撤回同意？';

  @override
  String get aboutRevokeConsentConfirmMessage =>
      '撤回后将立即退出应用，下次启动会重新征求您的同意。已记录的本地数据不会被清除。';

  @override
  String get aboutRevokeConsentConfirm => '撤回并退出';

  @override
  String get privacyConsentTitle => '隐私政策与用户协议';

  @override
  String get privacyConsentIntro =>
      '感谢使用边边记账。在开始使用前，请阅读以下隐私政策与用户协议。点击「同意并继续」表示您已阅读并同意本政策。';

  @override
  String get privacyConsentDataSectionTitle => '我们收集哪些数据';

  @override
  String get privacyConsentDataSectionBody =>
      '本应用为离线优先记账工具：流水、账本、分类、账户、预算、附件等数据默认仅保存在您的设备本地，存于 SQLCipher 加密的 SQLite 数据库中。仅当您主动开启云同步时，相应数据才会上传至您指定的云服务（您自建的 Supabase / WebDAV / S3 / iCloud Drive 等）。';

  @override
  String get privacyConsentUsageSectionTitle => '数据用途';

  @override
  String get privacyConsentUsageSectionBody =>
      '数据仅用于您本人的记账、统计、预算与提醒功能；本应用不进行任何形式的广告投放、用户画像、行为分析或第三方分享。';

  @override
  String get privacyConsentStorageSectionTitle => '存储位置';

  @override
  String get privacyConsentStorageSectionBody =>
      '本地数据存于设备文档目录的加密 SQLite 文件中；数据库密钥保存在系统 Keystore（Android）/ Keychain（iOS），永不离开设备。云同步数据存于您自行配置的云服务，本应用作者不接触任何用户数据。';

  @override
  String get privacyConsentSharingSectionTitle => '数据共享';

  @override
  String get privacyConsentSharingSectionBody =>
      '我们不会将您的数据共享给任何第三方。云同步、AI 增强等可选功能会按您的配置向您指定的服务（如您自建的 Supabase、您填写的 LLM API）发送相应数据；这些请求由您直接发起，对方为您选择的服务提供商，与本应用作者无关。';

  @override
  String get privacyConsentRightsSectionTitle => '您的权利';

  @override
  String get privacyConsentRightsSectionBody =>
      '您可随时通过「我的 → 关于 → 撤回同意」撤回本次授权；撤回后应用会退出，下次启动需要重新同意才能继续使用。所有本地数据可通过「导入 / 导出」功能完整导出或一键清除；流水删除走垃圾桶，可在 30 天内恢复。';

  @override
  String get privacyConsentContactSectionTitle => '联系方式';

  @override
  String get privacyConsentContactSectionBody =>
      '如对本政策有疑问，可通过应用源码仓库的 Issue 反馈。';

  @override
  String get privacyConsentVersionLabel => '政策版本';

  @override
  String get privacyConsentVersionValue => '1.0（2026-05-14 生效）';

  @override
  String get privacyConsentAccept => '同意并继续';

  @override
  String get privacyConsentReject => '不同意';

  @override
  String get privacyConsentRejectAlertTitle => '未同意将无法使用';

  @override
  String get privacyConsentRejectAlertMessage =>
      '未同意隐私政策与用户协议将无法使用本应用。点击「退出」立即关闭应用；点击「再次阅读」回到政策文本。';

  @override
  String get privacyConsentRejectAlertExit => '退出';

  @override
  String get privacyConsentRejectAlertReread => '再次阅读';

  @override
  String get termsOfServiceTitle => '用户协议';

  @override
  String get termsOfServiceIntro => '欢迎使用边边记账。使用本应用即表示您同意以下条款。';

  @override
  String get termsOfServiceLicenseSectionTitle => '使用许可';

  @override
  String get termsOfServiceLicenseSectionBody =>
      '本应用免费提供给您用于个人记账用途。在遵守本协议的前提下，您可在自己的设备上安装、使用、复制本应用。';

  @override
  String get termsOfServiceResponsibilitySectionTitle => '用户责任';

  @override
  String get termsOfServiceResponsibilitySectionBody =>
      '您应妥善保管设备与同步凭证；因您本人疏忽（如丢失设备、泄露同步凭证、忘记密码导致无法解密）造成的数据损失，本应用作者不承担责任。请定期使用「导入 / 导出」功能备份重要数据。';

  @override
  String get termsOfServiceDisclaimerSectionTitle => '免责声明';

  @override
  String get termsOfServiceDisclaimerSectionBody =>
      '本应用按「现状」提供，作者不对应用的可用性、准确性、完整性作出任何明示或默示的担保。在适用法律允许的最大范围内，作者不对因使用本应用而产生的任何直接或间接损失承担责任。';

  @override
  String get termsOfServiceVersionLabel => '协议版本';

  @override
  String get termsOfServiceVersionValue => '1.0（2026-05-14 生效）';
}
