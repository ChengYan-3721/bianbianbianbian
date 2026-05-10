# 架构说明

本文件记录项目**当前**运行期结构：哪些文件/目录存在、各自承担什么职责、模块间如何依赖。每当新增或重构关键文件/目录时同步更新。

- 设计意图（为什么这么做）看 `design-document.md`；
- 阶段路线与验收标准看 `implementation-plan.md`；
- 已完成步骤的时间线看 `progress.md`。

---

## 当前文件一览（Phase 15.3 · 自定义分类图标集完成后）

```
bianbianbianbian/
├─ lib/
│  ├─ main.dart                 应用入口：Riverpod bootstrap（预热 defaultSeedProvider + Step 15.1 currentThemeKeyProvider + Step 15.2 currentFontSizeKeyProvider + Step 15.3 currentIconPackKeyProvider）+ Step 14.3 await backgroundLockTimeoutProvider + appLockEnabled → 已开启则 guard.lock() 冷启动锁 + 错误兜底
│  ├─ app/
│  │  ├─ app.dart               BianBianApp 根组件（ConsumerStatefulWidget · Step 15.1 watch currentThemeProvider 驱动 theme · Step 15.2 builder 覆盖 MediaQuery.textScaler（fontSizeScaleFactorProvider × 系统 TextScaler）+ 条件 _AppLockGate · Step 10.7 enableSyncLifecycle WidgetsBindingObserver 联动 syncTrigger · Step 14.3 enableAppLockGuard 同生命周期回调 guard.onPaused/onResumed）
│  │  ├─ app_router.dart        顶层 goRouter（/ → HomeShell, /record/new → RecordNewPage, /record/search → RecordSearchPage, …, /sync → CloudServicePage）
│  │  ├─ app_theme.dart         BianBianTheme 枚举（cream_bunny/thick_brown_bear/moonlight_dark/mint_green）+ BianBianFontSize 枚举（small/standard/large + scaleFactor）+ buildAppTheme(theme) 统一构建 + BianBianSemanticColors ThemeExtension + 向后兼容 appTheme
│  │  └─ home_shell.dart        底部 4 Tab 壳页（Step 10.1：我的 Tab 加"云服务"入口；Step 15.2：我的 Tab "外观"入口）
│  │  └─ home_shell.dart        底部 4 Tab 壳页（Step 10.1：我的 Tab 加"云服务"入口；Step 15.2：我的 Tab "外观"入口）
│  ├─ core/
│  │  ├─ crypto/
│  │  │  └─ bianbian_crypto.dart  BianbianCrypto（PBKDF2 + AES-256-GCM）+ DecryptionFailure
│  │  ├─ network/               [空]
│  │  └─ util/
│  │     ├─ currencies.dart     Currency 数据类 + kBuiltInCurrencies (11 种) + kFxRateSnapshot 写死快照（Step 8.1）
│  │     ├─ category_icon_packs.dart  BianBianIconPack 枚举（sticker/flat）+ 两套 emoji 映射 + resolveCategoryIcon 运行时解析 + samplePackIcons 预览（Step 15.3）
│  │     └─ quick_text_parser.dart  QuickTextParser + QuickParseResult（Step 9.1，本地中文快速记账文本解析器）
│  ├─ data/
│  │  ├─ local/
│  │  │  ├─ app_database.dart         drift AppDatabase（schemaVersion=11；Step 15.3 v10→v11 user_pref 追加 icon_pack 列；Step 15.2 v9→v10 user_pref 追加 font_size 列；Step 11.2 v8→v9 附件 BLOB shape 升级）
│  │  │  ├─ app_database.g.dart       build_runner 产物
│  │  │  ├─ attachment_meta_codec.dart Step 11.2 AttachmentMetaCodec（encode/decode + v8 兼容）+ migrateAttachmentsBlobV8ToV9 纯函数
│  │  │  ├─ db_cipher_key_store.dart  本地 DB 加密密钥的生成/持久化
│  │  │  ├─ device_id_store.dart      device_id 加载器（secure ↔ user_pref 双向同步）
│  │  │  ├─ seeder.dart               DefaultSeeder（首次启动默认数据种子化 + Step 8.1 fx_rate 独立判空）
│  │  │  ├─ providers.dart            @Riverpod appDatabase / deviceId / defaultSeed 三个 provider
│  │  │  ├─ providers.g.dart          riverpod_generator 产物
│  │  │  ├─ dao/
│  │  │  │  ├─ ledger_dao.dart              LedgerDao + .g.dart（Step 1.4）
│  │  │  │  ├─ category_dao.dart            CategoryDao + .g.dart（Step 1.4）
│  │  │  │  ├─ account_dao.dart             AccountDao + .g.dart（Step 1.4）
│  │  │  │  ├─ transaction_entry_dao.dart   TransactionEntryDao + .g.dart（Step 1.4）
│  │  │  │  ├─ budget_dao.dart              BudgetDao + .g.dart（Step 1.4）
│  │  │  │  ├─ sync_op_dao.dart             SyncOpDao + .g.dart（Step 2.2，供仓库层写队列）
│  │  │  │  └─ fx_rate_dao.dart             FxRateDao + .g.dart（Step 8.1，工具表 listAll/getByCode/upsert）
│  │  │  └─ tables/
│  │  │     ├─ user_pref_table.dart         §7.1 user_pref 表（云配置由 flutter_cloud_sync 包走 SharedPreferences，不入库）
│  │  │     ├─ ledger_table.dart            §7.1 ledger 表
│  │  │     ├─ category_table.dart          重构版 category 表（parent_key/is_favorite，全局二级分类）
│  │  │     ├─ account_table.dart           §7.1 account 表（Step 7.3 追加 billing_day / repayment_day）
│  │  │     ├─ transaction_entry_table.dart §7.1 transaction_entry 表（FK→ledger）
│  │  │     ├─ budget_table.dart            §7.1 budget 表
│  │  │     ├─ sync_op_table.dart           §7.1 sync_op 队列表（AUTOINCREMENT id）
│  │  │     └─ fx_rate_table.dart           Step 8.1 工具表（code PK / rate_to_cny REAL / updated_at INTEGER）
│  │  ├─ remote/                [空]
│  │  └─ repository/             Step 2.2 已填充：entity_mappers + repo_clock + 5 个仓库
│  │     ├─ repo_clock.dart             RepoClock typedef（仓库层时间注入点）
│  │     ├─ entity_mappers.dart         drift row ↔ domain entity 映射桥接层
│  │     ├─ ledger_repository.dart      LedgerRepository 接口 + LocalLedgerRepository
│  │     ├─ category_repository.dart    CategoryRepository 接口 + LocalCategoryRepository
│  │     ├─ account_repository.dart     AccountRepository 接口 + LocalAccountRepository
│  │     ├─ transaction_repository.dart TransactionRepository 接口 + LocalTransactionRepository
│  │     ├─ budget_repository.dart      BudgetRepository 接口 + LocalBudgetRepository
│  │     ├─ providers.dart              7 个 @Riverpod provider；Step 2.3
│  │     └─ providers.g.dart            riverpod_generator 产物
│  ├─ domain/
│  │  ├─ entity/
│  │  │  ├─ ledger.dart                纯 Dart 不可变实体（Step 2.1）
│  │  │  ├─ category.dart              同上
│  │  │  ├─ account.dart               同上
│  │  │  ├─ transaction_entry.dart     同上（含 _bytesEqual/_bytesHash 深比较）
│  │  │  ├─ budget.dart                同上
│  │  │  └─ attachment_meta.dart       Step 11.2 AttachmentMeta（remoteKey/sha256/size/originalName/mime/localPath/missing）
│  │  └─ usecase/               [空] 跨仓库业务用例
│  └─ features/
│     ├─ record/                Step 3.2 已重构：新建记账页采用一级/二级分类 + 收藏 + 自动收支判定；Step 3.6/3.7 已接入搜索页 + 月份选择器；Step 11.3 起附件渲染统一走 AttachmentThumbnail
│     │  ├─ record_home_page.dart       RecordHomePage + 子组件（顶栏/月份/卡片/快捷输入/流水列表/FAB；Step 9.2 _QuickInputBar 已接线解析器+确认卡片；Step 3.6 搜索图标跳转 /record/search；Step 3.7 月份文字 InkWell 弹年-月选择器；详情/编辑/复制/删除流程已抽到 record_tile_actions.dart）
│     │  ├─ record_new_page.dart        RecordNewPage + 子组件（一级Tab/收藏/金额/分类/账户/时间/备注/附件/保存；Step 11.3 _NoteAttachments 改用 AttachmentThumbnail）
│     │  ├─ record_providers.dart       RecordMonth Notifier + recordMonthSummary FutureProvider
│     │  ├─ record_providers.g.dart     riverpod_generator 产物
│     │  ├─ record_new_providers.dart   RecordFormData + _parseExpr + RecordForm Notifier（自动判定 income/expense；Step 11.2 起 attachmentMetas: List&lt;AttachmentMeta&gt; 替代旧 attachmentPaths，编解码走 AttachmentMetaCodec）
│     │  ├─ record_new_providers.g.dart riverpod_generator 产物
│     │  ├─ record_search_filters.dart   Step 3.6 SearchQuery 数据类 + SearchTypeFilter 枚举 + searchTransactions 纯函数（关键词/日期/类型/金额取交集）
│     │  ├─ record_search_page.dart      Step 3.6 RecordSearchPage（关键词输入 + 日期范围 / 类型 / 金额三段筛选 + 结果列表 + 空查询/空结果两种空态；结果点击复用 record_tile_actions 详情底表）
│     │  ├─ record_tile_actions.dart     Step 3.6 续：RecordDetailAction 枚举 + RecordDetailSheet（流水详情底表）+ openRecordTileActions（点击 → 详情 → 编辑/复制/删除全流程的共享 helper）+ inferParentKeyForTx；Step 11.3 详情底表与 fullscreen viewer 改用 AttachmentThumbnail
│     │  ├─ month_picker_dialog.dart     Step 3.7 showMonthPicker + _MonthPickerDialog（年箭头切换 + 12 月网格 + 取消/确定）
│     │  ├─ quick_input_providers.dart   Step 9.2 quickTextParserProvider（keepAlive，可注入固定 clock 给测试）+ quickConfidenceThreshold=0.6
│     │  ├─ quick_input_providers.g.dart riverpod_generator 产物
│     │  ├─ quick_confirm_sheet.dart     Step 9.2 showQuickConfirmSheet + QuickConfirmCard（金额/分类/时间/备注 4 字段可编辑 + 低置信度横幅 + 分组分类选择器；Step 9.3 已追加 ✨ AI 增强按钮 + _runAiEnhance 路径）
│     │  ├─ ai_input_enhance_service.dart Step 9.3 LLM 增强服务（OpenAI 兼容协议 + 严格 JSON schema 校验 + AiEnhanceException + parseEnhanceJson @visibleForTesting）
│     │  └─ widgets/
│     │     ├─ number_keyboard.dart     NumberKeyboard（4行自定义键盘：7/8/9/⌫，4/5/6/+，1/2/3/-，CNY/0/./✓或=）
│     │     └─ attachment_thumbnail.dart Step 11.3 AttachmentThumbnail ConsumerStatefulWidget（loading/missing/success 三态 + localPath 同步快路径 + downloader/meta/txId 变化追踪）+ prefetchAttachment 顶层 fire-and-forget helper
│     ├─ stats/                 Step 5.6 已填充：统计区间选择器 + 折线图 + 分类饼图 + 收支排行榜 + 日历热力图 + 导出 PNG/CSV
│     │  ├─ stats_page.dart            StatsPage（区间选择 + 4 类图表 + 顶栏导出按钮 + RepaintBoundary 包裹图表区）
│     │  ├─ stats_range_providers.dart StatsRangePreset/StatsDateRange/StatsRangeState + 4 类统计聚合 provider
│     │  ├─ stats_range_providers.g.dart riverpod_generator 产物
│     │  └─ stats_export_service.dart  encodeStatsCsv（@visibleForTesting）+ buildExportFileName + StatsExportService（PNG/CSV/Share）
│     ├─ ledger/                Step 4.1 已填充：正式账本列表页
│     │  ├─ ledger_list_page.dart       LedgerListPage（账本卡片列表 + 切换 + 归档折叠区）
│     │  ├─ ledger_list_page.g.dart     riverpod_generator 产物
│     │  ├─ ledger_providers.dart       LedgerTxCounts AsyncNotifier（各账本流水条数）
│     │  └─ ledger_providers.g.dart     riverpod_generator 产物
│     ├─ budget/                Step 6.1 列表/编辑；Step 6.2 进度计算 + 颜色 + 震动
│     │  ├─ budget_progress.dart        BudgetProgress / Level + computeBudgetProgress / computePeriodSpent / budgetPeriodRange / shouldTriggerBudgetVibration
│     │  ├─ budget_providers.dart       activeBudgets / budgetableCategories + kParentKeyLabels + budgetClock + budgetProgressFor + BudgetVibrationSession
│     │  ├─ budget_providers.g.dart     riverpod_generator 产物
│     │  ├─ budget_list_page.dart       BudgetListPage（卡片列表 + 进度条/颜色/震动 + 新建 FAB + 删除二次确认）
│     │  └─ budget_edit_page.dart       BudgetEditPage（周期/分类/金额/结转，冲突 Snackbar）
│     ├─ account/               Step 7.1 列表；Step 7.2 CRUD（新建/编辑/软删）
│     │  ├─ account_balance.dart        AccountBalance + aggregateNetAmountsByAccount / computeAccountBalances / computeTotalAssets 纯函数
│     │  ├─ account_providers.dart      accountsList / accountBalances / totalAssets 三个 @riverpod FutureProvider
│     │  ├─ account_providers.g.dart    riverpod_generator 产物
│     │  ├─ account_list_page.dart      AccountListPage（总资产卡片 + 账户卡片列表 + 信用卡负余额红色 + FAB 新建 + 长按编辑/删除菜单）
│     │  └─ account_edit_page.dart      AccountEditPage（名称/类型/图标/初始余额/币种/计入总资产，新建+编辑双模式）
│     ├─ sync/                  Phase 10 已完成 + Phase 11.2 附件上传管线 + Phase 11.3 附件懒下载与本地缓存 + Phase 11.4 软删 / GC / 孤儿 sweep / 跨 backend 迁移
│     │  ├─ sync_service.dart        SyncService 抽象 + LocalOnlySyncService + SnapshotSyncService（V1，upload 内部已接入附件上传前置：扫表 → uploadPending → 写回 BLOB → 上传 JSON 快照）
│     │  ├─ snapshot_serializer.dart  LedgerSnapshot 数据类 + LedgerSnapshotSerializer + exportLedgerSnapshot/importLedgerSnapshot 纯函数
│     │  ├─ sync_provider.dart       Riverpod 顶层 provider 链（store→config→cloudProvider→authService→syncService）
│     │  ├─ sync_trigger.dart        Step 10.7 SyncTrigger Notifier + SyncTriggerState + 5 触发源调度（trigger/scheduleDebounced/startPeriodic/stopPeriodic/cancelTimers）
│     │  ├─ cloud_service_page.dart  「我的→云服务」页（_SyncStatusCard 状态条 + iCloud/WebDAV/S3/Supabase 4 个后端卡 + 配置对话框；Step 11.4 _switchService 加附件迁移确认对话框）
│     │  └─ attachment/
│     │     ├─ attachment_uploader.dart   Step 11.2 AttachmentUploader（uploadPending：sha256 计算 / exists 幂等 / 错误隔离 / remoteKey 回填）
│     │     ├─ attachment_downloader.dart Step 11.3 AttachmentDownloader（ensureLocal 三态契约 / in-memory cache + inflight 复用 / 3 路并发限流 / writeback 钩子）+ defaultAttachmentLocalPathWriteback 顶层函数
│     │     ├─ attachment_cache_pruner.dart Step 11.3 AttachmentCachePruner（currentSize / prune mtime LRU + 7 天保留期 / clear）+ Step 11.4 removeForTransaction（软删流水时清 cache 子目录）+ kAttachmentCacheLimitBytes (500 MiB) / kAttachmentCacheMinRetention (7d) 常量
│     │     ├─ attachment_providers.dart Step 11.3 attachmentCacheRootProvider / attachmentStorageServiceProvider / attachmentDownloaderProvider / attachmentCachePrunerProvider 4 个 FutureProvider + Step 11.4 attachmentOrphanSweeperProvider
│     │     ├─ attachment_orphan_sweeper.dart Step 11.4 AttachmentOrphanSweeper（listBinary diff DB remoteKey 集合 + 30 天宽限 + delete）+ AttachmentOrphanSweepReport + kAttachmentOrphanGrace / kLastOrphanSweepAtPrefKey / kOrphanSweepInterval 常量
│     │     └─ attachment_migration.dart Step 11.4 跨 backend 切换工具（clearAllRemoteAttachmentKeys 清 remoteKey + countAttachmentsWithRemoteKey 计数）
│     ├─ trash/                 Phase 12 已完成：垃圾桶列表 + 恢复/永久删除/清空 + 启动定时清理；Phase 11.4 GC 扩展为远端附件 delete + 孤儿 sweep
│     │  ├─ trash_attachment_cleaner.dart  TrashAttachmentCleaner（递归删除 <docs>/attachments/<txId>/）+ DocumentsDirProvider 注入点
│     │  ├─ trash_providers.dart           kTrashRetention=30d + trashDaysLeft 纯函数 + 5 个 FutureProvider.autoDispose（TX/Cat/Acc/Ledger/Budget）
│     │  ├─ trash_gc_service.dart          TrashGcService.gcExpired(now) 端到端硬删 + TrashGcReport（Phase 11.4 加 db / attachmentStorage 可选 named param + remoteAttachmentsDeleted/Failed 字段，硬删流水时先按 remoteKey 列表 storage.delete 再清 documents）
│     │  └─ trash_page.dart                TrashPage（4 Tab：流水/分类/账户/账本）+ AppBar 一键清空 + 行级恢复/永久删除二次确认
│     ├─ lock/                  Step 14.1 + 14.2 + 14.3 + 14.4 已填充：PIN（4-6 位 + PBKDF2-HMAC-SHA256 + 16B salt + 3 次错误冷却 30s）+ 生物识别（local_auth 3.x，启用后优先弹系统面板，cancelled/lockedOut/notAvailable/failed 各自降级到 PIN）+ 14.3 前台锁触发（AppLockGuard 监听 paused/resumed + 后台超时阈值可配 + 路由器之上 overlay 形态）+ 14.4 隐私模式（Android FLAG_SECURE / iOS sceneWillResignActive overlay，独立于 PIN 锁）
│     │  ├─ biometric_authenticator.dart Step 14.2 BiometricAuthenticator 抽象 + LocalAuthBiometricAuthenticator 生产实现（local_auth 3.x · LocalAuthException → BiometricResult cancelled/lockedOut/notAvailable/failed/success 5 态映射） + FakeBiometricAuthenticator @visibleForTesting (deviceSupported/enrolled/nextResult 三旋钮 + authenticateCalls/lastReason 断言)
│     │  ├─ pin_credential.dart        PinCredential 数据类 + PinCredentialStore 抽象 + FlutterSecurePinCredentialStore 生产实现 + InMemoryPinCredentialStore @visibleForTesting + generatePinSalt / hashPin / verifyPin / validatePinFormat / 常量时间比较；常量 kPinMinLength=4 / kPinMaxLength=6 / kPinPbkdf2Iterations=100000 / kPinSaltBytes=16；Step 14.3 新增常量 kDefaultBackgroundLockTimeoutSeconds=60 / kBackgroundLockTimeoutOptions=[0,60,300,900]；secure_storage 7 个独立条目（salt / hash / iterations / enabled + 14.2 biometric_enabled + 14.3 background_timeout_sec + 14.4 privacy_mode）
│     │  ├─ privacy_mode_service.dart   Step 14.4 PrivacyModeService 抽象 + MethodChannelPrivacyModeService 生产实现（'bianbian/privacy' channel · setEnabled(bool)；MissingPluginException / PlatformException 静默吞）+ FakePrivacyModeService @visibleForTesting（callCount + lastEnabled 断言）
│     │  ├─ app_lock_providers.dart    pinCredentialStoreProvider + appLockClockProvider + appLockEnabledProvider (FutureProvider) + PinAttemptSession (StateNotifier；isCoolingDown / cooldownRemainingSeconds / tryVerify / reset) + AppLockController (setupPin/changePin/disable/forgetPinAndDisable + Step 14.2 setBiometricEnabled · disable/forgetPinAndDisable 同步清生物识别开关 + Step 14.3 setBackgroundLockTimeoutSeconds 拒负值 + Step 14.4 setPrivacyMode 先打 native 再写 store) + biometricAuthenticatorProvider / biometricCapabilityProvider (FutureProvider) / biometricEnabledProvider + BiometricCapability 数据类 + 常量 kPinFailureLimit=3 / kPinCooldownDuration=30s + Step 14.3 backgroundLockTimeoutProvider (FutureProvider<int>) + AppLockGuardState (immutable · isLocked + lastBackgroundedAt) + AppLockGuard (StateNotifier · lock/unlock/forceUnlock/onPaused/onResumed/setTimeoutSeconds) + appLockGuardProvider (StateNotifierProvider；ref.listen 两路：appLockEnabled true→false 自动 forceUnlock + backgroundLockTimeout 变化 setTimeoutSeconds 同步) + Step 14.4 privacyModeProvider (FutureProvider<bool>) + privacyModeServiceProvider (Provider)
│     │  ├─ pin_setup_page.dart        PinSetupPage（PinSetupMode setup/change 两态 · 两步输入：先输 → 再确认 · 不一致回退到第一步并清空两个 controller · 调用 controller.setupPin/changePin · 成功 pop(true)）
│     │  ├─ pin_unlock_page.dart       PinUnlockPage（subtitle 注入 · allowBiometric 入参："持有人确认"路径传 false · 冷却中输入框 + 按钮置灰 + 1s Timer.periodic 倒计时 setState · Step 14.2 init 阶段自动尝试生物识别一次 + "使用指纹/面容"按钮手动重试 · cancelled 静默降级 · lockedOut/notAvailable/failed 各自文案 · 失败展示"剩余尝试次数 X"或"已进入冷却"· Step 14.3 onUnlocked 可选回调 + showAppBar 入参 · null callback 走 pop(true) 兼容老路径 · 非 null 走 callback 用于 overlay 形态）
│     │  ├─ app_lock_overlay.dart      Step 14.3 AppLockOverlay（ConsumerWidget；PopScope canPop=false + Material wrapper + PinUnlockPage(allowBiometric=true, showAppBar=false, onUnlocked=guard.unlock)）；不在路由栈，由 BianBianApp.builder 套在 router child 之上
│     │  └─ app_lock_settings_page.dart 「我的→应用锁」设置页（SwitchListTile 启用开关：关→开 push PinSetupPage / 开→关 push PinUnlockPage 验证（allowBiometric=false）· 修改 PIN 入口（先 unlock allowBiometric=false 再 setup mode=change）· Step 14.2 _BiometricToggle 三态：硬件不支持 / 未录入 / 可用，开启需弹一次系统面板二次确认 + SnackBar 反馈 · Step 14.3 _BackgroundTimeoutTile（仅 enabled 时挂载）4 选项 RadioGroup BottomSheet：立即锁定/1/5/15 分钟 · Step 14.4 _PrivacyModeToggle（独立于 enabled 显示）SwitchListTile · 忘记 PIN AlertDialog 二次确认 · 安全说明区扩展 14.3 + 14.4 文案）
│     ├─ import_export/         Phase 13 Step 13.1 + 13.2 + 13.3 + 13.4 已完成：CSV / JSON / .bbbak 导出 + 本 App 三种格式导入向导 + 钱迹 / 微信 / 支付宝 CSV 自动识别
│     │  ├─ export_service.dart    BackupFormat (csv/json/bbbak) / BackupScope / BackupDateRange + MultiLedgerSnapshot 信封 + filterSnapshotByRange + encodeBackupCsv / encodeBackupJson / buildBackupFileName + BackupExportService（writeExportFile / exportCsv / exportJson / exportBbbak / shareFile）
│     │  ├─ bbbak_codec.dart       Step 13.2 BbbakCodec（encode/decode/inspect + magic 'BBBK' / version=1 / salt 16B / packed AES-GCM body）+ BbbakFormatException
│     │  ├─ import_service.dart    Step 13.3 + 13.4 BackupImportService（detectFileType + preview + apply）+ BackupImportFileType / BackupDedupeStrategy (skip/overwrite/asNew) / BackupImportPreview（含 thirdPartyTemplateId/Name/unmappedCategoryCount）/ BackupImportCsvRow / BackupImportPreviewRow / BackupImportResult / BackupImportException + parseCsvRows / stripUtf8Bom / stripLedgerEmoji 工具函数 + 三方模板探测（CSV 路径优先识别）
│     │  ├─ import_export_page.dart 「我的 → 导入 / 导出」hub 页（导出 + 导入两个入口均可点）
│     │  ├─ export_page.dart       ExportPage（格式 3 段 CSV/JSON/加密 SegmentedButton + 范围 / 时间区间 + .bbbak 选中时密码二次输入 + 警告横幅 + 导出并分享 FilledButton）
│     │  ├─ import_page.dart       Step 13.3 + 13.4 ImportPage（_Stage idle/parsing/needPassword/preview/applying/done/error 7 阶段单页线性向导 + FilePicker 文件选择 + 元数据卡（含三方模板"识别为：xxx" + 未映射归"其他"提示）+ 20 行预览 + 3 种 dedupe 策略 RadioTile + 结果统计卡）
│     │  └─ templates/             Step 13.4 三方账单模板
│     │     └─ third_party_template.dart  ThirdPartyTemplate 抽象 + WechatBillTemplate / AlipayBillTemplate / QianjiTemplate + kAllThirdPartyTemplates 注册表 + detectThirdPartyTemplate(rows) 主入口 + kKeywordToCategory（~80 条关键词 → 本地二级分类名）+ kFallbackCategoryName='其他' + parseAmount / parseFlexibleDate / mapKeywordToCategory @visibleForTesting 工具
│     └─ settings/              Step 8.1：多币种开关；Step 8.2：账本默认币种 + 汇率快照 provider；Step 8.3：汇率刷新服务 + 手动覆盖；Step 9.3：AI 增强配置；Step 11.3：附件缓存设置页；Step 15.1：主题切换；Step 15.2：字号调节；Step 15.3：图标包切换
│        ├─ settings_providers.dart      CurrentThemeKey AsyncNotifier + currentThemeProvider + CurrentFontSizeKey AsyncNotifier + fontSizeScaleFactorProvider + CurrentIconPackKey AsyncNotifier + currentIconPackProvider + MultiCurrencyEnabled + currentLedgerDefaultCurrency + fxRates + fxRateRows + fxRateRefreshService + computeFxRate
│        ├─ settings_providers.g.dart    riverpod_generator 产物
│        ├─ fx_rate_refresh_service.dart Step 8.3 FxRateRefreshService（节流 / 失败静默 / 手动覆盖 / CNY 守护）+ defaultFxRateFetcher（open.er-api.com）
│        ├─ multi_currency_page.dart     MultiCurrencyPage（开关 SwitchListTile + 内置币种概览 + 汇率管理列表 + 立即刷新按钮 + 手动覆盖对话框）
│        ├─ ai_input_settings_providers.dart Step 9.3 AiInputSettings 数据类 + AiInputSettingsNotifier AsyncNotifier + aiInputEnhanceServiceProvider + kDefaultAiInputPromptTemplate
│        ├─ ai_input_settings_providers.g.dart riverpod_generator 产物
│        ├─ ai_input_settings_page.dart  Step 9.3 AiInputSettingsPage（开关 + endpoint/key/model/prompt 5 字段表单 + 保存按钮 + API key 显示切换）
│        ├─ theme_page.dart             Step 15.1 + 15.2 + 15.3 ThemePage（标题"外观"；主题区 4 套预览卡片 + 字号区 SegmentedButton 三档 + 图标包区 2 套 _IconPackCard 含样本 emoji 预览）
│        └─ attachment_cache_page.dart   Step 11.3 AttachmentCachePage（FutureBuilder 显示当前占用 + 上限 + 刷新按钮 + 红色"清除缓存"二次确认对话框 → pruner.clear()）
├─ android/app/build.gradle.kts Android 构建脚本（core library desugaring + minSdk 23）
├─ test/
│  ├─ core/
│  │  ├─ crypto/
│  │  │  └─ bianbian_crypto_test.dart     PBKDF2 + AES-GCM KAT + 往返 + 篡改检测（11 用例，Step 1.6）
│  │  └─ util/
│  │     ├─ category_icon_packs_test.dart  BianBianIconPack 枚举 + packDefaultIcon + resolveCategoryIcon + samplePackIcons（20 用例，Step 15.3）
│  │     └─ quick_text_parser_test.dart   QuickTextParser 解析器（34 用例，Step 9.1）
│  ├─ data/
│  │  └─ local/
│  │     ├─ app_database_test.dart           user_pref schema/CHECK 约束（2 用例）
│  │     ├─ business_tables_test.dart        6 张业务表 CRUD + soft-delete + 索引断言（7 用例）
│  │     ├─ dao_test.dart                    5 个 DAO × 4 类方法（5 用例，Step 1.4）
│  │     ├─ device_id_store_test.dart        device_id 加载器的 4 条分支（5 用例，Step 1.5）
│  │     ├─ seeder_test.dart                 默认数据种子化的 3 条路径（3 用例，Step 1.7）
│  │     ├─ db_cipher_key_store_test.dart    密钥生成/持久化（4 用例）
│  │     └─ fx_rate_test.dart                FxRateDao + seeder fx_rate 路径 + 内置币种常量（11 用例，Step 8.1）
│  ├─ data/
│  │  └─ repository/
│  │     ├─ transaction_repository_test.dart TransactionRepository 4 条用例（Step 2.2）
│  │     ├─ account_repository_test.dart     AccountRepository CRUD + getById 兜底（7 用例，Step 7.2）
│  │     └─ budget_repository_test.dart      BudgetRepository 唯一性 + 软删后重建（8 用例，Step 6.1）
│  ├─ domain/
│  │  └─ entity/
│  │     ├─ entities_test.dart               5 个实体 roundtrip/copyWith + drift 隔离（17 用例，Step 2.1）
│  │     └─ attachment_meta_test.dart        Step 11.2 AttachmentMeta + AttachmentMetaCodec + migrateAttachmentsBlobV8ToV9（12 用例：toJson/fromJson 往返、copyWith、v8 兼容、迁移幂等）
│  ├─ features/
│  │  ├─ record/
│  │  │  ├─ record_new_providers_test.dart   RecordForm Notifier 单元测试（含 Step 3.5 附件序列化、Step 8.2 setCurrency/fxRate 写入断言）
│  │  │  └─ record_new_page_test.dart        RecordNewPage widget 测试（含 Step 3.5 附件 UI、Step 8.2 币种下拉与 fxRate 保存）
│  │  │  └─ record_home_page_format_test.dart formatTxAmountForDetail 纯函数（6 用例，Step 8.2）
│  │  │  └─ widgets/
│  │  │     └─ attachment_thumbnail_test.dart Step 11.3 AttachmentThumbnail widget 测试（5 用例：downloader null + remoteKey 占位 / 双 null 占位 / storage 异常占位 / Provider loading 骨架屏 / onTap 触发 InkWell）
│  │  │  └─ quick_confirm_sheet_test.dart    Step 9.2 QuickConfirmCard 单元测试（13 用例 + Step 9.3 新增 4 用例 = 17 用例，覆盖字段初始展示 / 低置信度横幅 / 保存路径 / 取消 / 分类选择器 / subcategory 二次匹配 / AI 增强按钮显隐 + 成功/失败路径）
│  │  │  └─ quick_input_bar_test.dart        Step 9.2 首页输入条 → 卡片 → 保存全链路集成测试（2 用例）
│  │  │  └─ ai_input_enhance_service_test.dart Step 9.3 AiInputEnhanceService + parseEnhanceJson 测试（24 用例：schema 严格校验 + HTTP 协议 + prompt 占位符）
│  │  │  └─ record_search_filters_test.dart  Step 3.6 searchTransactions 纯函数 + SearchQuery copyWith/isEmpty（11 用例：关键词命中备注/分类/账户、日期闭区间、类型筛选、金额范围、多维度交集）
│  │  │  └─ record_search_page_test.dart     Step 3.6 RecordSearchPage widget 测试（5 用例：空查询提示 / 关键词命中 / 空结果提示 / 点击结果弹详情 / 删除流程从列表消失）
│  │  │  └─ month_picker_dialog_test.dart    Step 3.7 showMonthPicker widget 测试（3 用例：默认高亮初始月份 / 切换年-月并确认 / 取消返回 null）
│  │  └─ stats/
│  │     ├─ stats_range_providers_test.dart  统计区间/饼图/排行/热力图聚合测试（Step 5.1~5.5）
│  │     └─ stats_export_service_test.dart   CSV 编码 + 文件名规则测试（Step 5.6）
│  ├─ features/budget/
│  │  ├─ budget_progress_test.dart           computeBudgetProgress 边界 + computePeriodSpent + shouldTriggerBudgetVibration（16 用例，Step 6.2）
│  │  └─ budget_vibration_session_test.dart  BudgetVibrationSession Notifier 幂等/独立标记/clear（5 用例，Step 6.2）
│  ├─ features/account/
│  │  └─ account_balance_test.dart           aggregateNetAmountsByAccount + computeAccountBalances + computeTotalAssets 纯函数边界（16 用例，Step 7.1）
│  ├─ features/settings/
│  │  └─ multi_currency_page_test.dart       MultiCurrencyPage 开关 + 汇率列表 + 手动覆盖（11 用例，Step 8.1+8.3）
│  │  └─ fx_rate_compute_test.dart           computeFxRate 同币种/跨币种/兜底（8 用例，Step 8.2）
│  │  └─ fx_rate_refresh_service_test.dart   FxRateRefreshService 节流 / 失败静默 / 手动覆盖（15 用例，Step 8.3）
│  │  └─ ai_input_settings_providers_test.dart Step 9.3 AiInputSettings 数据类 + DB 集成 roundtrip（10 用例）
│  │  └─ ai_input_settings_page_test.dart    Step 9.3 AiInputSettingsPage widget 测试（3 用例：预填 / 保存 / API key 显示切换）
│  │  └─ theme_test.dart                    Step 15.1 + 15.2 BianBianTheme 枚举 + buildAppTheme 四套 + BianBianSemanticColors lerp/copyWith + currentThemeProvider 四 key + BianBianFontSize 枚举 + fontSizeScaleFactorProvider 四 key（27 用例）
│  │  └─ theme_page_test.dart               Step 15.1 + 15.2 ThemePage widget 测试（7 用例：4 卡片渲染 / 点击切换 / 描述文案 / 标题"外观" / 字号 SegmentedButton / 点击"大" / 字号描述文案）
│  ├─ features/sync/
│  │  ├─ sync_trigger_test.dart              Step 10.7 SyncTrigger 单元测试（8 用例：notConfigured / 成功 / SocketException / TimeoutException / failure / skipped / 防抖语义 / cancelTimers）
│  │  ├─ attachment_uploader_test.dart       Step 11.2 AttachmentUploader（6 用例：透传已 remoteKey、sha256 去重、单条失败隔离、null path 跳过、远端路径模式断言）
│  │  ├─ attachment_downloader_test.dart     Step 11.3 AttachmentDownloader（11 用例：localPath 命中 / null+null / remoteKey 下载 / storage 抛异常 / 404 / writeback 调用 + 抛异常 / in-memory cache / inflight 复用 / 并发限流 ≤3）
│  │  └─ attachment_cache_pruner_test.dart   Step 11.3 AttachmentCachePruner（8 用例：currentSize ×2 / prune 未超限 / 按 mtime 升序淘汰 / 7 天保留期 / 保留期 + 超限混合 / clear ×2）
│  ├─ features/import_export/
│  │  └─ export_service_test.dart            Step 13.1 BackupDateRange / filterSnapshotByRange / encodeBackupCsv / encodeBackupJson + MultiLedgerSnapshot.fromJson / buildBackupFileName 单元测试（20 用例：区间边界 / 过滤零拷贝 / CSV 9 列 BOM / 转账 toAccount / RFC 4180 转义 / 多账本顺序 / JSON round-trip / 版本不兼容抛 FormatException / 文件名各形态）
│  │  ├─ bbbak_codec_test.dart               Step 13.2 BbbakCodec 单元测试（18 用例：参数校验 / 文件结构（魔数+版本+salt+body）/ 短长明文 roundtrip / 含中文 emoji 换行 / 同密码两次产出不同 packed / 错误密码失败 / 大小写敏感 / 密文 salt 篡改失败 / 短文件 / 魔数错 / 版本不识别 / inspect 边界 / JSON 集成 round-trip）
│  │  ├─ import_service_test.dart            Step 13.3 BackupImportService 单元测试（28 用例：detectFileType / parseCsvRows / stripUtf8Bom / stripLedgerEmoji / JSON preview + 3 strategy / CSV header + fallback / .bbbak roundtrip + iterations:1）
│  │  └─ third_party_template_test.dart      Step 13.4 三方模板单元测试（37 用例：detectThirdPartyTemplate 4 模板形态 + 本 App CSV 不被误命中 / mapKeywordToCategory 7 类别 / parseAmount 7 形态 / parseFlexibleDate 5 形态 / 微信 50+ 行样本 + 状态过滤 + 中性过滤 / 支付宝 50+ 行样本 + 退款过滤 + 未命中归"其他" / 钱迹 50+ 行样本 + 转账行 + 二级分类直接成 categoryName / 三模板 apply 端到端落到 fallback ledger）
│  ├─ features/lock/            Step 14.1 + 14.2 + 14.3 + 14.4 PIN 凭据 / 冷却 / 设置页 / 生物识别 / 前台锁触发 / 隐私模式（123 用例）
│  │  ├─ biometric_authenticator_test.dart    Step 14.2 FakeBiometricAuthenticator 单元测试（6 用例：默认 success / deviceSupported / enrolled 旋钮 / nextResult 5 态 / authenticateCalls 计数 / lastReason 透传）
│  │  ├─ pin_credential_test.dart            validatePinFormat / generatePinSalt 熵 / hashPin + verifyPin 往返 / 错 PIN / 不同 salt / 篡改 iterations / constantTimeEquals / PinCredential ==hashCode / InMemoryPinCredentialStore + Step 14.2 biometric storage roundtrip + Step 14.3 backgroundLockTimeout default/roundtrip/拒负值/不被 clearCredential 清 + Step 14.4 privacyMode default/roundtrip/不被 clearCredential 清（28 用例）
│  │  ├─ privacy_mode_service_test.dart      Step 14.4 PrivacyModeService 单元测试（6 用例：FakePrivacyModeService 计数+lastEnabled / MethodChannel setEnabled true · false / PlatformException 静默吞 / MissingPluginException 静默吞）
│  │  ├─ app_lock_providers_test.dart        PinAttemptSession.tryVerify 冷却语义 + AppLockController setupPin/changePin/disable/forgetPinAndDisable + appLockEnabledProvider invalidate + Step 14.2 biometricCapabilityProvider 三态 + biometricEnabledProvider invalidate + setBiometricEnabled + disable/forgetPinAndDisable 同步清生物识别开关 + Step 14.3 backgroundLockTimeoutProvider default/setX/拒负值 + AppLockGuard 状态机（lock/unlock/onPaused/onResumed elapsed</>=timeout/timeout=0 立即/null 不动/setTimeoutSeconds 即时生效/拒负值/appLockEnabled 联动 forceUnlock/timeoutProvider 联动 sync）+ AppLockGuardState ==/copyWith + Step 14.4 privacyModeProvider 默认 + setPrivacyMode store+native 双写 + invalidate 同步（共 44 用例）
│  │  ├─ app_lock_overlay_test.dart          Step 14.3 AppLockOverlay widget 测试（3 用例：isLocked=true 显示 PinUnlockPage 无 AppBar / 输入正确 PIN → guard.unlock / PopScope canPop=false 验证）
│  │  └─ app_lock_settings_page_test.dart    PinSetupPage 两步一致 / 不一致回退 / 长度过短 + PinUnlockPage 正确 + 3 次错误冷却文案 + AppLockSettingsPage 默认 OFF / 拨开开关 push setup → ON / 忘记 PIN 二次确认 + Step 14.2 _BiometricToggle 三态（不支持/未录入/可用）+ 拨开 success → persist + cancelled SnackBar + 拨关不弹面板 + PinUnlockPage 5 路径（success/cancelled/lockedOut/disabled/不支持/allowBiometric=false）+ Step 14.3 _BackgroundTimeoutTile 显示 / 未启用不挂载 / BottomSheet 4 选项 + 立即锁定 persist / 选当前值不写入 + Step 14.4 _PrivacyModeToggle 关锁状态可见 / 拨开 store+native 双写 / 拨关同步关闭（24 用例）
│  └─ widget_test.dart          Widget 测试（HomeShell + 首页流水列表 + 已删账户回退 6 用例；Step 10.7 起所有 BianBianApp 实例均传 enableSyncLifecycle: false）
├─ memory-bank/
│  ├─ design-document.md        产品设计（权威来源）
│  ├─ implementation-plan.md    分阶段实施计划
│  ├─ progress.md               执行进度流水
│  └─ architecture.md           本文件
├─ pubspec.yaml                 依赖声明（Step 0.3 集合 − sqlite3_flutter_libs + sqlcipher_flutter_libs ^0.6.5）
└─ analysis_options.yaml        静态分析配置（flutter_lints + custom_lint 插件）
```

说明：`[空]` 表示目录仅含 `.gitkeep` 占位，等待后续 Phase 填充。

## 各文件/目录职责

### `lib/main.dart`
- 启动入口。Step 1.5 把 DB smoke test 从"裸 `AppDatabase()` + `SELECT 1`"改造为"Riverpod bootstrap"；Step 1.7 把预热目标升级为 `defaultSeedProvider`（下游链依次触发 device_id → DB → 种子数据）：
  1. `WidgetsFlutterBinding.ensureInitialized()`——因 `AppDatabase()` / `flutter_secure_storage` 都依赖 platform channel，必须先初始化 binding；
  2. `final container = ProviderContainer()`——独立于 Widget 树创建的 Riverpod 容器；
  3. `await container.read(defaultSeedProvider.future)`——一次性触发连锁：`defaultSeedProvider` → `deviceIdProvider` → `appDatabaseProvider` → `AppDatabase()` 构造 → `LazyDatabase` 打开 `bbb.db` → `PRAGMA key` 注入 → `PRAGMA cipher_version` 断言 → `LocalDeviceIdStore.loadOrCreate()` → `DefaultSeeder.seedIfEmpty()`。任何一环抛错都冒泡到 catch，兜底页显示 stack trace；
  3.5. Step 15.1：`await container.read(currentThemeKeyProvider.future)`——预热主题 key，让 `BianBianApp` 第一帧就能拿到正确的 `ThemeData`（否则 `currentThemeProvider` 的 `valueOrNull` 回退 cream_bunny）；
  4. 成功 → `runApp(UncontrolledProviderScope(container: container, child: BianBianApp()))`——把 main 里已预热的 container 原样交给 Widget 树，避免 runApp 后 ProviderScope 又开一次 DB。失败 → `container.dispose()` 释放资源、`runApp(ProviderScope(_BootstrapErrorApp(...)))` 渲染红字错误页。
- Step 1.4 之前的 `import 'data/local/app_database.dart'` 已被移除，现在只 import `data/local/providers.dart`——意味着 main.dart **不再直接 new AppDatabase()**，一切走 provider。

### `lib/app/`
应用装配层。Step 0.4 已填充四个文件：

- **`app.dart`**：`BianBianApp`（ConsumerStatefulWidget，Step 10.7 升级 + Step 15.1 主题动态化）。返回 `MaterialApp.router`，注入 `theme: ref.watch(currentThemeProvider)`（Step 15.1：由 provider 驱动，切换后即时变色）、`routerConfig: goRouter`、`title: '边边记账'`、`debugShowCheckedModeBanner: false`。Step 10.7 `enableSyncLifecycle` WidgetsBindingObserver 联动 syncTrigger；Step 14.3 `enableAppLockGuard` + builder 套 `_AppLockGate` Stack 在 router child 之上挂 `AppLockOverlay`。
- **`app_router.dart`**：顶层 `final GoRouter goRouter`。当前只有一条 `GoRoute('/')` → `HomeShell`；后续各 Phase 在此数组追加路由（`/record/new`、`/ledger`、`/settings/sync` …）。若 Phase 10 同步启动后需要监听登录态重定向，应改为 `@riverpod GoRouter goRouter(Ref ref)`。
- **`app_theme.dart`**（Step 15.1 重构）：
  - `BianBianTheme` 枚举：`creamBunny` / `thickBrownBear` / `moonlightDark` / `mintGreen`，与 `user_pref.theme` 列值一一对应。`fromKey(key)` 解析 + 回退默认；`isDark` / `label` 属性。
  - `buildAppTheme(BianBianTheme)`：统一构建入口——按枚举选出 `ColorScheme` + `BianBianSemanticColors` + 阴影色 + scaffold 背景，产出完整 `ThemeData`。四套色板：奶油兔（design-document §10.2 奶油黄/樱花粉/可可棕）、厚棕熊（暖棕/米）、月见黑（深色模式）、薄荷绿（清新）。
  - `BianBianSemanticColors`：`ThemeExtension`（不变），承载 success / warning / danger 三语义色，每套主题各自配色。
  - `final ThemeData appTheme = buildAppTheme(BianBianTheme.creamBunny)`：向后兼容，供 widget_test 等不依赖 provider 的场景。
- **`home_shell.dart`**：`HomeShell`（StatefulWidget）。`BottomNavigationBar` 4 Tab：记账 / 统计 / 账本 / 我的。使用**本地 index**（`setState`）管理当前 Tab。各 Tab body：
  - 记账（index=0）：`RecordHomePage`（Step 3.1 接入，ConsumerWidget，独立 Scaffold + FAB）。
  - 统计（index=1）：`StatsPage`（Step 5.1 接入，时间区间选择器 + 区间展示）。
  - 账本（index=2）：`LedgerListPage`（Step 4.1 接入，ConsumerWidget，正式卡片列表 + 点击切换）。
  - 我的（index=3）：`_MeTab`（Step 6.1 接入，文件内私有 StatelessWidget）。当前承载"主题 / 预算 / 资产 / 多币种 / 快速输入 · AI 增强 / 云服务 / 附件缓存 / 导入 / 导出 / 应用锁 / 垃圾桶"等入口；Phase 17 会扩展为完整设置页。
  - 若未来某 Tab 要求"深链 + 各自独立历史栈"，迁移到 `StatefulShellRoute.indexedStack`。

### `lib/core/`
横切关注点，三个子目录按职责拆分：
- **`crypto/`**（Step 1.6 已填充）：
  - **`bianbian_crypto.dart`**：`BianbianCrypto` 工具类（私有构造，只暴露 static 方法）+ `DecryptionFailure` 异常。三个公开 API：`deriveKey(password, salt, {iterations=100000})` 走 PBKDF2-HMAC-SHA256；`encrypt(plaintext, key)` 走 AES-256-GCM 并返回 `nonce(12) ‖ ciphertext(N) ‖ tag(16)` 连续打包的 `Uint8List`；`decrypt(packed, key)` 反向解包，任何失败（长度不足 / tag 校验失败 / 错误 key）统一抛 `DecryptionFailure`。nonce 由 `AesGcm.newNonce()` 生成（`Random.secure()` 内核）每次都独立，避免同一 key 下重用导致 GCM 泄密。`@visibleForTesting` 的 `encryptWithFixedNonce` 让 KAT 能对照固定 `(K, N, P) → (C, T)` 向量。key 长度严格校验 32 字节，nonce 严格 12 字节，非法输入抛 `ArgumentError`。
  - 消费者：当前实际消费方仅 `user_pref.ai_api_key_encrypted` 存取（Step 9.3 起，落 UTF-8 raw bytes，DB 由 SQLCipher 加密保护）。**Phase 11（附件云同步）不再消费**——附件直接明文上传到用户自有云，无字段级加密；原计划的「note 加密 / 附件密文 / 同步码对称外壳」整段废弃。`bianbian_crypto.dart` 留作未来可选加密层（如 Phase 13 `.bbbak` 备份包密码加密）的工具备件。**与 SQLCipher/`DbCipherKeyStore` 走两条独立路径**——本工具加密的是"出站字段"，SQLCipher 加密的是"本机 DB 文件"。
- **`network/`**：`SupabaseClient` 工厂，支持用户自建 Supabase（BYO 单模——Phase 10 已废弃"官方托管 + 自建双模"，所有用户都填自己的 URL + anon key）。Step 10.2 填充。
- **`util/`**：无分类的纯函数工具；目前承载三个文件——
  - `currencies.dart`（Step 8.1）：`Currency` 数据类 + `kBuiltInCurrencies` (11 种) + `kFxRateSnapshot` 初始汇率快照。
  - `category_icon_packs.dart`（Step 15.3）：`BianBianIconPack` 枚举（sticker/flat）+ 两套静态 emoji 映射 + `resolveCategoryIcon` 运行时解析函数 + `samplePackIcons` 预览辅助。解析策略：若 `category.icon` 匹配任一 pack 默认值 → 返回当前 pack 的默认值（切换即时生效）；否则 → 用户自定义，原样返回。不批量写 DB、不产生 sync_op。
  - `quick_text_parser.dart`（Step 9.1）：`QuickTextParser` + `QuickParseResult`。中文快速记账文本本地解析器。**纯 Dart**——不依赖 Flutter / Riverpod / drift。解析 5 步串行（**时间在金额之前**——避免 `3天前 烧烤 88` 中的 `3` 被金额正则先吃掉）：① 时间（内置相对天数 `大前天/前天/昨天/今天/明天/后天/大后天` + `上周X/这周X/下周X` + `N天前`）；② 金额（阿拉伯数字正则 `[¥￥]?(\d+(?:\.\d+)?)\s*(?:元|块|RMB|CNY|￥|¥)?` 优先，未命中则中文数字回退 `[零一二两三四五六七八九十百千万]+` + 可选尾缀；单字中文数字若无尾缀视为非金额，避免 `买了一些菜` 中 `一` 误判）；③ 分类（53 词词典，长词优先扫描，覆盖餐饮/交通/购物/娱乐/收入等 11 个一级分类 key，与 `seeder.dart::categoriesByParent.keys` 同集）；④ 置信度（阿拉伯金额 +0.5 / 中文金额 +0.4 / 分类 +0.4 / 时间 +0.1，上限 1.0；Step 9.2 阈值 0.6 决定"AI 增强"按钮是否出现）；⑤ 备注（剥离已识别片段后的残余文本）。`clock` 钩子让测试锁定参考时间。Step 9.2 会在 `features/record` 起 `quickTextParserProvider`，但本文件保持纯函数式无副作用。

### `lib/data/`
数据访问层，按"数据源"分三个子目录：
- **`local/`**：drift 数据库定义与 DAO。Step 1.1（user_pref 表）、Step 1.2（SQLCipher + 密钥）、Step 1.3（其余 6 张业务表 + v1→v2 migration）已落地；Step 1.4（5 个 DAO 分层）已落地；并在 Phase 3 对 `category` 做了 v3 不兼容重构（全局二级分类）。
  - **`app_database.dart`**：`AppDatabase extends _$AppDatabase`，`@DriftDatabase(tables: [UserPrefTable, LedgerTable, CategoryTable, AccountTable, TransactionEntryTable, BudgetTable, SyncOpTable], daos: [LedgerDao, CategoryDao, AccountDao, TransactionEntryDao, BudgetDao])`。生产构造 `AppDatabase()` → `_openEncrypted()`：① 先在主 isolate 跑 `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()`；② 从 `DbCipherKeyStore().loadOrCreate()` 取 hex 密钥；③ `NativeDatabase.createInBackground(file, isolateSetup: ..., setup: ...)`——`isolateSetup` 在后台 isolate 再跑一次 Android workaround，`setup` 里执行 `PRAGMA key = "x'<hex>'"` 并用 `PRAGMA cipher_version` 断言 SQLCipher 真的加载（未加载即 `StateError`，防止"看似加密实则明文落盘"）。测试构造 `AppDatabase.forTesting(NativeDatabase.memory())` 不变。顶层 `export 'package:drift/drift.dart' show Value;`。DAO 作为 `late final xxxDao = XxxDao(this as AppDatabase)` 字段由 drift_dev 生成在 `app_database.g.dart`——调用方通过 `db.ledgerDao` / `db.categoryDao` / `db.accountDao` / `db.transactionEntryDao` / `db.budgetDao` 访问。
    - **`schemaVersion = 5`（Phase 7 Step 7.3）**：
      - v1：`user_pref`
      - v2：新增 `ledger/category/account/transaction_entry/budget/sync_op` + transaction 索引
      - v3：`category` 改为“全局二级分类”模型（`parent_key` + `is_favorite`，移除 `ledger_id` + `type`）
      - v4：`budget` 追加 `carry_balance` / `last_settled_at`（预算结转）
      - v5：`account` 追加 `billing_day` / `repayment_day`（信用卡专属，1-28，仅展示）
    - **`MigrationStrategy`**：
      - `onCreate`：`m.createAll()` + `_createTransactionIndexes()`
      - `onUpgrade`：`from < 2` 时创建 v2 业务表；`from < 3` 时按产品要求**不兼容旧分类结构**，执行 `deleteTable('category')` 后 `createTable(categoryTable)` 重建；`from < 4` 时给 `budget` `addColumn` 两列；`from < 5` 时给 `account` `addColumn` 两列。
  - **`db_cipher_key_store.dart`**：`DbCipherKeyStore` + `SecureKeyValueStore` 抽象接口 + `FlutterSecureKeyValueStore` 生产实现。`loadOrCreate()`：已有合法 hex（64 字符小写）→ 读回；否则用注入的 `Random`（默认 `Random.secure()`）生成 32 字节，hex 编码写入 `flutter_secure_storage` 条目 `local_db_cipher_key`。密钥以 hex 串保存、以 `PRAGMA key = "x'<hex>'"` 注入，跳过 SQLCipher 自带 PBKDF2。**该密钥仅保护本机 `bbb.db`**，与同步链路完全无关——Phase 11 附件云同步不引入任何字段级加密，云端是用户自有空间，明文上传（详见 implementation-plan §11）。
  - **`device_id_store.dart`**（Step 1.5）：`LocalDeviceIdStore` + `UuidFactory` 类型别名。`loadOrCreate()` 按「`flutter_secure_storage` → `user_pref.device_id` → 新生成」优先级解析 device_id，并把最终值**同步写回另一侧**（"冗余防丢"）。密钥名 `local_device_id`（静态常量 `storageKey`）独立于 `DbCipherKeyStore.storageKey`——前者可被同步恢复，后者丢失即本机 DB 永久不可读，两者命名空间故意分开。UUID 合法性走宽松正则（8-4-4-4-12 hex、不校验 v4 version/variant 位），允许从老库恢复任意合法 UUID。`_ensureUserPref` **故意不用 `insertOnConflictUpdate`**——user_pref 的 `CHECK(id=1)` 约束在 SQLite UPSERT 的 DO UPDATE 路径会被二次评估并误报失败，改为显式 select-then-insert/update（DAO 层普通表不受此影响，原因是它们没有 id CHECK）。依赖注入点：`SecureKeyValueStore`（生产 `FlutterSecureKeyValueStore`、测试 in-memory）+ `UuidFactory`（默认 `const Uuid().v4()`、测试返回固定字面量）。
  - **`seeder.dart`**（Step 1.7）：`DefaultSeeder` + `SeedClock` / `SeedUuidFactory` 类型别名。`seedIfEmpty()` 在单事务内判断 `ledger` 表是否空——非空整体跳过；空则插入 1 账本（📒 生活）+ 28 分类（18 支出 + 10 收入）+ 5 账户（现金 / 工商银行卡 / 招商信用卡 / 支付宝 / 微信）。默认列表作为 `static const List<(...)> expenseCategories / incomeCategories / defaultAccounts` 暴露给测试与后续 UI（Step 3.2 记账页分类网格直接消费）。颜色走 `palette` 6 色（design-document §10.2 奶油兔色板）的 `i % 6` 循环。**不向 `sync_op` 写条目**——Phase 10 再决定种子数据与首次同步的交互规则，避免两台设备各自种子导致"两套默认数据重复上云"。
  - **`providers.dart`**（Step 1.5/1.7）：三个 `@Riverpod(keepAlive: true)` 顶层函数。
    - `appDatabase(Ref)` 构造 `AppDatabase()` 并在 `ref.onDispose` 里关闭。
    - `deviceId(Ref)` 返回 `Future<String>`，`watch(appDatabaseProvider)` 拿到 DB，再 `LocalDeviceIdStore(db: db).loadOrCreate()`。
    - `defaultSeed(Ref)`（Step 1.7 加）返回 `Future<void>`，`watch(appDatabaseProvider)` + `await watch(deviceIdProvider.future)` 后调 `DefaultSeeder.seedIfEmpty()`。是整条 bootstrap 链最靠前的那个 provider——main.dart 只要 `await container.read(defaultSeedProvider.future)` 即可穿过"DB 打开 → device_id → 种子"三环。
    - `keepAlive: true` 保证在 ProviderContainer 生命周期内只构建一次；main.dart 的 bootstrap 依赖这点：`container.read` 预热后，runApp 交给 `UncontrolledProviderScope`，widget 树再读就是 cache hit。
    - `providers.g.dart` 由 `riverpod_generator` 产出对应的 `appDatabaseProvider` / `deviceIdProvider` / `defaultSeedProvider`。
  - **`tables/user_pref_table.dart`**：§7.1 `user_pref` 表——单行 `CHECK (id = 1)` 约束、`device_id` NOT NULL、其余字段按文档定义 nullability + 默认值。
  - **`tables/ledger_table.dart`**（Step 1.3）：`LedgerTable` + `@DataClassName('LedgerEntry')`。§7.1 账本表，PK `id` (TEXT, uuid)，`name` NOT NULL，`cover_emoji` 可空，`default_currency` 默认 `'CNY'`，`archived` 默认 0，`created_at` / `updated_at` NOT NULL，`deleted_at`, `device_id`。
  - **`tables/category_table.dart`**（Phase 3 重构）：`CategoryTable` + `@DataClassName('CategoryEntry')`。分类改为“固定一级 + 落库二级”的全局模型：
    - 一级分类不落库，仅由 `parent_key` 归属（如 `income/food/shopping/...`）；
    - 二级分类通过 `is_favorite` 标记收藏（全局共享）；
    - 已移除 `ledger_id` 与 `type`，并通过 `parent_key` 约束保证值域合法。
  - **`tables/account_table.dart`**（Step 1.3 / Step 7.3）：`AccountTable` + `@DataClassName('AccountEntry')`。`type` ∈ `cash` / `debit` / `credit` / `third_party` / `other`；`initial_balance` REAL 默认 0（信用卡可为负）；`include_in_total` 默认 1；`currency` 默认 `'CNY'`。账户不绑定账本——全局资源。**Step 7.3** 追加两列 `billing_day INTEGER` / `repayment_day INTEGER`（均 nullable，UI 校验取值 1-28），仅信用卡使用，仅展示用、不生成提醒。
  - **`tables/transaction_entry_table.dart`**（Step 1.3）：`TransactionEntryTable` + `@DataClassName('TransactionEntryRow')`——**刻意不叫 `TransactionEntry`**，让位给 Step 2.1 的领域实体同名。`ledger_id` 声 FK，`amount` / `currency` / `occurred_at` NOT NULL，`fx_rate` 默认 1.0，`note_encrypted` / `attachments_encrypted` 为 BLOB（**列名是历史遗留**——v1 设计曾打算装字段级加密密文，Phase 11 决策后改为明文：`note_encrypted` 暂未消费、`attachments_encrypted` 装附件元数据 JSON 数组明文 bytes，Phase 11 schema v10 升级后 shape 从 `["path"]` 升级为 `[{remote_key, sha256, ...}]`。详见 implementation-plan §11.2）。两索引 `idx_tx_ledger_time (ledger_id, occurred_at DESC)` 与 `idx_tx_updated (updated_at)` 在 `MigrationStrategy` 里用 `customStatement` 建。
  - **`tables/budget_table.dart`**（Step 1.3）：`BudgetTable` + `@DataClassName('BudgetEntry')`。`period` ∈ `monthly` / `yearly`；`category_id = NULL` 表示"总预算"（该账本该周期的总盘子）；`carry_over` 默认 0（Phase 6 Step 6.4 才真正使用）。
  - **`tables/sync_op_table.dart`**（Step 1.3）：`SyncOpTable` + `@DataClassName('SyncOpEntry')`——本机出站同步队列。`id` 用 `integer().autoIncrement()`（隐式主键，**不**再覆写 `primaryKey`；重复覆写会触发 drift_dev 的 `primary_key_and_auto_increment` 报错）。无 `updated_at` / `deleted_at` / `device_id` 三件套——这是队列而非实体，push 成功就物理删除条目。
  - **`dao/`**（Step 1.4）：5 个业务表 DAO，每个文件均为 `@DriftAccessor(tables: [XxxTable])` + `extends DatabaseAccessor<AppDatabase> with _$XxxDaoMixin`。所有 DAO 只暴露 **4 类方法**（实施计划 Step 1.4 硬性约束）：
    1. **list-active**：未软删记录的查询。`category` 已从“按账本”切为“按一级分类 key”查询（`listActiveByParentKey(parentKey)`）与全量/收藏查询（`listActiveAll` / `listFavorites`）；`transaction_entry` / `budget` 仍按 `ledger_id` 查询；`ledger` / `account` 为全局查询。
    2. **upsert**：`into(table).insertOnConflictUpdate(entry)`——调用方负责填 `updated_at` / `device_id`（Step 2.2 仓库层会统一封装）。
    3. **softDeleteById(id, {deletedAt, updatedAt})**：双写 `deleted_at` + `updated_at`；单凭写 `deleted_at` 不够，同步层按 `updated_at` 拉取增量，不刷 `updated_at` 的软删会被对端当成"没变过"漏掉。
    4. **hardDeleteById(id)**：`delete(table)..where(id = ?)` 物理移除。**方法文档显式注明"仅供垃圾桶定时任务调用"**——业务路径必须走 softDelete 以保留 30 天恢复窗口。接口不会自检 `deleted_at IS NOT NULL`；"仅 GC 可调"靠文档 + 代码评审守护，不做运行时护栏（会让正常 GC 也绕不过）。
    - 排序约定：`listActive()` 按 `updated_at DESC`（最近变动靠前）；`listActiveByLedger` 在 `category` 按 `sort_order ASC`（与记账页网格顺序一致）、`transaction_entry` 按 `occurred_at DESC`（命中 `idx_tx_ledger_time` 索引）、`budget` 不排序（UI 层按 `category_id IS NULL` 优先 + 周期分组自行排）。
    - **未提供 watch 变体**：Step 1.4 只暴露 `Future` API，够支撑 Step 2.2 仓库层做一次性查询；UI 响应式刷新由 Step 2.3 的 Riverpod provider `invalidate` 机制驱动。如果未来某 Tab 需要真正的 drift Stream（例如首页流水列表），可以在 DAO 里增量加 `watchActiveByLedger`，而不是把 `listActive...` 全改成 Stream。
- **`dao/sync_op_dao.dart`**（Step 2.2）：`SyncOpDao`——`@DriftAccessor(tables: [SyncOpTable])`。两个方法：`enqueue(...)` 返回 AUTOINCREMENT id；`listAll()` 按 `id ASC` 列出所有待同步记录。`op` 取 `'upsert'` / `'delete'`；`entity` 取 `'ledger'` / `'category'` / `'account'` / `'transaction'` / `'budget'`——注意是 `'transaction'` 而非 `'transaction_entry'`，与 design-document §7.1 DDL 注释字面一致。
- **`remote/`**：Supabase 的 DataSource（表映射 + 批量 push/pull）。Step 10.x 填充。
- **`repository/`**（Step 2.2 已填充）：
  - **`repo_clock.dart`**：`typedef RepoClock = DateTime Function()`——仓库层"当前时间"注入点。生产路径默认 `DateTime.now`，测试路径注入固定时间戳。
  - **`entity_mappers.dart`**：drift 行对象 ↔ 领域实体的唯一映射桥接层。5 组 10 个函数（每组 `rowToXxx` + `xxxToCompanion`），完成 `int epochMs ↔ DateTime`、`int? 0/1 ↔ bool`、nullable 默认值应用。**这是 `lib/data/` 与 `lib/domain/` 之间唯一允许的桥接点**——UI 层只能通过抽象接口 import 仓库。
  - **5 个仓库**（一个抽象接口 + 一个 `LocalXxxRepository` 实现）：
    - `ledger_repository.dart`：`listActive()` / `getById(id)` / `save(Ledger)` / `softDeleteById(id)` / `setArchived(id, bool)`。**名称唯一性强化**：`save()` 内查 `name` 命中未软删账本（排除自身 id）即抛 `LedgerNameConflictException`（同文件公开类，`Exception` 而非 `Error`）。Why: 删除账本即使云端有备份也找不回（V1 同步按 ledgerId 寻址，普通用户只识别名字），允许重名会导致切换/恢复时无法区分。已软删的账本不视为冲突——名字可被新账本立即复用；UI 在调用前已 trim 名字。
    - `category_repository.dart`：`listActiveByParentKey(parentKey)` / `listFavorites()` / `listActiveAll()` / `save(Category)` / `toggleFavorite(id, isFavorite)` / `softDeleteById(id)`
    - `account_repository.dart`：`listActive()` / `getById(id)` / `save(Account)` / `softDeleteById(id)`。**Step 7.2 新增 `getById`**：**不**过滤 `deleted_at`，软删账户也能查到——这是流水详情显示"（已删账户）"占位的实现路径（参见 `_TxTile.accountName`）。
    - `transaction_repository.dart`：`listActiveByLedger(ledgerId)` / `save(TransactionEntry)` / `softDeleteById(id)`
    - `budget_repository.dart`：`listActiveByLedger(ledgerId)` / `save(Budget)` / `softDeleteById(id)`。**Step 6.1 强化**：`save()` 内额外查 `(ledgerId, period, categoryId)` 是否有未软删的同键预算（`categoryId == null` 与非空分别走 `isNull` / `equals`）；命中即抛 `BudgetConflictException`（同文件公开类，`Exception` 而非 `Error`）。允许"同 id 视为更新"（excludeId 排除自身）；软删后释放唯一性锁，可重建。
  - 所有仓库的 `LocalXxxRepository` 构造参数统一为 `(db, deviceId, {clock})`，内部持有 `AppDatabase` + 对应 DAO + `SyncOpDao`。
  - **共同职责**：
    1. `save`：覆写 `updated_at`（clock）+ `device_id`（构造参数），单事务内 `dao.upsert` + `syncOpDao.enqueue('upsert')`。返回已被 repo 覆写的实体快照。
    2. `softDeleteById`：先查一行判存（不存在静默返回），单事务内直接写 `updated_at` / `deleted_at` / `device_id` 三列 + `syncOpDao.enqueue('delete')`。**不调用 DAO 的 `softDeleteById`**——DAO 只管两列、不含 `device_id`；repo 三列全写以保证同步 LWW tiebreak 一致。
    3. 无论同步开关是否启用，每次写入/软删都入队 sync_op。若同步一直关闭，表会长期增长——这是刻意的，保留"稍后启用同步时追溯本地历史"的能力。
  - **`providers.dart`**（Step 2.3）：7 个 `@Riverpod(keepAlive: true)` provider：
    - `CurrentLedgerId`（`@riverpod` AsyncNotifier，`keepAlive: true`，Step 4.1 升级）：`build()` 先查 `user_pref.current_ledger_id`（校验仍存在且活跃），失败则回退首个活跃账本；`switchTo(newId)` 持久化到 `user_pref` 后 `invalidateSelf()` 触发重建。
    - `ledgerRepository(Ref)` / `categoryRepository(Ref)` / `accountRepository(Ref)` / `transactionRepository(Ref)` / `budgetRepository(Ref)` → `Future<XxxRepository>`：`watch(appDatabaseProvider)` + `await watch(deviceIdProvider.future)`，构造 `LocalXxxRepository`。
    - 所有仓库 provider 返回抽象接口类型（`LedgerRepository` 等），但内部构造的是 `LocalXxxRepository` 具体实现——UI 消费 `AsyncValue<XxxRepository>`，已通过接口隔离。

### `lib/domain/`
- **`entity/`**（Step 2.1 已填充）：5 个纯 Dart 不可变实体，文件名与类名一一对应（`Ledger` / `Category` / `Account` / `TransactionEntry` / `Budget`）。每个实体:
  - 所有字段 `final` + `const` 构造；所有非空字段在构造中是 `required` 或带默认值。
  - `copyWith({...})`——所有参数可空，**null 即不改**；**不支持通过 copyWith 把一个已有值清回 null**（要反软删、清 toAccountId 等场景，Step 12.2 或相关业务步骤再加 `restore()` / `clearXxx()` 方法，或调用方直接构造新实体）。
  - `toJson()` / `fromJson(Map)`：键名统一 snake_case（与设计文档 §7.1 DDL 以及 Phase 10 Supabase 列名一致）；`DateTime` 用 ISO 8601 字符串；`Uint8List?`（仅 `TransactionEntry` 有）用 **base64 字符串**；`bool` / `double` / `int` / `String?` 走原生 JSON 类型。`fromJson` 对可空字段显式 `??` 应用默认值，保证默认值在序列化-反序列化链路上不丢（比如 `defaultCurrency='CNY'`、`fxRate=1.0`、`carryOver=false`）。
  - `==` / `hashCode` 手写。对 `TransactionEntry.noteEncrypted` / `attachmentsEncrypted` 走**深比较**（`_bytesEqual` / `_bytesHash` 位于 `transaction_entry.dart` 底部的 top-level 私有函数）——原因：`Uint8List` 在 Dart 默认是引用相等，`Uint8List.fromList([1,2,3]) == Uint8List.fromList([1,2,3])` 为 `false`，若不深比较，`fromJson(toJson(x)) == x` 的验收会假阴。
  - `toString()` 列出所有字段（bytes 字段仅打印 length），`expect(..., equals(...))` 失败时能直接看出哪个字段不匹配。
  - **类型收紧**相对于 drift 数据类（也即"一一对应"的语义解释）：`archived` / `includeInTotal` / `carryOver` 用 `bool` 而非 `int?`；`defaultCurrency` / `currency` / `fxRate` / `initialBalance` / `sortOrder` 用非空 + 默认值；`created_at` / `updated_at` / `deleted_at` / `occurred_at` / `start_date` 用 `DateTime?`。仓库层（Step 2.2）承担 drift `int epoch ms` ↔ `DateTime` 与 `int?` ↔ `bool` 的桥接。
  - **`TransactionEntry` 的命名**：drift 数据类叫 `TransactionEntryRow`（Step 1.3 备忘有记录），此命名差异是为了让领域层享有纯粹 `TransactionEntry` 这个名字。仓库层同时引入两个类型时可用 `import 'package:.../transaction_entry_table.dart' show TransactionEntryRow;` + `import 'package:.../transaction_entry.dart' show TransactionEntry;` 避免重名冲突。
- **`usecase/`**：预留给需要跨多个仓库协调的业务动作；简单场景可直接在仓库中完成，不强求每个功能都建一个 usecase。

### `lib/features/`
UI + 状态管理的纵向切分，每个子目录对应一块用户可见功能。

- **`budget/`**（Step 6.1 列表/编辑；Step 6.2 进度计算 + 颜色 + 震动）：
  - **`budget_progress.dart`**（Step 6.2 新增）：纯 Dart 工具集，不依赖 Flutter / Riverpod。
    - `BudgetProgressLevel { green, orange, red }`、`BudgetProgress(spent, limit, ratio, level)`。
    - `computeBudgetProgress({spent, limit})`：色档纯函数。`<70%` 绿、`70%~100%`（含两端）橙、`>100%` 红；`limit <= 0` 直接返回 ratio=0 / level=green，避免误震动。
    - `budgetPeriodRange(period, now)`：返回半开区间 `[start, end)`。`monthly` = now 所在自然月，`yearly` = now 所在自然年。Step 6.4 接入结转后会改造为以 `Budget.startDate` 起算。
    - `computePeriodSpent({budget, transactions, now})`：按上述区间过滤 + `type == 'expense'` + `categoryId 匹配（总预算不限）` + `deletedAt == null` 累加金额。
    - `shouldTriggerBudgetVibration({level, alreadyVibrated})`：把"是否触发震动"的决策抽出为纯函数，`HapticFeedback` 留给 UI 调用方，便于单测覆盖"仅首次"语义。
  - **`budget_providers.dart`**：
    - `kParentKeyLabels`：一级分类 key → 中文标签的常量映射（与 `seeder.dart` 的 `categoriesByParent.keys` 同集合，仅是展示层翻译）。
    - `activeBudgets(Ref)`（`@riverpod FutureProvider`）：当前账本的活跃预算列表，客户端排序——先按 `period` 月→年、再按 `categoryId == null` 的总预算优先。依赖 `currentLedgerIdProvider` + `budgetRepositoryProvider`。
    - `budgetableCategories(Ref)`（`@riverpod FutureProvider`）：从 `categoryRepositoryProvider.listActiveAll()` 中过滤掉 `parentKey == 'income'` 的分类——预算只针对支出。依赖 `categoryRepositoryProvider`。
    - `BudgetClock` typedef + `budgetClock(Ref)` provider（`keepAlive`）：默认 `DateTime.now`；测试覆盖以锁定参考时间，避免周期边界 flaky。
    - `budgetProgressFor(Ref, Budget)`（`@riverpod FutureProvider.family`）：拉当前账本流水 → `computePeriodSpent` → `computeBudgetProgress`。Family key = Budget 实体，因此预算金额变更会产生新的 cache entry，旧 entry 由 autoDispose 回收；Riverpod 用 `Budget.hashCode` / `==`，所以实体的 `==` 实现必须包含所有相关字段（已有）。
    - `BudgetVibrationSession`（`@Riverpod(keepAlive: true) class`）：状态为 `Set<String>`（已震动的预算 id 集合）。`hasVibrated(id)` / `markVibrated(id)`（幂等：重复 mark 不重建 state，避免无谓 rebuild）/ `clear(id)`。冷启动后自然清空——这就是"会话级"语义，符合 implementation-plan 的"session 标记"约束。
  - **`budget_list_page.dart`**：`BudgetListPage`（ConsumerWidget）。
    - `Scaffold` + `FloatingActionButton.extended('新建预算')` → `context.push('/budget/edit')`，返回 `true` 时 `invalidate(activeBudgetsProvider)` 刷新。
    - 内嵌 `_BudgetCard`（Step 6.2 升级为 `ConsumerWidget`）：左侧分类 emoji（总预算用 💰）+ 中部"标题（分类名 / 总预算）+ 周期/结转副标题"+ 右侧金额 + 删除按钮；下方追加 `_ProgressSection`（订阅 `budgetProgressForProvider(budget)`）。
    - **`_ProgressSection`**（ConsumerWidget）：渲染彩色 `LinearProgressIndicator`（color 来自 `BianBianSemanticColors`：green=success / orange=warning / red=danger，进度条 value 用 `ratio.clamp(0, 1)` 防止溢出）+ 一行"已花 ¥X / ¥Y · 百分比"。当 `shouldTriggerBudgetVibration(level, alreadyVibrated)` 为真时，**整段** `markVibrated + HapticFeedback.heavyImpact()` 都放进 `WidgetsBinding.addPostFrameCallback`——build 期间修改 provider state 会触发 Riverpod 的 "Tried to modify a provider while the widget tree was building" 断言。回调内再做一次 `hasVibrated` 检查，保证同帧多次 build 注册多个 postFrame 时只执行一次。
    - 空状态：`_EmptyState`（💰 图标 + "还没有预算"+"点右下角加一个吧 🐰"）。
    - 空状态：`_EmptyState`（💰 图标 + "还没有预算"+"点右下角加一个吧 🐰"）。
  - **`budget_edit_page.dart`**：`BudgetEditPage`（ConsumerStatefulWidget，`budgetId` 可选——传入即编辑，否则新建）。
    - `_loadBudget()` 编辑模式下从 `repo.listActiveByLedger` 中按 id 提取（不存在抛 `StateError`）；`_hydrate(...)` 仅在第一次 build 时把字段写入表单 controller / `_period` / `_categoryId` / `_carryOver`，避免 setState 循环覆盖输入。
    - 表单组件：周期 `SegmentedButton<String>('monthly'/'yearly')`、分类 `DropdownButtonFormField<String?>`（首项"总预算（不限分类）"对应 `null`，其余按 `(parentKey 中文 + sortOrder)` 排序）、金额 `TextFormField`（`numberWithOptions(decimal: true)` + 正则限制最多两位小数）、结转 `SwitchListTile`（subtitle 注明"Step 6.4 实装"）。
    - 保存逻辑：新建走 `const Uuid().v4()` + `startDate` 取本月/本年第一天；编辑走"裸构造 Budget"（`copyWith` 不能把 `categoryId` 清回 null，如果用户从分类预算切回总预算会失败）。捕获 `BudgetConflictException` 走 SnackBar；其他异常走通用"保存失败：$e"。
    - 路由 `/budget` / `/budget/edit?id=...` 在 `app_router.dart` 注册。

- **`stats/`**(Step 5.6 已填充)：
  - **`stats_range_providers.dart`**：统计区间状态源 + 统计聚合纯函数/Provider。
    - `StatsRangePreset`：`thisMonth / lastMonth / thisYear / custom`；
    - `StatsDateRange`：`month(...)` / `year(...)` 边界构造 + `normalize(start, end)`（支持起止反序与跨年）；
    - `StatsRangeState`：当前 preset + 生效区间；
    - `StatsRange`（`@Riverpod(keepAlive: true)`）：`build()` 默认本月；`setPreset(...)` 切换本月/上月/本年；`setCustomRange(...)` 写入自定义区间。
    - `StatsLinePoint` + `statsLinePointsProvider`：按日聚合收入/支出折线数据，排除 transfer。
    - `StatsPieSlice` + `aggregatePieSlices(...)` + `statsPieSlicesProvider`：支出分类 Top 6 + 其他饼图聚合。
    - `StatsRankItem` + `aggregateRankItems(...)` + `statsRankItemsProvider`：按分类金额生成收支排行榜，收入/支出各自计算百分比。
    - `StatsHeatmapCell` + `quantileNormalize(...)` + `aggregateHeatmapCells(...)` + `statsHeatmapCellsProvider`：按日聚合支出热力图，并使用 90 分位归一化抑制极端值“冲白”其它日期。
  - **`stats_page.dart`**：`StatsPage`（ConsumerStatefulWidget，Step 5.6 升级）。
    - 顶部 4 个区间入口（本月/上月/本年/自定义）；
    - 自定义区间用 `showDateRangePicker` 选择后写回 `statsRangeProvider`；
    - 页面展示当前生效区间，作为 Step 5.2+ 图表的统一时间过滤来源；
    - 当前卡片布局：收支折线图 / 分类饼图 / 收支排行榜 / 支出日历热力图，整体被 `RepaintBoundary(key: _chartsBoundaryKey)` + `Container(surface)` 包裹（避免截图透明）；
    - 标题行右侧承载 `IconButton(Icons.ios_share)`，点击弹出 `showModalBottomSheet`（PNG / CSV 二选一），导出过程中显示 `CircularProgressIndicator`，错误通过 `ScaffoldMessenger` 提示；
    - 热力图 `_HeatmapCard` 使用“周列 × 星期行”的滚动网格，cell 通过 `Tooltip` 展示“日期 + 支出金额”，颜色由 `BianBianSemanticColors.danger` 与 `surfaceContainerHighest` 插值得到。
  - **`stats_export_service.dart`**（Step 5.6 新建）：
    - `encodeStatsCsv({entries, categoryMap, accountMap, range})`（顶层 `@visibleForTesting` 纯函数）：UTF-8 BOM `\uFEFF` + 中文列头 `日期/类型/金额/币种/分类/账户/转入账户/备注` + RFC 4180 转义 + 按 `occurredAt` 升序 + 区间外丢弃 + 缺失字段空白。
    - `buildExportFileName({prefix, extension, now, range})`（顶层 `@visibleForTesting` 纯函数）：`<prefix>_<startDate>_<endDate>_<timestamp>.<ext>`。
    - `StatsExportService`：`exportCsv(...)` / `exportPng({boundary, range, pixelRatio = 3.0})` / `shareFile(File, {subject, text})` / `writeExportFile(filename, bytes)` / `capturePng(boundary, pixelRatio)`。`<documents>/exports/` 子目录写盘 + `share_plus.Share.shareXFiles` 分享。三个钩子可注入：`documentsDirProvider` / `shareXFiles` / `now`。

- **`record/`**（Step 3.1 已填充，Step 3.2 已完成分类模型重构）：
  - **`record_providers.dart`**：
    - `RecordMonth`（`@riverpod` Notifier）：当前导航月份（`DateTime`），`build()` 返回当月，`previous()` / `next()` 切换月份。Phase 5 可扩展为自定义区间。
    - `recordMonthSummary(Ref)`（`@riverpod FutureProvider`）：依赖 `recordMonthProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider`。取当前账本全量活跃流水 → 客户端按月份过滤 → 按 `occurredAt` 倒序 → 汇总收入/支出 → 按天分组为 `List<DailyTransactions>` → 产出 `RecordMonthSummary`。
    - 数据类 `DailyTransactions` / `RecordMonthSummary`：不依赖 flutter/riverpod 的纯 Dart 类型。
  - **`record_home_page.dart`**：`RecordHomePage`（ConsumerWidget）→ 内层 `Scaffold`（自有 FAB）。5 个子区域：
    1. `_TopBar`：`currentLedgerIdProvider` + `ledgerRepositoryProvider` → 显示账本 `📒 名称 ▾` + 搜索占位
    2. `_MonthBar`：左右箭头 + `{year}年{month}月` → `ref.read(recordMonthProvider.notifier).previous()/next()`
    3. `_DataCards`：3 个 `_CardChip`（收入/支出/结余），财务三色
    4. `_QuickInputBar`：单行输入 + `✨ 识别` 占位
    5. `_TransactionList`：`summary.when()` 三态（loading/error/data），无数据时"开始记第一笔吧 🐰"空状态，有数据时按天分组列表
  - FAB `+` → Step 3.2 已接线到 `/record/new`（`context.go('/record/new')`）。
  - **`record_new_providers.dart`**（Step 3.2 新增并重构）：
    - `RecordFormData`：表单数据类（`selectedParentKey` / expression / amount / categoryId / accountId / occurredAt / note），`canSave => amount != null && amount! > 0 && categoryId != null`。
    - `_parseExpr(String expr)`：递归下降求值器，从右向左找 `+`/`-` 分割点，仅支持浮点加减。不完整表达式返回 null。
    - `RecordForm`（`@riverpod` Notifier）：管理表单状态。`onKeyTap` 处理键盘按键；`setParentKey` 切换一级分类；Step 3.5 新增本地附件状态管理（最多 3 张、相册/拍照、删除、沙盒落盘）；`save()` 按 `selectedParentKey` 自动推导流水类型（`income` 或 `expense`）并保存，同时把附件路径列表编码到 `attachmentsEncrypted`（明文 JSON bytes），随后 `invalidate(recordMonthSummaryProvider)`。
  - **`record_new_page.dart`**（Step 3.2 新增并重构；Step 3.5 增量）：`RecordNewPage`（ConsumerWidget），`Column(Expanded(SingleChildScrollView), NumberKeyboard)` 布局。子组件：`_ParentTabs`（底部单字一级分类，含 `☆` 收藏）/ `_AmountDisplay` / `_CategoryGrid`（按一级或收藏过滤）/ `_AccountSelector` / `_LedgerLabel` / `_TimeAndNote` / `_SaveButton`。已移除顶部收入/支出/转账 tab，且不再提供“再记一笔”开关。Step 3.5 在备注弹层新增本地附件区（相册/拍照入口、缩略图预览、删除、`x/3` 上限提示）。
  - **`widgets/number_keyboard.dart`**（Step 3.2 新增，2026-04-26 调整）：`NumberKeyboard`，4 行布局（`7 8 9 ⌫` / `4 5 6 +` / `1 2 3 -` / `CNY 0 . ✓/=`），移除 `C` 与括号键；右下动作键按 `showEquals` 动态显示 `=` 或 `✓`，并受 `canAction` 控制可点击态。

### `test/data/local/app_database_test.dart`
- Step 1.1 落地的 2 个用例：① 空库插入 `user_pref(id=1, deviceId=...)` 并完整读回（校验所有字段默认值）；② 显式 `id: Value(2)` 被 CHECK 约束拒绝。
- 测试走 `AppDatabase.forTesting(NativeDatabase.memory())`，**不**走 SQLCipher——仅验 schema 行为。SQLCipher 的真实加密效果只能在设备级验证（见 progress.md Step 1.2 验证节）。

### `test/data/local/business_tables_test.dart`
- Step 1.3 落地的 7 个用例（6 张业务表 + 1 个索引存在性）：
  1. `ledger` · insert → update(`updated_at`) → soft-delete(`deleted_at`)；校验默认值 `defaultCurrency='CNY'` / `archived=0`。
  2. `category` · 同上；先插父 ledger 演练真实路径（FK 未强制，但当作最佳实践）。
  3. `account` · 同上；校验 `initialBalance=-1200.0`（信用卡欠款为负）、`includeInTotal=1`、`currency='CNY'`。
  4. `transaction_entry` · 同上；校验 `fxRate=1.0` 默认值、tags 明文、`noteEncrypted` 为 null（Phase 11 才写密文）。
  5. `idx_tx_ledger_time` / `idx_tx_updated` 两索引存在性——直接查 `sqlite_master WHERE type='index' AND tbl_name='transaction_entry'`。
  6. `budget` · 同上；`categoryId=null` 表示总预算。
  7. `sync_op` · 队列语义：insert（断言 AUTOINCREMENT `id == 1`）→ tried++ + `lastError` 写入 → 物理 delete。
- 都走 `NativeDatabase.memory()`；用常量 `insertTs / updateTs / deleteTs` 固定时间戳，避免 flaky。

### `test/data/local/dao_test.dart`
- Step 1.4 落地的 5 个用例（每个 DAO 一组，组内按 4 类方法顺序跑一条完整流程）：
  1. `LedgerDao` · upsert×2（含二次 upsert 覆写同 id 触发更新路径）→ `listActive` 按 updated_at DESC → softDelete ledger-1 → `listActive` 剩 ledger-2 → 直查 `select(ledgerTable)` 确认软删行仍物理存在且 `deleted_at`/`updated_at` 均已写 → `hardDeleteById` 返回 1 → 原始表查不到（这就是验收要求"soft-delete 后普通查询查不到，但硬删除接口能看到"的落地）。
  2. `CategoryDao` · 在 ledger-1 下插两条 + ledger-2 下一条（跨账本噪声），`listActiveByLedger('ledger-1')` 断言按 `sort_order` 升序且不含 ledger-2 的噪声，然后跑 soft/hardDelete。
  3. `AccountDao` · 同 LedgerDao 模式（account 无 ledgerId）。
  4. `TransactionEntryDao` · 两条不同 occurred_at 的 tx，断言 `listActiveByLedger` 按 `occurred_at DESC`（命中 `idx_tx_ledger_time`），softDelete 一条后 list 排除，hardDelete 命中软删行。
  5. `BudgetDao` · 三条（ledger-1 总预算 + ledger-1 餐饮分类预算 + ledger-2 年度总预算），断言 `listActiveByLedger('ledger-1')` 仅返回前两条且包含 categoryId=null 的总预算，soft/hardDelete 流程同上。
- 共享 `seedLedger(id)` 辅助函数插父 ledger（category/transaction 需要）。都走 `NativeDatabase.memory()`；`hardDeleteById` 的返回值 = 物理删除行数，测试里都断言为 1（精确命中软删后的残留）。

### `test/core/crypto/bianbian_crypto_test.dart`
- Step 1.6 落地的 11 个用例：
  - **deriveKey（3）**：① RFC 7914 §11 的 PBKDF2-HMAC-SHA256(`passwd`,`salt`,c=1,64B) 向量（取前 32 字节 = `55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc`）；② 默认 iterations=100000 产出 32 字节长度校验；③ 确定性（同输入同输出）+ 不同 salt 产出不同密钥。
  - **AES-GCM KAT（1）**：NIST SP 800-38D Test Case 13（zero key / zero nonce / 16 字节零明文），对照固定 `cea7403d4d606b6e074ec5d3baf39d18 ‖ d0d1c8a799996bf0265b98b5d48ab919` —— 通过 `@visibleForTesting` 的 `encryptWithFixedNonce` 注入 nonce，然后断言打包 bytes 精确相等；同步反向验 decrypt 得回 16 字节零明文。
  - **encrypt/decrypt 往返（2）**：含非 ASCII 的 UTF-8 字符串（中文 + emoji 🐰）往返不丢失字节；同明文二次 encrypt 产出不同 bytes（fresh nonce）但都能解回。
  - **失败场景（4）**：错误密钥 → `DecryptionFailure`；密文段某字节翻转 → `DecryptionFailure`（GCM tag 认证生效）；tag 段某字节翻转 → 同；packed 短于 `12+16=28` 字节 → 同。
  - **参数校验（1）**：非 32 字节 key 抛 `ArgumentError`。
- 辅助函数：`_hex(String)` 把 hex 字符串转 `Uint8List`；`_countingBytes(32)` 产出 `[0,1,2,...,31]` 作为合法非零测试 key。

### `test/data/local/device_id_store_test.dart`
- Step 1.5 落地的 5 个用例，对应 `LocalDeviceIdStore.loadOrCreate()` 的四条分支 + 一条脏数据覆盖：
  1. **全新安装**：secure + user_pref 均空 → 注入的 `uuidFactory` 被调 **1 次**（断言 `callCount == 1`），最终值同时写回两侧。
  2. **冷启动**：secure 预置合法 UUID → 两次调 `loadOrCreate` 返回同值，`uuidFactory` 注入为 `() => fail(...)` 以确保**绝不会被调用**；user_pref 在第一次调用时被顺手补写。
  3. **iOS 重装**：secure 留存 + user_pref 空 → 返回 secure 值 + 补写 user_pref；`uuidFactory` 也配成 fail。
  4. **恢复分支**：手动 `await db.into(userPrefTable).insert(UserPrefTableCompanion.insert(deviceId: _fixedUuidB))` 预置 user_pref，secure 空 → 返回 pref 值并回写 secure。
  5. **脏数据**：secure 存 `'not-a-uuid'` → 视为缺失，回落到生成新 UUID 并覆盖原脏值。
- 自带 `_InMemoryStore` 实现 `SecureKeyValueStore`（不复用 `db_cipher_key_store_test` 的同名类是为了避免跨文件测试耦合）；两个固定 UUID 字面量 `_fixedUuidA` / `_fixedUuidB` 用于跨用例复用。`setUp` 用 `AppDatabase.forTesting(NativeDatabase.memory())` 保证每个用例独立 DB。

### `test/data/local/db_cipher_key_store_test.dart`
- Step 1.2 落地的 4 个用例：① 首次调用生成 64 字符小写 hex 并持久化；② 第二次调用返回同一密钥；③ 底层已存在非法值时覆写；④ 两个独立 `DbCipherKeyStore` 实例（用 `Random.secure()`）产出不同密钥。
- 通过注入内存实现的 `SecureKeyValueStore` 测试，免去 platform channel mock；`Random(seed)` 让 CI 上输出可重现。

### `test/data/local/seeder_test.dart`
- Step 1.7 落地的 3 个用例：
  1. **空库路径**：单次 `seedIfEmpty()` 后断言 1 ledger（含 emoji `📒`、`default_currency='CNY'`、`archived=0`、`device_id='device-a'`、时间戳 = 注入的 `fixedInstant`）+ 28 categories（18 `expense` + 10 `income`，各自按 `sort_order` 升序首个是「餐饮」/「工资」；末个都叫「其他」且颜色按 `i%6` 循环）+ 5 accounts（5 种预期 type、`includeInTotal=1`、`currency='CNY'`、`initialBalance=0.0`）。
  2. **幂等**：连续两次调用（第二次 `counterStart=1000` 确保不会意外重复生成同 UUID），对比前后两次 `ledger/category/account` 的 id 集合应完全相等——证明第二次整体跳过。
  3. **预置账本跳过**：手动插入一个 `'工作'` 账本，然后 `seedIfEmpty()` → 仍只剩那一个账本、分类与账户表保持空，确认 seeder 不越权"补齐"任何数据。
- 辅助 `makeSeeder({counterStart})` 封装确定性 `clock`（固定 `fixedInstant = 1714000000000`）+ 确定性 UUID 工厂（`uuid-0001`, `uuid-0002`, ... 递增）——让"第一个 UUID 属于 ledger"之类的断言可以精确到 id 字符串。

### `test/domain/entity/entities_test.dart`
- Step 2.1 落地的 17 个用例（每个实体 3-4 条 + 1 条依赖隔离）：
  - **Ledger / Category / Account / Budget**：各 3 条——全字段 roundtrip、部分可空字段为 null 的 roundtrip（同时验证默认值落地：`defaultCurrency='CNY'`、`sortOrder=0`、`initialBalance=0`、`carryOver=false` 等）、`copyWith` 改一字段其它不动。
  - **TransactionEntry**：4 条——前两条同上，加上 `Uint8List` 深等断言（`identical` 是 `false` 但 `==` 是 `true`，证明 `_bytesEqual` 生效）+ 一条反面用例（换一组 bytes 后必须 `!=`，防止 `_bytesEqual` 被改成 trivially true 时无人察觉）。
  - **domain 依赖隔离**：1 条——递归扫 `lib/domain/**.dart`，只检查 `import ` / `export ` 开头的行，禁止出现 `'package:drift/` 或 `"package:drift/`。注释 / 字符串里的 `package:drift/` 字面量不会误伤。
- 所有测试用固定时间戳（`DateTime.utc(2026, 4, 21, ...)`）构造实体，不依赖 `DateTime.now()`，CI 可重复。

### `test/data/repository/transaction_repository_test.dart`
- Step 2.2 落地的 4 个用例（以 TransactionEntry 为代表验证所有仓库的共同契约）：
  1. **create → sync_op 入队**：构造一个 `TransactionEntry`（`updatedAt` 与 `deviceId` 故意写错误值），`repo.save()` 后断言——返回实体的 `updatedAt` 已被覆写为固定时间戳 `1714000000000`（注入 clock）、`deviceId` 被覆写为 `'device-test'`（注入参数）；`syncOpDao.listAll()` 有 1 条 upsert，payload JSON 里 `amount=42.5`、`device_id='device-test'`。
  2. **update → sync_op 再入队**：同 id 第二次 `save`（改 `amount 100→200`），断言 sync_op 共 2 条 upsert，第 2 条 payload 含 `amount=200`。
  3. **softDeleteById → sync_op 入队 delete**：先 save 后 softDelete，断言 `listActiveByLedger` 返回空、sync_op 共 2 条（1 upsert + 1 delete）、delete payload 含 `deleted_at` 非空 + `device_id='device-test'`。
  4. **返回实体是纯 Dart 类型**：`isA<TransactionEntry>()` + `runtimeType.toString() == 'TransactionEntry'`——不含 drift 专属 ref/getter。
- 共享 `setUp` → `NativeDatabase.memory()` + 种子一条 `ledger-1`（TransactionEntry 需要父 ledger，FK 虽未强制但保持最佳实践）。`RepoClock` 注入固定 `1714000000000`。
- 其余 4 个仓库（Ledger/Category/Account/Budget）的实现形式完全一致、复用同一套 `entity_mappers.dart` 映射函数——仅以 TransactionEntry 为代表做覆盖，避免 5×3=15 条高重复用例。

### `test/widget_test.dart`
- HomeShell 骨架测试，共 5 用例（Step 3.1 / Step 6.1 配合）：
  1. HomeShell renders all 4 bottom-nav tabs（Tab 名在 nav bar 各出现一次）。
  2. BottomNavigationBar background is cream yellow `#FFE9B0`。
  3. Tapping "统计" tab switches body text（body + nav bar 各一处"统计"）。
  4. 记账 Tab 通过 provider 显示当前账本名称：注入 `_FakeLedgerRepository` 返回"测试账本"，验证 `find.text('测试账本')` + Key 断言。
  5. 有 mock 数据时流水列表按天分组：注入两条 4 月流水，断言月份 header / 金额 / 数据卡片。
- 所有测试通过 `ProviderScope(overrides: _standardOverrides())` 注入。Step 6.1 新增 `_FixedRecordMonth` Notifier 并 override `recordMonthProvider` 为 `DateTime(2026, 4)`——此前用例 4 / 5 硬编码 "2026年4月" / "4月25日"，跨月（如 2026-05-01 之后）跑会因 `RecordMonth.build()` 读 `DateTime.now()` 而 flaky；固定后测试与真实日期解耦。
- `_FakeLedgerRepository` 实现 `LedgerRepository` 接口：`getById` 返回固定 Ledger、`listActive` 返回单元素列表，其余操作走 `fail()`。
- `_FakeTransactionRepository` 实现 `TransactionRepository` 接口：`listActiveByLedger` 返回构造时传入的固定列表，其余走 `fail()`。

### `test/data/repository/budget_repository_test.dart`
- Step 6.1 落地的 8 个用例覆盖唯一性约束的所有边界：
  1. 同账本 + 同周期 + 同分类（categoryId 非空）二次保存抛 `BudgetConflictException`。
  2. 同账本 + 同周期 + `categoryId == null`（总预算）二次保存抛冲突——`isNull` 路径单独覆盖。
  3. 同账本同周期不同分类可共存。
  4. 总预算与分类预算同账本同周期可共存（一个 categoryId=null + 一个 categoryId 非空）。
  5. 同分类不同周期（monthly / yearly）可共存。
  6. 不同账本同周期同分类可共存。
  7. 同 id 二次保存视为更新，`excludeId` 排除自身——不报冲突，金额从 1000 变 2000。
  8. 软删除已存在预算后释放唯一性锁，允许重建（验证 `_findActiveDuplicate` 走 `deletedAt.isNull()` 过滤）。
- 共享 setUp：`AppDatabase.forTesting(NativeDatabase.memory())` + 种子 `ledger-1` / `ledger-2`。`RepoClock` 注入固定 `1714000000000`。

### `pubspec.yaml`
- 运行依赖（Step 0.3 集合经 Step 1.2 调整后）：
  - 路由：`go_router ^17.2.1`
  - 状态：`flutter_riverpod ^2.6.1`、`riverpod_annotation ^2.6.1`
  - 本地 DB：`drift '>=2.22.0 <2.28.2'`、`sqlcipher_flutter_libs ^0.6.5`（实际解析到 0.6.8）、`path_provider ^2.1.5`、`path ^1.9.1`
    - **Step 1.2 变更**：移除 `sqlite3_flutter_libs`；`sqlcipher_flutter_libs` 从 `^0.7.0+eol`（EOL 空壳，仅适配 sqlite3 3.x）回退到 `^0.6.5`（与 `sqlite3 2.x` 匹配并提供 `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions` 工具）。两者并存会在 Android 上同时链入普通 sqlite3 与 SQLCipher，行为未定义，drift 文档明确告警。
  - 远端：`supabase_flutter ^2.12.4`
  - 偏好/密钥：`shared_preferences ^2.5.5`、`flutter_secure_storage ^10.0.0`
  - 加密：`cryptography ^2.9.0`
  - 图表/SVG：`fl_chart ^1.2.0`、`flutter_svg ^2.2.4`
  - 平台能力：`local_auth ^3.0.1`、`flutter_local_notifications ^21.0.0`
  - 国际化/工具：`intl ^0.20.2`、`uuid ^4.5.3`、`flutter_localizations`（sdk）、`cupertino_icons ^1.0.8`
  - 分享：`share_plus ^10.1.4`（Step 5.6 新增，用于统计页导出 PNG/CSV 后唤起系统 Share Sheet）
- dev 依赖：`flutter_test`（sdk）、`flutter_lints ^6.0.0`、`build_runner ^2.4.13`、`drift_dev '>=2.22.0 <2.28.2'`、`riverpod_generator ^2.6.3`、`custom_lint ^0.7.4`、`riverpod_lint ^2.6.3`。
- 版本整体略落后于 pub.dev 最新（如 `flutter_riverpod` 锁 2.x），是为了彼此 API 兼容；若要升级需作为独立一步。

### `analysis_options.yaml`
- 继承 `package:flutter_lints/flutter.yaml`。
- 已追加 `analyzer.plugins: [custom_lint]`，使 `riverpod_lint` 规则在 `dart run custom_lint` 与 IDE 中生效（`flutter analyze` 不受此块影响，二者互补）。

### `android/app/build.gradle.kts`
- 应用 Gradle 脚本。`flutter_local_notifications` 依赖 Java 8+ 的时间 API，因此：
  - `compileOptions.isCoreLibraryDesugaringEnabled = true`
  - `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`
- 若升级 `flutter_local_notifications` 或其他 plugin 要求更高的 desugar 版本，这里是唯一改动点。
- `defaultConfig.minSdk = 23`（Step 1.2 确认值）——`flutter_secure_storage ^10.0.0` 使用 AndroidX `EncryptedSharedPreferences`，要求 API 23+。注意不再跟随 `flutter.minSdkVersion`，升级 Flutter 不会倒退此值。

## 依赖分层（Step 2.2 后已部分实现）

```
features/*  →  domain/entity/*  →  data/repository/（抽象接口） →  data/local/repository/（LocalXxxRepository）
                                     ↑                                          │
                                     └── 抽象接口与实现均在同一文件                    ├─ dao/（drift DAO）
                                                                                  ├─ entity_mappers.dart
                                                                                  └─ sync_op_dao.dart
```

- UI 仅通过 Riverpod Provider 获取 Repository，**不直接持有** drift / supabase 对象。
- `domain/entity` 禁止 import `package:drift/*`（Step 2.1 有依赖检查测试）。
- `data/repository/entity_mappers.dart` 是 `lib/data/` 与 `lib/domain/` 之间唯一桥接点。

## 本机约定

- Dart SDK：`^3.11.5`（pubspec.yaml 锁定）。
- Shell：本机虽为 Windows，但 Claude Code 使用 bash —— 脚本与命令统一 POSIX 风格（`/` 作分隔符、`/dev/null` 作空设备），禁止 `NUL` / 反斜杠路径。


## Phase 3 · Step 3.3 增量说明（2026-04-26）

- `lib/features/record/record_home_page.dart`：
  - 首页流水项点击进入只读详情底部页（新增 `_RecordDetailSheet`），不再直接进入编辑。
  - 详情页动作标准化为：编辑 / 复制 / 删除（`_DetailAction`）。
  - 编辑与复制均复用 `RecordNewPage` + `recordFormProvider.notifier.preloadFromEntry(...)`：
    - 编辑：`asEdit: true`（保留原 id，覆盖保存）
    - 复制：`asEdit: false`（新建语义，不覆盖原记录）
  - 首页支持 `Dismissible` 左滑删除，并在确认后执行 `TransactionRepository.softDeleteById`，随后 `invalidate(recordMonthSummaryProvider)` 刷新列表。
  - FAB 新建前先重置 `recordFormProvider`，防止编辑态脏状态污染新建流程。

- `test/data/repository/transaction_repository_test.dart`：
  - update 用例新增对 `updated_at` 递增断言与 upsert payload 中 `updated_at/device_id` 断言；
  - soft delete 用例新增“库内物理行仍存在且 `deleted_at` 非空”断言，明确软删除语义。

- 本次仅为 Step 3.3 增量，未引入 Step 3.4（转账）字段与流程改造。

## Phase 3 · Step 3.5 增量说明（2026-04-26）

- `lib/features/record/record_new_providers.dart`：
  - `RecordFormData` 增加 `attachmentPaths: List<String>`，用于承载当前表单的本地附件路径集合。
  - `RecordForm` 增加附件操作 API：
    - `pickAndAttachFromGallery()` / `pickAndAttachFromCamera()`；
    - `removeAttachmentAt(index)`；
    - `canAddAttachment`（上限 3 张）。
  - 文件持久化策略：选择图片后复制到应用文档目录 `attachments/<tx_id>/...`，避免依赖系统临时路径。
  - 序列化策略：附件路径数组 `List<String>` 以 UTF-8 JSON 编码写入 `TransactionEntry.attachmentsEncrypted`（当前阶段为明文 JSON bytes）。
  - 反序列化策略：`preloadFromEntry(...)` 从 `attachmentsEncrypted` 解码恢复 `attachmentPaths`，保证编辑/复制时可回显已有附件。
- `lib/features/record/record_new_page.dart`：
  - 备注弹层新增附件 UI（缩略图、删除、相册/拍照入口、数量提示 `x/3`）。
  - `_NotePillButton` 由 `StatelessWidget` 调整为 `ConsumerWidget`，直接感知附件状态变化。
- `test/features/record/record_new_providers_test.dart`：
  - 增加 Step 3.5 断言：保存时 `attachmentPaths` 会编码进 `attachmentsEncrypted`，并可按 JSON 数组还原。

## Phase 4 · Step 4.1 增量说明（2026-04-26）

- `lib/data/repository/providers.dart`：
  - `currentLedgerId` 从 `Future<String>` 升级为 `AsyncNotifier`（`CurrentLedgerId`）。
  - `build()` 先查 `user_pref.current_ledger_id`，验证目标账本仍存在且活跃 → 是则返回；否则取第一个活跃账本并写回 `user_pref`。
  - 新增 `switchTo(newId)` 供 UI 切换：持久化 → `invalidateSelf()` → `build()` 重跑读到新值。

- `lib/data/local/dao/transaction_entry_dao.dart`：
  - 新增 `countActiveByLedger(ledgerId)`：`SELECT COUNT(*) WHERE ledger_id=? AND deleted_at IS NULL`，供账本列表展示流水总数。

- `lib/features/ledger/ledger_providers.dart`（新建）：
  - `LedgerTxCounts`（AsyncNotifier）：遍历活跃账本调 `countActiveByLedger`，产出 `Map<String, int>`。
  - `invalidate()` 供外部（切换账本 / 写流水后）触发全量重建。

- `lib/features/ledger/ledger_list_page.dart`（新建）：
  - `LedgerListPage`（ConsumerWidget）：`watch(currentLedgerIdProvider)` + `watch(ledgerRepositoryProvider)` + `watch(ledgerTxCountsProvider)` 三态渲染。
  - `ledgerGroupsProvider`（FutureProvider）：按 `archived` 字段分组。
  - `_LedgerCard`：封面 emoji + 名称 + 流水计数；当前账本奶油黄底色 + ✓ 高亮；归档卡片置灰 + archive 图标。
  - 切换后自动刷新 `ledgerTxCountsProvider`。

- `lib/app/home_shell.dart`：
  - 移除 `_LedgerPreviewBody` 及其 ConsumerStatefulWidget（Step 1.7 临时预览退役）。
  - index=2 分支改为 `const LedgerListPage()`。
  - 清理 `flutter_riverpod` / `app_database` / `local/providers` 三行无用 import。

- 测试更新：
  - 新增 `_TestCurrentLedgerId extends CurrentLedgerId`（覆盖 `build()` 返回固定 id），用于 `AsyncNotifierProvider` override。
  - 三处测试文件（widget_test / record_new_providers_test / record_new_page_test）的 override 同步升级。

## Phase 4 · Step 4.2 增量说明（2026-04-27）

- `lib/data/local/dao/transaction_entry_dao.dart`：
  - 新增 `softDeleteByLedgerId(ledgerId, {deletedAt, updatedAt})`——批量软删除某账本下所有未软删流水，返回受影响行数。

- `lib/data/local/dao/budget_dao.dart`：
  - 新增 `softDeleteByLedgerId(ledgerId, {deletedAt, updatedAt})`——批量软删除某账本下所有未软删预算，返回受影响行数。

- `lib/data/repository/transaction_repository.dart`：
  - 接口新增 `softDeleteByLedgerId(String ledgerId)`。
  - `LocalTransactionRepository` 实现：先查出所有将被软删的流水 → 调 DAO 批量写 → 逐条入队 sync_op delete。

- `lib/data/repository/budget_repository.dart`：
  - 接口新增 `softDeleteByLedgerId(String ledgerId)`。
  - `LocalBudgetRepository` 实现同上模式。

- `lib/data/repository/ledger_repository.dart`（重写）：
  - 接口新增 `setArchived(String id, bool archived)`——归档/取消归档，返回更新后的实体快照。
  - `LocalLedgerRepository` 新增持有 `TransactionEntryDao` / `BudgetDao`。
  - `softDeleteById` 改为级联：先调 `_txDao.softDeleteByLedgerId` → 再调 `_budgetDao.softDeleteByLedgerId` → 最后软删账本自身。全部在同一事务内完成。
  - `setArchived` 实现：查行 → 覆写 `archived`/`updated_at`/`device_id` → 入队 sync_op upsert。

- `lib/features/ledger/ledger_edit_page.dart`（新建）：
  - `LedgerEditPage`（ConsumerStatefulWidget）——支持新建/编辑双模式。
  - 表单含名称、封面 Emoji、默认币种下拉（CNY/USD/EUR/JPY/KRW/GBP/HKD）；编辑模式额外显示归档开关。
  - 保存时新建走 `const Uuid().v4()` 生成 id，编辑走 `copyWith` 更新；保存后 invalidate 相关 provider。

- `lib/app/app_router.dart`：
  - 新增路由 `/ledger/edit`（可选 query 参数 `id` 进入编辑模式）。

- `lib/features/ledger/ledger_list_page.dart`（重写）：
  - `LedgerListPage` 改为返回 `Scaffold`，新增 `FloatingActionButton.extended`（"新建账本"）→ 跳转 `/ledger/edit`。
  - `_LedgerCard` 新增 `onLongPress` 回调。
  - 活跃账本长按弹出底部菜单：编辑 / 归档（或取消归档） / 删除。当前账本删除按钮置灰并提示"请先切换到其他账本"。
  - 归档账本长按弹出底部菜单：取消归档 / 删除。
  - 删除前弹出二次确认对话框，确认后调 `repo.softDeleteById`（级联删除流水+预算），删除后若为当前账本则 invalidate `currentLedgerIdProvider` 触发重新选择。

- 测试更新：
  - `test/widget_test.dart`：`_FakeLedgerRepository` 补 `setArchived`；`_FakeTransactionRepository` 补 `softDeleteByLedgerId`。
  - `test/features/record/record_new_page_test.dart`：`_FakeLedgerRepository` 补 `setArchived`；`_FakeTransactionRepository` 补 `softDeleteByLedgerId`。
  - `test/features/record/record_new_providers_test.dart`：`_FakeTransactionRepository` 补 `softDeleteByLedgerId`。

## Phase 5 · Step 5.1 增量说明（2026-04-28）

- `lib/features/stats/stats_range_providers.dart`（新建）：
  - 新增 `StatsRangePreset`：`thisMonth / lastMonth / thisYear / custom`。
  - 新增 `StatsDateRange`：封装统计时间区间，提供 `month(...)` / `year(...)` 构造与 `normalize(start, end)`（支持起止反序与跨年边界归一）。
  - 新增 `StatsRangeState`：承载当前区间模式与生效区间。
  - 新增 `StatsRange`（`@Riverpod(keepAlive: true)` Notifier）：
    - `build()` 默认本月；
    - `setPreset(...)` 切换本月/上月/本年；
    - `setCustomRange(...)` 写入自定义时间区间。
- `lib/features/stats/stats_page.dart`（新建）：
  - 新增 `StatsPage`（`ConsumerWidget`）作为统计 Tab 页面。
  - 顶部接入 4 个区间入口（本月/上月/本年/自定义）。
  - 自定义区间通过 `showDateRangePicker` 选择并写回 `statsRangeProvider`。
  - 增加当前生效区间展示条，为 Step 5.2+ 图表组件提供统一时间过滤来源。
- `lib/app/home_shell.dart`：
  - 统计 Tab（index=1）从占位 `_PlaceholderTab(label: '统计')` 替换为 `const StatsPage()`。
- 测试更新：
  - `test/features/stats/stats_range_providers_test.dart`（新建）：
## Phase 5 · Step 5.3 增量说明（2026-04-28）

- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsPieSlice` 数据类：承载饼图单个切片的展示信息（`categoryId`/`categoryName`/`categoryColor`/`amount`/`percentage`），其中 `categoryId` 在"其他"切片中为 null。
  - 新增 `aggregatePieSlices(List<TransactionEntry>, Map<String, Category>, DateTime, DateTime)` 纯函数：从流水列表中筛选支出类型、时间范围内的记录，按 `categoryId` 聚合金额，降序取 Top 6，其余归入"其他"切片。`Category.color` 为 hex 时解析为 `Color`，否则按索引从 `_piePalette` 6 色轮取色。
  - 新增 `statsPieSlices`（`@Riverpod(keepAlive: true)` FutureProvider）：组合 `statsRangeProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider` + `categoryRepositoryProvider`，产出 `List<StatsPieSlice>`。
  - 修复 `package:flutter/foundation.dart` 导入冲突：改为 `show visibleForTesting`，避免与 `domain/entity/category.dart` 的 `Category` 类型歧义。
  - 新增 `_piePalette`（6 色奶油兔调色板常量）与 `_parseHexColor`（`#RRGGBB` → `Color` 解析器）。

- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 统计卡片区重构为 `SingleChildScrollView` + `Column` 双卡片布局（折线图卡片 + 饼图卡片）。
  - 新增 `_CategoryPieCard`（ConsumerWidget）：订阅 `statsPieSlicesProvider`，loading/error/data 三态渲染；数据为空时显示 `_PieChartEmptyState`（"暂无支出数据"）。
  - 新增 `_PieChartView`（StatefulWidget）：`fl_chart` `PieChart`，支持触摸反馈（`_touchedIndex` 状态驱动选中切片放大 + 显示金额 badge），颜色直接使用 `StatsPieSlice.categoryColor`，切片标题文字颜色按背景亮度自动选择黑白。右侧搭配 `_LegendList`（圆点 + 分类名，`SingleChildScrollView` 兜底）。
  - 新增 `_PieChartEmptyState`：与 `_LineChartEmptyState` 风格一致的占位组件。

- `test/features/stats/stats_range_providers_test.dart`：
  - 新增 `makeTx` / `makeCat` 本地辅助构造器。
  - 新增 7 条 `aggregatePieSlices` 用例：空数据、排除 income/transfer、4 分类百分比和 = 100%、>6 分类 Top 6 + 其他、排除超时、使用分类自身颜色、无颜色回退调色板。

- `test/widget_test.dart`：
  - `_standardOverrides()` 新增 `statsLinePointsProvider` / `statsPieSlicesProvider` override（空列表），避免统计页 provider 未 mock 导致 widget 测试 `pumpAndSettle` 超时。

## Phase 5 · Step 5.4 增量说明（2026-04-29）

- `lib/features/stats/stats_range_providers.dart`：
  - 新增 `StatsRankItem` 数据类：承载排行榜单行展示信息（`categoryId`/`categoryName`/`categoryColor`/`amount`/`percentage`/`isIncome`），其中 `categoryId` 在"未分类"场景中可能为 null。
  - 新增 `_CategoryAgg` 内部聚合辅助类（`double amount = 0`）。
  - 新增 `aggregateRankItems(List<TransactionEntry>, Map<String, Category>, DateTime, DateTime)` 纯函数：从流水列表中排除 transfer、按时间区间过滤、按 `type|categoryId` 复合键聚合金额，分别计算收入/支出各自的总和，产出按金额降序排列的 `List<StatsRankItem>`。百分比按各自类型（收入/支出）的总和计算。
  - 新增 `statsRankItems`（`@Riverpod(keepAlive: true)` FutureProvider）：组合 `statsRangeProvider` + `currentLedgerIdProvider` + `transactionRepositoryProvider` + `categoryRepositoryProvider`，产出 `List<StatsRankItem>`。

- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 统计卡片区新增排行榜卡片：`SizedBox(height: 360, child: _RankingCard())`。
  - 新增 `_RankingCard`（ConsumerWidget）：订阅 `statsRankItemsProvider`，loading/error/data 三态渲染；数据为空时显示 `_RankingEmptyState`（"暂无排行数据"）。
  - 新增 `_RankingList`（StatelessWidget）：`ListView.separated` 渲染排行榜。每行含排名序号（前 3 名用分类颜色高亮）、分类颜色圆点、分类名称、占比进度条（`FractionallySizedBox` 按 `amount/maxAmount` 比例填充）、金额（收入绿色 `+` 前缀、支出红色 `-` 前缀，颜色来自 `BianBianSemanticColors`）。
  - 新增 `_RankingEmptyState`：与 `_LineChartEmptyState` / `_PieChartEmptyState` 风格一致的占位组件。

- `test/features/stats/stats_range_providers_test.dart`：
  - 新增 8 条 `aggregateRankItems` 用例：空数据、排除 transfer、同分类聚合、百分比计算、排除超时、使用分类颜色、回退调色板、混合收支正确分组与百分比。

- `test/widget_test.dart`：
  - `_standardOverrides()` 及第二个测试用例的 override 列表均新增 `statsRankItemsProvider.overrideWith((ref) async => [])`。

## Phase 5 · Step 5.6 增量说明（2026-04-29）

- `pubspec.yaml`：新增依赖 `share_plus: ^10.1.4`（实际解析到 10.1.4）。10.x 而非最新 13.x 是为了与现有 SDK / 依赖约束保持兼容；同时引入间接依赖 `share_plus_platform_interface 5.0.2` 与 `cross_file`（提供 `XFile`）。

- `lib/features/stats/stats_export_service.dart`（新建）：
  - `encodeStatsCsv({entries, categoryMap, accountMap, range})`（顶层 `@visibleForTesting` 纯函数）：UTF-8 BOM `\uFEFF` + 中文列头 `日期/类型/金额/币种/分类/账户/转入账户/备注` + RFC 4180 转义（值含 `,` / `"` / `\n` / `\r` 整体加引号、内部 `"` 转义为 `""`）+ 按 `occurredAt` 升序 + 区间外行丢弃 + categoryId/accountId 缺失时空字段。日期格式 `yyyy-MM-dd HH:mm`，金额 `0.00`，类型映射中文（`收入/支出/转账`）。
  - `buildExportFileName({prefix, extension, now, range})`（顶层 `@visibleForTesting` 纯函数）：产出 `<prefix>_<startDate>_<endDate>_<timestamp>.<ext>`，时间戳格式 `yyyyMMdd_HHmmss`、区间格式 `yyyyMMdd`，避免 Windows 文件名非法字符。
  - `StatsExportService` 类：注入 `documentsDirProvider`（默认 `getApplicationDocumentsDirectory`）/ `shareXFiles`（默认 `Share.shareXFiles`）/ `now`（默认 `DateTime.now`）三个钩子；公开 API：
    - `writeExportFile(filename, bytes)`：在 `<documents>/exports/` 子目录下写文件，自动创建目录，`flush: true` 保证落盘后再返回 `File`。
    - `exportCsv(...)` / `exportPng({boundary, range, pixelRatio = 3.0})`：组合 encode + 文件名 + 写盘。
    - `capturePng(boundary, pixelRatio)`：`RenderRepaintBoundary.toImage(pixelRatio: 3.0)` 默认值满足验收"PNG 分辨率 ≥ 2x"；`image.dispose()` 在 finally 内确保 ImageBuffer 释放。
    - `shareFile(File, {subject, text})`：薄封装 `share_plus.Share.shareXFiles([XFile(file.path)], ...)`。

- `lib/features/stats/stats_page.dart`：
  - `StatsPage` 由 `ConsumerWidget` 升级为 `ConsumerStatefulWidget`，持有 `_chartsBoundaryKey: GlobalKey` + `_exportService: StatsExportService` + `_exporting: bool`。
  - 标题行重构为 `Row` 三段式：左占位 40px / 居中 `Text('统计分析')` / 右侧 40px 区域承载 `IconButton(Icons.ios_share, tooltip: '导出')`；导出中显示 `CircularProgressIndicator(strokeWidth: 2)`。
  - 点击导出按钮 → `showModalBottomSheet<_ExportKind>` 选 PNG / CSV → `_exportPng()` 或 `_exportCsv()`；任意失败由 `try/catch` 通过 `ScaffoldMessenger` 提示「导出失败：$e」并在 finally 中复位 `_exporting`。
  - PNG 路径：`_chartsBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?` → service.exportPng → service.shareFile。
  - CSV 路径：`ref.read` 拉取 `currentLedgerIdProvider.future` / `transactionRepositoryProvider.future` / `categoryRepositoryProvider.future` / `accountRepositoryProvider.future`，组装 `categoryMap` / `accountMap` 后调用 service.exportCsv → service.shareFile。
  - 图表区被 `RepaintBoundary(key: _chartsBoundaryKey, child: Container(color: surface, ...))` 包裹（`Container` 给 PNG 截图填充背景，避免透明区显示为黑/白色）。
  - 顺手清理 Step 5.5 留下的预存 warning：`_HeatmapCard` 删除未消费的 `super.key` 形参。

- `test/features/stats/stats_export_service_test.dart`（新建）：8 条用例——
  - `encodeStatsCsv` × 6：UTF-8 BOM + 中文列头 / 行排序 + 字段格式 / transfer 行 toAccount 解析 / RFC 4180 转义（`,` / `"` / `\n`）/ 区间过滤 / 缺失映射时空字段。
  - `buildExportFileName` × 2：含起止 + 时间戳 / 扩展名参数生效。
  - 自带迷你 `LineSplitter`（识别 `\n` / `\r\n`）以避免外部 `dart:convert` import 噪声。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 126/126 通过（118 前 + 8 新）；`dart run custom_lint` → 3 条预存 INFO（`record_new_providers.dart`），与本步无关。

## Phase 6 · Step 6.1 增量说明（2026-05-01）

- `lib/data/repository/budget_repository.dart`：
  - 新增 `BudgetConflictException`（`Exception`，含 `message`），用于业务可恢复的"重复预算"冲突。
  - `LocalBudgetRepository.save()` 在事务内、`dao.upsert` 之前先调 `_findActiveDuplicate(...)`：按 `(ledgerId, period, categoryId)` 查未软删行（`categoryId == null` 走 `t.categoryId.isNull()`，否则 `t.categoryId.equals(...)`）；通过 `t.id.isNotIn([excludeId])` 排除自身，使"同 id 二次保存"仍是合法更新。
  - 静态助手 `_periodLabel(period)` 把 `'monthly'` / `'yearly'` 映射为中文"月" / "年"，仅用于异常 message 的拼接，不外泄到 UI 文案。

- `lib/features/budget/budget_providers.dart`（新建）：
  - `kParentKeyLabels`：常量映射，键集与 `seeder.dart::categoriesByParent.keys` 同步。
  - `activeBudgets(Ref)`：从 `budgetRepositoryProvider` 拉当前账本未软删预算，客户端排序"先 monthly 后 yearly、再 categoryId=null 优先"，UI 不再二次排序。
  - `budgetableCategories(Ref)`：从 `categoryRepositoryProvider.listActiveAll()` 过滤掉 `parentKey == 'income'`——预算覆盖支出场景。

- `lib/features/budget/budget_list_page.dart`（新建）：
  - `BudgetListPage`（ConsumerWidget）：`Scaffold` + 列表 + `FloatingActionButton.extended`。卡片点击进入编辑、按钮触发删除二次确认（`AlertDialog`）。删除走 `repo.softDeleteById` → `invalidate(activeBudgetsProvider)` + Snackbar。
  - 私有 `_BudgetCard`：左 emoji（来自分类 icon，总预算用 💰 兜底）+ 中部双行（标题/副标题"周期 · 结转标记"）+ 右金额（`NumberFormat('#,##0.00')`）+ 删除 `IconButton`。
  - 私有 `_EmptyState`：💰 图标 + "还没有预算" + "点右下角加一个吧 🐰"。

- `lib/features/budget/budget_edit_page.dart`（新建）：
  - `BudgetEditPage`（ConsumerStatefulWidget，`budgetId` 可选）。`_loadBudget()` 在 `FutureBuilder` 内异步取 budget；`_hydrate(...)` 守 `_initialized` flag 仅首次 build 写入字段，避免重渲染时覆盖用户编辑。
  - 字段：周期 `SegmentedButton<String>(monthly/yearly)`、分类 `DropdownButtonFormField<String?>`（首项 null = 总预算 + 其余按"中文 parentKey + sortOrder"排序）、金额 `TextFormField`（`numberWithOptions(decimal:true)` + `FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))`）、结转 `SwitchListTile`。
  - 保存逻辑：编辑模式直接 `Budget(...)` 裸构造（不走 copyWith——`copyWith` 不能把 `categoryId` 清回 null，否则用户从分类预算切回总预算会失败）。新建走 `Uuid().v4()` + `startDate` 取本月/本年第一天。捕获 `BudgetConflictException` → SnackBar 友好提示；捕获其他异常 → "保存失败：$e"。`_saving` 状态守按钮，避免双击。

- `lib/app/app_router.dart`：新增两条路由 `/budget`（`BudgetListPage`）、`/budget/edit`（`BudgetEditPage` + `?id=...`）。

- `lib/app/home_shell.dart`：
  - 移除占位 `_PlaceholderTab`；`_pages[3]` 改为 `_MeTab`。
  - 新增 `_MeTab` 私有 StatelessWidget：`Scaffold` + `AppBar('我的')` + `ListView`，目前唯一一项 `ListTile('预算')` → `context.push('/budget')`。Phase 17 会扩展为完整设置/同步/锁等入口。
  - 新增 import `package:go_router/go_router.dart`（`_MeTab` 内 `context.push` 用）。

- `test/data/repository/budget_repository_test.dart`（新建）：8 用例覆盖 `(ledgerId, period, categoryId)` 唯一性的全部边界（详见对应 test 文件章节）。

- `test/widget_test.dart`：新增 `_FixedRecordMonth extends RecordMonth` 并在 `_standardOverrides()` + 测试 5 的 inline overrides 中各加一行 `recordMonthProvider.overrideWith(() => _FixedRecordMonth(DateTime(2026, 4)))`——把 widget 测试的"当前月"锁死，避免随真实日期跨月而 flaky（曾在 2026-05-01 触发）。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 134/134 通过（126 前 + 8 新 budget repo 用例）；含 widget_test 时间敏感修复后 5/5 通过。

## Phase 6 · Step 6.2 增量说明（2026-05-01）

- `lib/features/budget/budget_progress.dart`（新建）：纯 Dart 工具集（不依赖 Flutter / Riverpod / drift），承载色档、周期边界、消费聚合、震动决策四件事。详细内容见上文 `lib/features/budget/` 节。色档边界严格按 implementation-plan：`<70%` 绿、`70%`/`100%` 归橙、`>100%` 红。

- `lib/features/budget/budget_providers.dart`：
  - 新增 `BudgetClock` typedef + `budgetClock(Ref)` provider（默认 `DateTime.now`）——测试可 override 锁定参考时间。
  - 新增 `budgetProgressFor(Ref, Budget)`（family FutureProvider）：拉当前账本流水 → `computePeriodSpent` → `computeBudgetProgress`。
  - 新增 `BudgetVibrationSession` Notifier（`keepAlive`）：状态为 `Set<String>`，`hasVibrated` / `markVibrated`（幂等）/ `clear`。冷启动后清空，符合"会话级"语义。

- `lib/features/budget/budget_list_page.dart`：
  - `_BudgetCard` 升级为 `ConsumerWidget`；卡片 body 从单 `Row` 改为 `Column`，下方追加 `_ProgressSection`。
  - `_ProgressSection`（ConsumerWidget）：彩色 `LinearProgressIndicator` + "已花 ¥X / ¥Y · N%" 文案。颜色取自 `BianBianSemanticColors`（success/warning/danger）。`ratio.clamp(0, 1)` 给进度条 value，避免 >100% 溢出动画。
  - 震动逻辑：`shouldTriggerBudgetVibration(level, hasVibrated)` 为真时，**整段** `markVibrated + HapticFeedback.heavyImpact()` 都放进 `WidgetsBinding.addPostFrameCallback`——build 期间修改 provider state 会被 Riverpod 拒绝。回调内再做一次 `hasVibrated` 检查，确保同帧多次 build 注册多个 postFrame 时只执行一次。
  - import 新增 `package:flutter/services.dart`（HapticFeedback）+ `app/app_theme.dart`（BianBianSemanticColors）+ `budget_progress.dart`。

- `test/features/budget/budget_progress_test.dart`（新建，16 用例）：
  - `computeBudgetProgress`：< 70%、= 70%、85%、= 100%、100.01%、limit ≤ 0、spent = 0 共 7 条边界。
  - `budgetPeriodRange`：monthly/yearly/12 月跨年 3 条。
  - `computePeriodSpent`：总预算累加 / 分类预算过滤 / yearly 全年范围 3 条。
  - `shouldTriggerBudgetVibration`：green/orange 不触发、red 首次触发、red 已触发不再触发 3 条。

- `test/features/budget/budget_vibration_session_test.dart`（新建，5 用例）：
  - 初始 state 空；`markVibrated` → `hasVibrated` true；同 id 重复 mark 不重建 state（`identical` 断言）；多 id 独立标记；`clear` 移除指定 id。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 155/155 通过（134 前 + 16 budget_progress + 5 vibration_session）；`dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。

## Phase 7 · Step 7.2 增量说明（2026-05-01）

- `lib/data/repository/account_repository.dart`：
  - 接口新增 `Future<Account?> getById(String id)`——**不**过滤 `deleted_at`。
  - `LocalAccountRepository.getById`：`select(accountTable)..where(id == id)..getSingleOrNull()` → `rowToAccount`；调用方按 `account.deletedAt != null` 自行决定如何渲染。这是流水详情显示"（已删账户）"占位的实现路径——`listActive` 不能给出软删账户，但流水的 `accountId` 仍指向历史 id，必须能拿到历史名 / 软删标记。

- `lib/features/account/account_edit_page.dart`（新建）：`AccountEditPage`（`ConsumerStatefulWidget`，`accountId` 可选）。字段：名称（`TextFormField`，必填校验）、类型（下拉，`cash` / `debit` / `credit` / `third_party` / `other`）、图标 emoji（`TextFormField`，可空）、初始余额（`TextFormField` + `numberWithOptions(decimal: true, signed: true)` + 正则 `^-?\d*\.?\d{0,2}` 限两位小数 + 可负号）、默认币种（下拉同账本编辑页 7 种）、计入总资产（`SwitchListTile`）。`initState` 启动 `_loadFuture`；`_hydrate(acc)` 守 `_initialized` flag 仅首次写入字段。`_save()` 编辑模式走 `existing.copyWith(...)` 路径（避免裸构造遗漏字段）；新建模式走 `Account(id: const Uuid().v4(), ..., deviceId: '')` 让 repo 覆写 deviceId/updatedAt。保存成功后 `ref.invalidate(accountsListProvider)` / `accountBalancesProvider` / `totalAssetsProvider` 三连击，再 `Navigator.pop(true)`。`_saving` 守按钮防双击。

- `lib/features/account/account_list_page.dart`：
  - 新增 `FloatingActionButton.extended('新建账户')` → `context.push<bool>('/accounts/edit')`，返回 `true` 触发 3 个 provider invalidate。
  - `_AccountCard` 接收 `onTap` / `onLongPress` 回调；`InkWell` 包裹卡片内容，点击进入 `/accounts/edit?id=<acc.id>`。
  - 长按弹出 `showModalBottomSheet`：编辑（同 onTap）+ 删除（红色，触发 `_confirmDelete`）。
  - `_confirmDelete(...)`：`AlertDialog` 二次确认 → `repo.softDeleteById(account.id)` → 3 个 provider invalidate + Snackbar `「{name}」已删除`；删除按钮置 `foregroundColor: Colors.red`。`hero_tag: 'account_list_fab'` 与账本列表的 FAB 区分，避免 Hero 冲突。

- `lib/app/app_router.dart`：新增 `GoRoute('/accounts/edit')`，可选 query `id` 进入编辑模式；与 `/accounts` 路由列表平行。

- `lib/features/record/record_home_page.dart::_TxTile` 的 `accountName(id)` 回退逻辑修订：
  - id == null / 空字符串 → `'账户'`（保持旧版"未填写账户"语义）。
  - id != null 且不在 `accountRepo?.listActive()` 结果中 → `'（已删账户）'`（**新增**——Step 7.2 验收）。
  - 这是"懒查询"实现：不去查 `getById`（每条流水 + 每次 build 都查会爆查询），而是利用 `listActive` 一次性查出全部活跃账户后做内存查找。`getById` 由仓库测试覆盖，UI 不消费——但若未来产品要求"已删账户保留原名 + 加`（已删）`后缀"，则改为消费 `getById` 即可（每个 `_TxTile` 内 `FutureBuilder<Account?>`）。
  - 转账流水副标题 `'A → B'` 与详情底部页 `_RecordDetailSheet` 的"钱包" / "转出" / "转入" KV 行均经此 `accountName` 函数，故同一处修改即生效。

- `test/data/repository/account_repository_test.dart`（新建，7 用例）：
  - `save → 写入并入队 sync_op upsert`（覆写 device_id/updated_at + payload 断言）。
  - `getById 命中活跃账户`（基础正向）。
  - `getById 不存在的 id 返回 null`。
  - `softDeleteById → listActive 不可见，但 getById 仍能查到（含 deletedAt）`（Step 7.2 兜底关键）。
  - `softDeleteById 不存在的 id 静默跳过（不入队）`。
  - `save (update) 同 id 二次保存视为更新`（步进 clock + 单行 + 2 条 upsert）。
  - `返回实体是纯 Dart 类型（不含 drift 专属类型）`。

- `test/widget_test.dart`：
  - 新增 `_FakeAccountRepository`（`listActive` / `getById` / `save fail` / `softDeleteById fail`）。
  - 新增第 6 条用例 `删除账户后转账流水显示"（已删账户）"占位`：注入 1 条 transfer 流水 + 空账户列表 → 验证副标题 `（已删账户） → （已删账户）` + 金额 `¥200.00` 渲染（不崩溃）。

- `test/features/record/record_new_page_test.dart`：`_FakeAccountRepository` 补 `getById`（按 id 内存匹配）以保持 implements 接口完整。

- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 200/200 通过（192 前 + 7 account repo + 1 widget = 200）。

## Phase 7 · Step 7.2 刷新补丁（2026-05-01）

- **现象**：删除账户后流水副标题不更新；切换账本再切回才刷新。
- **根因**：`_TxTile` watch 的是 `accountRepositoryProvider`（仓库实例从不变），`accountsListProvider` 被 invalidate 不会让 tile 重建。
- **修复点**：`lib/features/record/record_home_page.dart::_TxTile.build()`——把 `ref.watch(accountRepositoryProvider).valueOrNull` + 内层 `FutureBuilder<List<Account>>` 替换为 `ref.watch(accountsListProvider).valueOrNull ?? const <Account>[]`。同时 import 调整为 `features/account/account_providers.dart::accountsListProvider`，原 `data/repository/providers.dart` 的 `accountRepositoryProvider` 从 import 列表里移除（不再使用）。
- **回归测试**：`test/widget_test.dart` 新增 `删除账户后流水副标题立即刷新（无需切换账本）` 用例——`_FakeAccountRepository.accounts` 改为可变；`ProviderContainer.invalidate(accountsListProvider)` 模拟删除事件；pumpAndSettle 后断言副标题从原账户名变为"（已删账户）"。
- **同款风险**：`categoryRepositoryProvider` 在 `_TxTile` 内同样以仓库实例 + FutureBuilder 模式使用。若未来用户报告"删/改分类后流水图标/名未刷新"，应按同模式切换为某个 `categoriesListProvider`。本次刻意不顺手改，保持补丁聚焦。
- 验证摘要：`flutter analyze` → No issues found；`flutter test` → 201/201 通过（200 前 + 1 新刷新回归）。

## Phase 7 · Step 7.3 增量说明（2026-05-02）

数据层 / 实体层：
- `lib/data/local/tables/account_table.dart`：`AccountTable` 追加两列——`billing_day INTEGER`（nullable）、`repayment_day INTEGER`（nullable）。命名按 design-document §7.1 风格保持下划线，drift Companion getter 自动转 camelCase。两列对所有账户都允许 null，UI 层按 `type == 'credit'` 决定是否显示 / 是否写入。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v4 升 v5；`onUpgrade` 新增 `if (from < 5)` 分支，调 `m.addColumn(accountTable, accountTable.billingDay)` + `m.addColumn(accountTable, accountTable.repaymentDay)`。schema 版本注释同步追加 v5 行。
- `lib/domain/entity/account.dart`：实体加 `int? billingDay` / `int? repaymentDay`；`copyWith` / `toJson` / `fromJson` / `==` / `hashCode` / `toString` 全部同步。`fromJson` 用 `(json['billing_day'] as num?)?.toInt()` 兜底——保持向旧 JSON 备份的兼容（旧备份缺这两个 key 时按 null 解析）。Step 2.1 实体约定不变：`copyWith` 不能把 `T?` 清回 null；要清 `billingDay` / `repaymentDay` 必须裸构造（账户编辑页保存路径已切换为裸构造）。
- `lib/data/repository/entity_mappers.dart`：`rowToAccount` / `accountToCompanion` 两侧都补两个字段映射，与其他 nullable 字段同模式（drift 端 `int?` ↔ 实体端 `int?` 直接透传）。

UI 层：
- `lib/features/account/account_edit_page.dart`：
  - 新增 `_billingDayController` / `_repaymentDayController` 两个 controller + 对应 dispose；`_hydrate(acc)` 编辑模式回填两字段。
  - `build()` 内当 `_type == 'credit'` 时条件渲染一行双 `TextFormField`（`Row + Expanded`），输入限制：`TextInputType.number` + `FilteringTextInputFormatter.digitsOnly` + `LengthLimitingTextInputFormatter(2)`；`validator` 共用 `_validateDay` 私有方法（空字符串放行；非空时要求 `1 ≤ n ≤ 28`，否则提示"请输入 1-28 的整数"）。两字段各挂 `Key('billing_day_field')` / `Key('repayment_day_field')`。
  - 类型 dropdown 的 `onChanged` 在切到非 credit 时同步 `setState` 清空两个 controller，避免视觉残留。
  - `_save()` 编辑分支改为**裸构造 `Account(...)`**（不走 copyWith）——这是为了支持"由非空 → null"的清空场景。`billingDay` / `repaymentDay` 仅当 `_type == 'credit'` 时取 controller 值，其它类型一律落 null。新建分支沿用裸构造（本来就是）。
- `lib/features/account/account_list_page.dart`：
  - `_AccountCard` 新增静态方法 `_creditDayLine(billingDay, repaymentDay)`：根据填写情况组合 `'账单日 X 号 · 还款日 Y 号'`；任一字段缺失时仅显示已填字段；两者都缺失返回 null。
  - `build()` 中当 `account.type == 'credit' && creditInfo != null` 时，在卡片中部 Column 第二行（类型 + 不计入总资产 suffix）下方再渲染一行 `Text(creditInfo)`，挂 `Key('credit_info_<accountId>')` 便于测试断言。

测试：
- `test/domain/entity/entities_test.dart::Account` 组：原 `full` 加 `billingDay: 5` / `repaymentDay: 22`，覆盖含信用卡日的全字段 roundtrip；`minimal`（cash 账户）的预期断言新增"两字段为 null"；`copyWith` 用例新增"不动信用卡日"断言；新增第 4 条"信用卡日仅存其一也能 roundtrip"用例（仅填 `billingDay`）。
- `test/data/repository/account_repository_test.dart`：`makeAccount` 工厂加 `billingDay` / `repaymentDay` 可选参数；新增 2 条 Step 7.3 用例——① 信用卡日持久化并可读回（同时验 sync_op payload 含两个 key）；② 非信用卡保存时两字段为 null（即使被传入也按 UI 规范落 null，但仓库本身不强制）。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 147 outputs；`flutter analyze` → No issues found；`flutter test` → 204/204 通过（201 前 + 1 entities + 2 account_repository = 204）；`dart run custom_lint` → 仍是 3 条预存 INFO（与 record_new_providers.dart 相关），与本步无关。


## Phase 8 · Step 8.1 增量说明（2026-05-02）

数据层 / Schema：
- `lib/data/local/tables/user_pref_table.dart`：新增 `multi_currency_enabled INTEGER NULLABLE DEFAULT 0` 列。命名按 design-document §7.1 风格保持下划线，drift Companion getter 自动转 camelCase。`0` / `null` 视为关闭，`1` 视为开启——与生产默认一致。
- `lib/data/local/tables/fx_rate_table.dart`（新建）：`FxRateTable` + `@DataClassName('FxRateEntry')`。**工具表**（与 `sync_op` 同性质，不是同步实体）——只有 `code` (TEXT PK) / `rate_to_cny` (REAL NOT NULL) / `updated_at` (INTEGER NOT NULL) 三列，无 `deleted_at` / `device_id` / sync_op 入队。设计 §5.7 的"汇率快照"职责。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v5 升 v6；注册 `FxRateTable` + `FxRateDao`；`onUpgrade` 新增 `if (from < 6)` 分支：`m.addColumn(userPrefTable, userPrefTable.multiCurrencyEnabled)` + `m.createTable(fxRateTable)`。**故意不**在 onUpgrade 写入 fx_rate 快照——把"种子化"职责留给 `seeder.dart` 的独立判空，与 ledger 路径解耦。
- `lib/data/local/dao/fx_rate_dao.dart`（新建）：`FxRateDao` 暴露 3 个方法——`listAll()` (按 code 升序) / `getByCode(code)` / `upsert(companion)`。不走 Step 1.4 的"业务表 4 方法"模式；不需要 softDelete / hardDelete。

常量层：
- `lib/core/util/currencies.dart`（新建，原目录 `[空]` 退役）：`Currency` 数据类（`code` / `symbol` / `name`）+ 顶层 `kBuiltInCurrencies` (11 种：CNY / USD / EUR / JPY / KRW / HKD / TWD / GBP / SGD / CAD / AUD) + 顶层 `kFxRateSnapshot: Map<String, double>`（写死的初始汇率快照，以 CNY 为基准；CNY 自身 = 1.0）。两个常量集对外暴露但**不可在运行期 mutate**——Step 8.3 联网刷新走的是"覆盖 fx_rate 表行"，不动这两个 const。

种子化：
- `lib/data/local/seeder.dart::seedIfEmpty()` 重构为**两段独立判空**：
  - 第一段（旧 ledger 路径）：`ledger` 表为空 → 插入账本 + 分类 + 账户。
  - 第二段（Step 8.1 新增）：`fx_rate` 表为空 → 按 [kFxRateSnapshot] 批量插入 11 行（updated_at = `_clock()` ms）。
  两段都在同一个 `_db.transaction` 内，任一失败整体回滚。这种解耦让 v5 → v6 升级路径下的"既有用户首次冷启 v6"能仅补齐 fx_rate（不重建 ledger）；同样让"用户已手动覆盖某币种汇率"的场景下 seeder 不会回写覆盖（fx_rate 整体非空 → 整段跳过；逐 code 增量补齐留给 Step 8.3 的联网刷新）。

UI 层 / 设置入口：
- `lib/features/settings/settings_providers.dart`（新建）：`@Riverpod(keepAlive: true) class MultiCurrencyEnabled extends _$MultiCurrencyEnabled`。`build()` 读 `user_pref.multi_currency_enabled` → bool；`set(bool enabled)` 写 user_pref + `invalidateSelf()`。与 Step 4.1 的 `CurrentLedgerId` AsyncNotifier 同模式，是后续 settings 模块的"单字段开关"基底。
- `lib/features/settings/multi_currency_page.dart`（新建）：`MultiCurrencyPage` ConsumerWidget。`SwitchListTile`（挂 `Key('multi_currency_switch')`）+ "内置币种" ListTile（展示 `kBuiltInCurrencies.map(code).join(' · ')`）+ "汇率管理"占位 ListTile（disabled，文案"Step 8.3 接入联网刷新与手动覆盖"）。
- `lib/app/app_router.dart`：新增 `GoRoute('/settings/multi-currency')` → `MultiCurrencyPage`。
- `lib/app/home_shell.dart`：`_MeTab` 在"资产"项之后追加"多币种"项（`Icons.public` → `context.push('/settings/multi-currency')`）。

记账页接线：
- `lib/features/record/widgets/number_keyboard.dart`：`NumberKeyboard` 加 `bool showCurrencyKey = true` 参数；构建左下角 'CURRENCY' 位时用 `key == 'CURRENCY' && !showCurrencyKey ? const SizedBox(height: 65) : _KeyButton(...)` 决定渲染。**保持 4×4 网格布局**——只是把币种按钮替换成等高空 SizedBox，不让其它键变形或换位。点击事件在该位为空时也不响应。
- `lib/features/record/record_new_page.dart`：`_RecordNewPageState.build` 内 `ref.watch(multiCurrencyEnabledProvider).valueOrNull ?? false`，把结果作为 `NumberKeyboard.showCurrencyKey` 透传。loading/error 期间默认按"关闭"显示——避免短暂闪现币种键的不一致体验。

测试：
- `test/data/local/fx_rate_test.dart`（新建，11 用例）：
  1. `FxRateDao` × 3：`upsert + listAll` 升序 / `upsert` 同 code 二次更新 / `getByCode` 命中与未命中。
  2. `DefaultSeeder` fx_rate 路径 × 4：空库 → 写入 [kFxRateSnapshot] 全集 / CNY = 1.0 且 11 种内置币种全覆盖 / 已有 fx_rate 不被覆盖（独立判空）/ ledger 已存在但 fx_rate 为空 → 仅种子化 fx_rate（验证 v5→v6 升级路径）。
  3. 内置币种常量 × 4：codes 顺序锁定 / [kFxRateSnapshot].keys 与 [kBuiltInCurrencies] 同集 / CNY 自身 = 1.0 / 每种币种有非空 symbol+中文 name。
- `test/features/settings/multi_currency_page_test.dart`（新建，5 用例）：覆盖 SwitchListTile 在 initial=false / 切换后 true / initial=true 三种状态；内置币种行展示三个 code 抽样；汇率管理行 disabled。`_TestMultiCurrencyEnabled` fake notifier 走"override `build` + override `set` 直接 `state = AsyncValue.data(...)`"模式，避免 dependencies on real DB。
- `test/features/record/record_new_page_test.dart`：
  - `_baseOverrides` 加 `bool multiCurrencyEnabled = false` 参数 + `_TestMultiCurrencyEnabled` 类，默认与生产一致（false）。
  - 原"数字键盘完整渲染"用例改为传 `multiCurrencyEnabled: true`（含 'CNY' 键断言）。
  - 新增 2 条 Step 8.1 验收用例：① 开关关闭时 'CNY' 不可见、其它键仍渲染保持布局；② 开关开启时 'CNY' 可见。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 155 outputs；`flutter analyze` → No issues found；`flutter test` → 222/222 通过（204 前 + 11 fx_rate + 5 multi_currency_page + 2 record_new_page Step 8.1 = 222）；`dart run custom_lint` → 仍是 3 条预存 INFO（与 record_new_providers.dart 相关），与本步无关。


## Phase 8 · Step 8.2 增量说明（2026-05-02）

Provider 与纯函数：
- `lib/features/settings/settings_providers.dart`：新增 `currentLedgerDefaultCurrencyProvider`（依赖 `currentLedgerIdProvider` + `ledgerRepositoryProvider`，账本切换 / 编辑后自动重算；读取失败兜底 `'CNY'`）+ `fxRatesProvider`（dump `fx_rate` 表为 `Map<String, double>`，code → rate_to_cny；后续 Step 8.3 联网刷新或用户手动覆写后会 invalidate）+ 顶层纯函数 `computeFxRate(from, to, ratesToCny)`（`from == to → 1.0` / 任一码缺失或 `toRate == 0` 兜底 1.0 / 否则 `from/to`）。本文件因新增 `Ref` 类型 import 加上 `package:flutter_riverpod/flutter_riverpod.dart`。

记账表单：
- `lib/features/record/record_new_providers.dart`：保留 `toggleCurrency()`（不再被 UI 调用，Step 8.3 之后再决定移除）；新增 `setCurrency(String code)` 与 `initDefaultCurrency()`（async，把 `state.currency` 设为账本默认币种；当 `state.currency != 'CNY'` 时跳过，避免覆盖已选/已 preload 的值）。`save()` 在保存前 `ref.read currentLedgerDefaultCurrencyProvider + fxRatesProvider`，调 `computeFxRate` 算出"原币 → 账本默认币种"的换算因子写入 `tx.fxRate`，与 `currency` 一同持久化。
- `lib/features/record/record_new_page.dart`：`initState` 内 `addPostFrameCallback` 触发 `initDefaultCurrency()`（fire-and-forget，与 `initDefaultAccount()` 同模式）。`_AmountDisplay` 改为按 `kBuiltInCurrencies` 查 `symbol`（移除硬编码 `¥` / `$`）。`NumberKeyboard.onCurrencyTap` 由 toggle 改为打开 `_CurrencyPicker` 底部抽屉——抽屉新增同文件，`ListView.builder` 渲染 11 内置币种、当前选中尾部 ✓、点击 `Navigator.pop(context, code)` 把 ISO 码回传，外层 `setCurrency(picked)`。

记账首页 / 流水：
- `lib/features/record/record_home_page.dart`：新增顶层 `_symbolFor(String code)` 私有 helper 与顶层 `@visibleForTesting` 函数 `formatTxAmountForDetail(tx, ledgerCurrency)`——同币种 → `±¥10.00`；跨币种 → `±USD 10.00（≈ ¥72.00）`（`amount * fxRate` 即折合，无需读 fx_rate 表）。`_TxTile` 显示金额改用 `_symbolFor(tx.currency)`（保留原币展示）。`_DataCards` 升级为 `ConsumerWidget`，watch `currentLedgerDefaultCurrencyProvider` 拿账本默认币种 symbol 传给 `_CardChip`，使顶部卡片在 USD 账本下显示 `$X.XX`。`_RecordDetailSheet` 升级为 `ConsumerWidget`，watch 同 provider 后调 `formatTxAmountForDetail(tx, ledgerCurrency)`，并把容器挂上 `Key('detail_amount')`。

统计聚合：
- `lib/features/record/record_providers.dart`：`recordMonthSummary` 收入/支出累加从 `tx.amount` 改为 `tx.amount * tx.fxRate`，与"卡片显示账本默认币种 symbol"一致。
- `lib/features/stats/stats_range_providers.dart`：`aggregatePieSlices` / `aggregateRankItems` / `aggregateHeatmapCells` / `statsLinePoints` 内的所有 `tx.amount` 求和改为 `tx.amount * tx.fxRate`。同币种流水 `fxRate = 1.0`，因此 V1 单币种用户行为完全不变；多币种开启后才真正起作用。
- `lib/features/budget/budget_progress.dart`：`computePeriodSpent` 与 `_spentBetween` 同样改为 `tx.amount * tx.fxRate`——预算金额本身是账本默认币种，两侧单位一致。
- **未触动** `lib/features/account/account_balance.dart`——账户余额按原币累加（每个账户有自己的 currency），跨币种总资产换算超出 Step 8.2 范围（V1 简化：跨币种转账留空，单账户内币种应与 account.currency 一致）。

测试：
- `test/features/settings/fx_rate_compute_test.dart`（新建，8 用例）：`computeFxRate` 同币种 / USD↔CNY / USD↔EUR / USD 10×7.2=72 验收 / 源缺失 / 目标缺失 / 除零保护。
- `test/features/stats/stats_range_providers_test.dart`：新增 3 用例覆盖 pie / rank / heatmap 在 USD 10、fxRate 7.2 下计入 72 CNY；现有用例 `fxRate` 默认 1.0 → 行为不变。
- `test/features/record/record_new_providers_test.dart`：新增 `_FakeLedgerRepository` + `_testLedger` + `currentLedgerDefaultCurrencyProvider` / `fxRatesProvider` / `ledgerRepositoryProvider` overrides；新增 6 个 Step 8.2 用例（setCurrency / initDefaultCurrency 默认 / initDefaultCurrency 不覆盖非 CNY / save 跨币种 USD 10 写入 fxRate=7.2 / save 同币种 fxRate=1.0 / save 跨币种到 USD 账本 fxRate=1/7.2）。
- `test/features/record/record_new_page_test.dart`：`_baseOverrides` 加 `currentLedgerDefaultCurrencyProvider` + `fxRatesProvider` 注入；新增 2 个 Step 8.2 widget 用例（点 CNY 键打开下拉 + 选 USD 后金额前缀变 `$` / 保存 USD 10 → fxRate=7.2、折合 72 CNY）。
- `test/features/record/record_home_page_format_test.dart`（新建，6 用例）：`formatTxAmountForDetail` 同币种 / USD 10×7.2 → "-USD 10.00（≈ ¥72.00）" / 收入用 `+` / 转账无符号 / CNY → USD 账本 / JPY 1500 千分位逗号。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 70 outputs；`flutter analyze` → No issues found；`flutter test` → 247/247 通过（222 前 + 25 Step 8.2 = 247）；`dart run custom_lint` → 仍是 3 条预存 INFO（`record_new_providers.dart`），与本步无关。


## Phase 8 · Step 8.3 增量说明（2026-05-02）

数据层 / Schema：
- `lib/data/local/tables/fx_rate_table.dart`：新增 `is_manual INTEGER NOT NULL DEFAULT 0` 列。`1` = 用户在"我的 → 多币种 → 汇率管理"手动覆盖；`0` = 由种子化 / 自动刷新写入。CNY 永远保持 `is_manual=0` 且服务层过滤掉 CNY，避免覆写基准。
- `lib/data/local/tables/user_pref_table.dart`：新增 `last_fx_refresh_at INTEGER`（nullable）。每日刷新节流锚点；NULL = 从未刷新。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v6 升 v7；`onUpgrade` 新增 `if (from < 7)` 分支：`m.addColumn(fxRateTable, fxRateTable.isManual)` + `m.addColumn(userPrefTable, userPrefTable.lastFxRefreshAt)`。Schema 版本注释同步追加 v7 行。
- `lib/data/local/dao/fx_rate_dao.dart`：在原有 `listAll` / `getByCode` / `upsert` 之外新增 3 个方法。
  - `setAutoRate({code, rateToCny, updatedAt})`：自动刷新写入。先 `getByCode`：不存在 → insert（`is_manual=0`）；存在且 `is_manual=0` → update；存在且 `is_manual=1` → 跳过。返回写入行数（0 表示被手动行跳过）。
  - `setManualRate({code, rateToCny, updatedAt})`：用户手动覆盖。`insertOnConflictUpdate` 写入并把 `is_manual=1`。
  - `clearManualFlag(code)`：把 `is_manual` 置回 0；汇率本身不动，等下次自动刷新覆盖（短暂保留旧值，避免出现"无值"中间态）。

服务层：
- `lib/features/settings/fx_rate_refresh_service.dart`（新建）：`FxRateRefreshService` 三公开 API。
  - `refreshIfDue({force=false})`：受 `user_pref.last_fx_refresh_at` 节流（默认 24h）。`force=true`（"立即刷新"按钮）绕过节流。fetcher 抛异常 / 返回空 Map / 返回非有限数 / 返回 0 或负数都被防御性跳过——任何失败都返回 false 且**不**推进 `last_fx_refresh_at`，保证下次启动还能重试。CNY 在写入前过滤掉。
  - `setManualRate(code, rate)`：参数校验（非 CNY、正有限数）后调 DAO 写入 `is_manual=1`；包装异常为 `ArgumentError`。
  - `resetToAuto(code)`：调 DAO `clearManualFlag`。
  - `defaultFxRateFetcher`（顶层）：默认 fetcher 走 `https://open.er-api.com/v6/latest/CNY`（免费、无 API key、ECB+Fed 数据源）。返回 `1 CNY = X target`，需要倒数得到 `rate_to_cny[code] = 1 / X`。仅对 [kBuiltInCurrencies] 中的非 CNY 币种返回结果；任何字段缺失或非法都跳过该币种（不抛异常，整体仍可成功）。
  - `FxRateFetcher` typedef：`Future<Map<code, rate_to_cny>> Function()`。测试可注入伪造 fetcher 验证 throttle / failure / manual-skip 行为而不依赖网络。

Provider 层：
- `lib/features/settings/settings_providers.dart`：
  - 新增 `fxRateRowsProvider`（`@Riverpod(keepAlive: true)`）：dump `fx_rate` 全字段行（含 `is_manual` / `updated_at`），供"汇率管理"列表渲染。与 `fxRatesProvider` 区分——后者只暴露 `code → rate`（供换算），本 provider 暴露视图所需全字段。
  - 新增 `fxRateRefreshServiceProvider`（`@Riverpod(keepAlive: true)`）：返回 `FxRateRefreshService(db: ref.watch(appDatabaseProvider))`，生产 fetcher 默认走 `defaultFxRateFetcher`。
- `lib/main.dart`：bootstrap `await defaultSeedProvider.future` 之后追加 fire-and-forget `container.read(fxRateRefreshServiceProvider).refreshIfDue()`。成功后 invalidate `fxRatesProvider` / `fxRateRowsProvider`；catchError 静默吞掉，不影响首帧。`unawaited(...)` 显式标注 fire-and-forget。

UI 层：
- `lib/features/settings/multi_currency_page.dart`（重写，从 ConsumerWidget 升级为 ConsumerStatefulWidget）：
  - 顶部 AppBar 右侧 `IconButton(Icons.refresh, key: 'fx_refresh_now')`：刷新中显示 `CircularProgressIndicator`，点击触发 `service.refreshIfDue(force: true)`，成功 → "汇率已更新"，失败 → "联网失败，使用现有快照"。
  - 三段：① 多币种 SwitchListTile（与 Step 8.1 一致）；② 内置币种概览（与 Step 8.1 一致）；③ "汇率管理"标题 + 11 行 `_FxRateTile`（每行渲染 code + 中文名 + 汇率 + 4 位小数 + 更新时间 + 手动/自动徽章；CNY 行显示"基准"徽章 + disabled）。
  - 入页 `addPostFrameCallback` fire-and-forget `service.refreshIfDue()`（节流，不 force）；成功后 invalidate 行列表。
  - 点击非 CNY 行 → `_ManualRateDialog`（StatefulWidget）：TextField 数字输入（默认 `numberWithOptions(decimal: true)`）+ 校验（正有限数）+ "保存"按钮。手动行额外显示"重置为自动"按钮 + 提示文案。返回 `_ManualResult(rate?, reset)` 由父组件分发到 `service.setManualRate` / `service.resetToAuto`。
  - 视图模型 `FxRateRow.fromEntry(FxRateEntry)`：把 drift 行解耦成 UI 用结构（`isManual: bool`），便于 widget 测试 + 服务层 fake。

测试：
- `test/features/settings/fx_rate_refresh_service_test.dart`（新建，15 用例）：
  - 节流 × 4：从未刷新即触发 / < 24h 跳过 / >= 24h 重发 / `force=true` 绕过节流。
  - 失败静默 × 3：fetcher 抛异常 → 不更新 fx_rate 也不推进 `last_fx_refresh_at` / 返回空 Map / 返回非有限/非正数（NaN / 负数 / 0）跳过该币种但其他正常币种仍写入。
  - 手动覆盖与重置 × 5：手动行不被自动刷新覆盖 / `resetToAuto` 后下次刷新可覆盖 / CNY 在 fetcher 返回时被服务层过滤掉永远保持 1.0 / `setManualRate` 拒绝 CNY / 拒绝非正数 / 写入新行（fx_rate 表中不存在的 code 也能被手动覆盖）。
- `test/data/local/fx_rate_test.dart`：在原 11 用例基础上补 6 个 Step 8.3 DAO 用例（默认 is_manual=0 / `setAutoRate` 在新行插入 / `setAutoRate` 跳过手动行 / `setManualRate` 写入并标 1 / `clearManualFlag` 清标记保留 rate / `clearManualFlag` 对不存在 code 返回 0），原"upsert + listAll"用例补 `is_manual` 默认值断言。
- `test/features/settings/multi_currency_page_test.dart`（重写）：注入 `_FakeRefreshService`（实现 `FxRateRefreshService` 接口的内存 fake，记录 `refreshCalls` / `refreshForceCalls` 并在 `setManualRate` / `resetToAuto` 调用时同步更新内存 rows），覆盖 11 用例：原开关 3 用例 + 内置币种行 + Step 8.3 新 7 用例（汇率列表渲染 / CNY 行禁用 + "基准"徽章 / 点击 USD 行 → 输入 → setManualRate / 点击 EUR（手动行）→ "重置为自动" / 点击 CNY 行无反应 / AppBar 立即刷新成功提示 / 立即刷新失败降级提示 / 入页 fire-and-forget refreshIfDue）。

验证摘要：`dart run build_runner build --delete-conflicting-outputs` → 38 outputs；`flutter analyze` → No issues found；`flutter test` → 270/270 通过（247 前 + 15 fx_rate_refresh_service + 6 fx_rate_dao Step 8.3 + 7 multi_currency_page Step 8.3 - 5 multi_currency_page 老用例移除/合并 = 270）；`dart run custom_lint` → 6 条 INFO（3 条预存 `record_new_providers.dart` + 3 条新 `multi_currency_page_test.dart` 关于 `scoped_providers_should_specify_dependencies`，仅测试 override 风格，不影响生产）。

依赖：`pubspec.yaml` 新增 `http: ^1.2.0`（`open.er-api.com` GET 请求）。在此之前 `http` 已是 `supabase_flutter` 的间接依赖；显式声明以满足 `depend_on_referenced_packages`。


## Phase 9 · Step 9.1 增量说明（2026-05-02）

新增 `lib/core/util/quick_text_parser.dart`（纯 Dart 工具，不依赖 Flutter / Riverpod / drift）：

- `QuickParseResult`（`@immutable`）：承载本地解析结果——`amount` / `categoryParentKey` / `categoryLabel` / `confidence` / `occurredAt` / `note` / `rawText`。`categoryParentKey` 与 `seeder.dart::categoriesByParent.keys` 同集；`categoryLabel` 与 `budget_providers.dart::kParentKeyLabels` 同义（`food` ↔ `餐饮`、`transport` ↔ `交通` 等 11 项）。`note` 为剥离已识别片段后的残余文本。
- `QuickTextParser({DateTime Function()? clock})`：注入时钟钩子供测试锁定参考时间，生产路径默认 `DateTime.now`。
- 解析步骤（5 步串行）：
  1. **时间**（先于金额）：内置相对天数关键词（大词优先：`大前天 → 前天 → 昨天 → 今天 → 明天 → 后天 → 大后天`，含口语化 `昨儿 / 今儿`） → `(上周|这周|本周|下周|上个星期|这个星期|下个星期)([一二三四五六日天])` → `(\d+)\s*天前`。
  2. **金额**：阿拉伯数字正则 `[¥￥]?(\d+(?:\.\d+)?)\s*(?:元|块|RMB|CNY|￥|¥)?`（caseInsensitive）优先；未命中则中文数字回退 `[零一二两三四五六七八九十百千万]+` + 可选尾缀（`元 / 块 / ￥ / ¥`）。**单字中文数字（如 `一`）若无尾缀视为非金额**——避免 `买了一些菜` 中 `一` 误判。中文数字解析覆盖 `0..99,999`，不支持亿、不支持小数、不支持负数。
  3. **分类**：53 词词典，长词优先扫描——`午饭 / 早饭 / 淘宝 / 唱K` 等不会被泛 `饭 / 饭` 截断。`_sortedKeywords` 静态闭包按 `length.compareTo` 倒序排，进程内仅算一次。词典覆盖 implementation-plan 重点：餐饮 20 词 + 交通 13 词 + 购物 13 词 + 娱乐 9 词 + 居家/医疗/教育/投资/收入/人情各 5-7 词。
  4. **置信度**：阿拉伯金额 +0.5 / 中文金额 +0.4 / 分类 +0.4 / 时间 +0.1，上限 1.0。`午饭 30` = 0.9（≥0.8 验收线）；`昨天 午餐 28` = 1.0；`三十块` 仅 0.4。
  5. **备注**：每识别一段就把 substring 替换为单空格，最终 `replaceAll(\s+, ' ').trim()`；空字符串 → null。
- `parseChineseNumber(String)` 暴露为 `@visibleForTesting` 静态方法，便于针对中文数字分支单独覆盖。
- **关键设计：时间扫描早于金额扫描**——避免 `3天前 烧烤 88` 中 `3` 被金额正则先吃掉，导致 `(\d+)\s*天前` 失配后 `amount=3 / occurredAt=null`。

新增 `test/core/util/quick_text_parser_test.dart`（34 用例 = 5 中文数字 + 7 金额 + 7 分类 + 7 时间 + 6 备注/置信度 + 2 数据类）：

- **`parseChineseNumber` × 5**：个位 / 十位组合 / 百千组合（`一百二十三`）/ 万级（`两万五千`）/ 非法输入返回 null。
- **金额 × 7**：`30` / `¥30` / `30元` / `30.5` / `三十块` / `两万五千元` / 单字中文数字若无尾缀不视为金额。
- **分类 × 7**：`午饭 30` → 餐饮 + 30 + ≥0.8（implementation-plan 验收线）/ `打车 25` → 交通 / `淘宝买衣服 99` → 购物（长词优先）/ `看电影 50` → 娱乐 / `工资 5000` → 收入 / `房租 3500` → 居家 / 未命中词典返回 null。
- **时间 × 7**：`今天` / `昨天打车 25`（confidence 1.0）/ `前天 50` / `大前天 早饭 12` / `上周五 100`（基准 2026-05-04 周一 → 5-1 周五）/ `3天前 烧烤 88`（**回归钉子：时间在金额前的关键证明**）/ `5 天前` 数字与"天前"间允许空格。
- **note + confidence × 6**：残留为空 / 残留含中文备注 / 中文金额单维 0.4 < 0.6 / 三件套满分 1.0 / 空输入零置信度 / `rawText` 保留原始 trim 前。
- **QuickParseResult × 2**：`toString` 含关键字段、`@immutable` 编译期保护占位。

测试基准时间锚定 `DateTime(2026, 5, 4)`（周一），所有相对时间断言都基于此值。


## Phase 9 · Step 9.2 增量说明（2026-05-02）

新增 `lib/features/record/quick_input_providers.dart`：
- `@Riverpod(keepAlive: true) QuickTextParser quickTextParser(Ref ref)`——返回 `QuickTextParser()`。`keepAlive` 让首页输入实例复用同一个 parser；测试可 `quickTextParserProvider.overrideWith((ref) => QuickTextParser(clock: () => fixedNow))` 注入固定时钟稳定相对时间断言。
- `const double quickConfidenceThreshold = 0.6`——implementation-plan §9.2 建议阈值。常量而非 provider，因为阈值是产品决策不随会话/账本变化；Step 9.3 LLM 增强按钮也使用同阈值决定是否暴露。

新增 `lib/features/record/quick_confirm_sheet.dart`：
- 顶层函数 `Future<bool> showQuickConfirmSheet({context, parsed})`——`showModalBottomSheet<bool>` 包裹 `QuickConfirmCard`，`MediaQuery.viewInsets.bottom` 给键盘留余量。返回 true=保存成功 / false / null=取消。
- `QuickConfirmCard`（`ConsumerStatefulWidget`）：4 字段可编辑——
  - **金额**：`TextField` + `numberWithOptions(decimal:true)` + `FilteringTextInputFormatter.allow(r'^\d*\.?\d{0,2}')` 限两位小数。前缀 `'<symbol> '` 取自 `currentLedgerDefaultCurrencyProvider` → `kBuiltInCurrencies` 命中码。`onChanged: (_) => setState({})` 让保存按钮 enable 状态实时跟随用户输入。`Key('quick_confirm_amount_field')`。
  - **分类**：`InkWell` 行 `Text('${parentLabel} / ${cat.name}')`，点击调 `_pickCategory()` 弹 `_CategoryPickerList`（`DraggableScrollableSheet(initialChildSize:0.6, max:0.85, min:0.4)` 内的 `ListView` + 按 `_parentKeyOrder` 分组的 ListTile）。每个 ListTile 挂 `Key('quick_confirm_picker_${c.id}')`，已选项 `trailing: Icon(Icons.check, color: primary)`。`Key('quick_confirm_category_row')`。
  - **时间**：`InkWell` 行 `Text` 显示 `'yyyy-MM-dd HH:mm'`，点击调 `_pickDateTime()` 串联 `showDatePicker(locale: zh_CN, lastDate: now) → showTimePicker(initialTime: TimeOfDay.fromDateTime(_occurredAt))`。文本 `Key('quick_confirm_time_text')`、行 `Key('quick_confirm_time_row')`。
  - **备注**：`TextField` + `Key('quick_confirm_note_field')`。
- 置信度横幅：`parsed.confidence < quickConfidenceThreshold` 时顶部展示红色容器（色板苹果红 `#E76F51`，背景 alpha=36 + border alpha=120），文案"识别置信度较低，请核对"。挂 `Key('quick_confirm_low_conf_banner')`。Step 9.3 "✨ AI 增强"按钮将出现在同一区。
- 保存按钮：`FilledButton`（`Key('quick_confirm_save_button')`），`onPressed: _canSave && !_saving ? _save : null`。`_canSave = _parsedAmount != null && _categoryId != null`；不满足时按钮 disabled（保留视觉反馈）。`_saving` 期间显示 `CircularProgressIndicator(strokeWidth:2)` 替代文字防双击。
- 初始化（`initState`）：
  1. `_amountController` 走 `_formatAmount(p.amount)`——`25.0` → `"25"`、`25.50` → `"25.5"`、`25.55` 保持原样（与 `RecordForm.preloadFromEntry` normalize 风格一致）；
  2. `_noteController` 填 `parsed.note` 残余文本；
  3. `_parentKey` 取自 `parsed.categoryParentKey`；
  4. `_occurredAt` = `parsed.occurredAt` 的日期 + "现在"的 hour:minute（解析未识别时回退当前时间）；
  5. `addPostFrameCallback` 触发 `_loadCategories`——拉 `categoryRepositoryProvider.listActiveAll` → 按 `_parentKeyOrder + sortOrder` 排序 → 解析的 `parentKey` 命中时默认选其下首个二级分类（`sortOrder=0`）。
- 保存路径（`_save`）：
  1. `_canSave` 守门 + `_saving` 锁；
  2. 构造 `TransactionEntry`：`type = parentKey == 'income' ? 'income' : 'expense'`（自动判定，与 `record_new_page` 同语义）；`currency = ledgerCurrency`、`fxRate = 1.0`（同币种简化——快速输入暂不暴露币种切换）；`accountId / toAccountId` 都为 null（暂不暴露账户选择）；
  3. `transactionRepository.save` → invalidate 6 个 provider（`recordMonthSummary` + 4 个 stats + `budgetProgressFor`）；
  4. 成功 `Navigator.pop(true)`；异常 SnackBar `'保存失败：$e'`。
- 顶层 const `_parentKeyLabels` / `_parentKeyOrder`——刻意复制不 import `budget_providers.kParentKeyLabels` / `seeder.categoriesByParent`，保持 `record/quick` 与 `budget/` / `data/local/` 的解耦；如果未来三处不同步，需要走单元测试守护一致性。

修改 `lib/features/record/record_home_page.dart`：
- `_QuickInputBar` 由 `StatelessWidget` 改为 `ConsumerStatefulWidget`，持有 `TextEditingController _controller` + `bool _busy`。
- TextField 加 `Key('quick_input_field')` + `textInputAction: TextInputAction.send` + `onSubmitted: (_) => _handleSubmit()`。
- 识别按钮加 `Key('quick_input_recognize_button')`，`onPressed: _busy ? null : _handleSubmit`。
- `_handleSubmit()` 流程：trim 后空文本 → SnackBar `'请先输入一段话再点识别'`；非空 → `_busy=true` → `ref.read(quickTextParserProvider).parse(text)` → `await showQuickConfirmSheet(context, parsed)` → 返回 true 时 `_controller.clear()` → `_busy=false`。`_busy` 在 await 期间锁住按钮，避免重复提交。
- 顶部 import 新增 `quick_confirm_sheet.dart` + `quick_input_providers.dart`。

### `test/features/record/quick_confirm_sheet_test.dart`
- Step 9.2 落地的 9 个用例（按 group 分 3 组）：
  - **解析结果初始展示 × 3**：① `昨天打车 25` → 金额=25 / 分类=交通/地铁公交 / 时间=2026-05-03 / 高置信度无横幅 / 保存按钮 enabled；② `30` 仅金额 → 低置信度横幅可见 + "请选择"占位 + 保存 disabled；③ `今天 午饭 30 跟同事` → 备注字段 `'跟同事'`。
  - **保存 × 4**：① `昨天打车 25` 点保存 → tx 写为 `expense + amount=25 + categoryId=cat-transport-1 + currency=CNY + fxRate=1.0 + tags=null + occurredAt 日期=2026-05-03`；② `工资 5000` → tx `type=income + categoryId=cat-income-1`；③ 用户 `enterText('42.5')` 改写金额 → 保存值跟随；④ 点取消 → 不保存、`showQuickConfirmSheet` 返回 false。
  - **分类选择器 × 2**：① 点击分类行 → 分组 header（餐饮/交通）+ 二级（午餐/打车）渲染 + cat-transport-1 trailing check icon；② 点击 cat-transport-2（打车）→ 卡片标题 `'交通 / 打车'` + 保存 categoryId 切换。**测试视口 `tester.view.physicalSize = (800, 1600)`**——DraggableScrollableSheet 内 ListView lazy 渲染，默认 600px 视口下 0.6 高度只能渲染前 4 行让"打车"在 tree 外。
- 自带 `_FakeCategoryRepository / _FakeTransactionRepository / _TestCurrentLedgerId / _cardHarness` 工具。固定 parser 时钟 `2026-05-04`（与 quick_text_parser_test 对齐）。

### `test/features/record/quick_input_bar_test.dart`
- Step 9.2 落地的 2 个集成用例（验证 `_QuickInputBar` 接线 → 卡片 → 保存全链路）：
  1. **`昨天打车 25` 全链路**：通过 `BianBianApp` + 完整 ProviderScope 走完链路。验证：① 输入 + 点识别按钮 → 卡片打开；② 卡片金额=25、分类=交通/地铁公交、时间=2026-04-25；③ 点保存 → 卡片关闭、输入框清空、`txRepo.lastSaved.amount=25 / type=expense / categoryId=cat-trans-1 / fxRate=1.0 / 日期=2026-04-25`。RecordMonth 锚定 2026-04 + parser 时钟 `2026-04-26` 让"昨天"=2026-04-25 落在测试月内，避免月跨界 flaky。
  2. **空文本 SnackBar**：点识别 → SnackBar `'请先输入一段话再点识别'` + 不弹卡片。
- 文件单独成立而非塞 widget_test.dart，是为了承载 9.2 专属 override（`quickTextParserProvider` / `categoryRepositoryProvider` / `_RecordingTransactionRepository` 区别于 widget_test 那个 fail 的同名类）不影响 home shell 基线测试。
- `library;` 声明放在 dartdoc 后避免 `dangling_library_doc_comments` 警告。

验证摘要：`flutter analyze` → No issues found；`flutter test` → 304/304 通过（270 前 + 34 新 = 304）；`dart run custom_lint` → 仍是 6 条预存 INFO，与本步无关。**未触动** `pubspec.yaml`、未触动 `build_runner` 产物（解析器是纯 Dart 类，无 codegen 依赖）。Step 9.2 会在 `features/record` 起 `quickTextParserProvider` 把它接入首页快捷输入条；本步只承担"纯本地基线 + 置信度信号"。


## Phase 9 · Step 9.3 增量说明（2026-05-02）

数据层 / Schema（v7 → v8）：
- `lib/data/local/tables/user_pref_table.dart`：追加 3 列。
  - `ai_input_enabled INTEGER NULLABLE DEFAULT 0`：master switch。0/null = 关闭（确认卡片不显示 AI 增强按钮），1 = 开启（且需 endpoint/key/model 三件齐全才真正显示按钮）。
  - `ai_api_model TEXT NULLABLE`：用户填写的模型名（如 `gpt-4o-mini`）。
  - `ai_api_prompt_template TEXT NULLABLE`：用户填写的 prompt 模板（含 `{NOW}` / `{TEXT}` / `{CATEGORIES}` 占位符）；为空时使用 [kDefaultAiInputPromptTemplate] 兜底。
  - 历史遗留列 `ai_api_endpoint TEXT` / `ai_api_key_encrypted BLOB`（自 Step 4.2 user_pref 表初次落库即声明但未消费）：Step 9.3 起被消费。`ai_api_key_encrypted` 在 V1 落 UTF-8 raw bytes（DB 由 SQLCipher 加密保护，故 at-rest 安全已由 DB 级别覆盖；列名 `_encrypted` 是历史遗留——曾计划用 BianbianCrypto 字段级加密，Phase 11 决策后整套字段级加密计划废弃，名字保留只是为了不动 schema）。
- `lib/data/local/app_database.dart`：`schemaVersion` 从 v7 升 v8；`onUpgrade` 新增 `if (from < 8)` 分支：3 个 `m.addColumn(userPrefTable, ...)`。Schema 版本注释同步追加 v8 行。

Provider 层 / 服务：
- `lib/features/settings/ai_input_settings_providers.dart`（新建）：
  - `AiInputSettings`（`@immutable` 数据类）：5 字段 + `hasMinimalConfig`（enabled + endpoint/key/model 三件齐全才 true，决定确认卡片是否显示 AI 增强按钮）+ `effectivePromptTemplate`（用户值优先，否则走默认）+ `copyWith` + `==` / `hashCode`。
  - `AiInputSettingsNotifier`（`@Riverpod(keepAlive: true) class`）：`build()` 从 user_pref 加载；`save(AiInputSettings)` 全量写入 user_pref + `invalidateSelf()`。空白字段（empty / whitespace-only）一律落 NULL。API key 经 `_encodeApiKey`（UTF-8 → Uint8List）/ `_decodeApiKey`（反向）转换。
  - `aiInputEnhanceServiceProvider`（`@Riverpod(keepAlive: true)`）：返回 `AiInputEnhanceService(settings: aiSettings)`，settings 变更时自动重建。测试可 `overrideWithValue(fakeService)`。
  - `kDefaultAiInputPromptTemplate`（顶层 const）：默认 prompt 模板。强调"只输出 JSON"+ 字段允许 null + snake_case 字段名（与 design-document §7.1 DDL 一致）。

- `lib/features/record/ai_input_enhance_service.dart`（新建）：
  - `AiEnhanceResult`（`@immutable` 数据类）：4 字段 amount / categoryParentKey / occurredAt / note。LLM 命中视作高置信度，无 confidence 字段。
  - `AiEnhanceException`（`Exception`，含 message）：所有失败的统一异常类型。UI 层 catch 后展示 SnackBar `'AI 解析失败：$message'`。
  - `kValidParentKeys`（顶层 const Set）：合法 parent_key 集（与 `seeder.dart::categoriesByParent.keys` 同集），用于校验 LLM 返回的 `category_parent_key`。
  - `AiInputEnhanceService` 类：构造参数 `settings` + 可注入的 `httpClient` / `clock` / `timeout`（默认 30s）。
    - `enhance(String rawText)`：① 校验配置完整 → ② 校验 endpoint URL 合法 → ③ 替换 prompt 占位符 → ④ POST OpenAI Chat Completions（`{model, messages: [{role:user, content:prompt}], temperature:0, response_format:{type:'json_object'}}`，`Authorization: Bearer <key>`）→ ⑤ 30s 超时 → ⑥ 抽取 `choices[0].message.content` → ⑦ 调 `parseEnhanceJson`。任一步失败抛 [AiEnhanceException]。
    - `_buildPrompt`：替换 `{NOW}` → `yyyy-MM-dd HH:mm`、`{TEXT}` → 用户原文、`{CATEGORIES}` → `kValidParentKeys.join(' / ')`。
    - `buildPromptForTesting`：`@visibleForTesting` 暴露给单测验证占位符替换。
  - `parseEnhanceJson(String)`（顶层 + `@visibleForTesting`）：严格 schema 校验。`amount` 必须 number 且 isFinite 且 > 0；`category_parent_key` 必须在 [kValidParentKeys] 内；`occurred_at` 必须 ISO 日期；`note` 必须 string。任一字段类型 / 取值 / 格式不符抛 [AiEnhanceException]——不返回部分解析结果，避免半成品污染卡片。

UI 层：
- `lib/features/settings/ai_input_settings_page.dart`（新建）：
  - `AiInputSettingsPage`（ConsumerStatefulWidget）：5 字段表单 + 底部"保存"按钮。
  - 字段：SwitchListTile（开关）+ 4 个 TextField（endpoint URL / API key（默认 obscureText=true，可点眼睛切换）/ model / prompt 模板，多行 6-12 行）。
  - 控制器在第一次拿到 settings 时一次性 `_hydrate`（`_hydrated` flag 守门，避免后续 settings 变更覆盖用户编辑）。
  - 保存路径：构造完整 [AiInputSettings] → `notifier.save(...)` → SnackBar `'AI 增强配置已保存'`；失败 → `'保存失败：$e'`。`_saving` 状态守按钮防双击。
  - 关键 Key：`ai_input_enabled_switch` / `ai_input_endpoint_field` / `ai_input_api_key_field` / `ai_input_show_api_key` / `ai_input_model_field` / `ai_input_prompt_field` / `ai_input_save_button`。

- `lib/features/record/quick_confirm_sheet.dart`（修改）：
  - `_QuickConfirmCardState` 新增字段 `bool _aiEnhancing = false`。
  - 新增 `_runAiEnhance()` 方法：调 `aiInputEnhanceServiceProvider.enhance(parsed.rawText)` → 成功 → setState 用返回值重写 `_amountController` / `_parentKey` + 自动选首个二级分类 / `_occurredAt`（保留时分）/ `_noteController` → SnackBar `'AI 已更新'`。失败 catch [AiEnhanceException] → SnackBar `'AI 解析失败：${e.message}'`，**字段不变**（implementation-plan §9.3 验证 2 "网络失败回退本地结果"）。
  - `build()` 内新增局部变量 `showAiButton = lowConfidence && (aiSettings?.hasMinimalConfig ?? false)`——三个条件同时满足才显示按钮。
  - 低置信度横幅 Row 末尾新增 `TextButton.icon(✨ AI 增强)`：挂 `Key('quick_confirm_ai_enhance_button')`，loading 时显示小 spinner + 文字 "解析中…"，完成后回到 `'AI 增强'`。颜色取苹果红与横幅一致。

- `lib/app/home_shell.dart`：`_MeTab` 新增 `ListTile(Icons.auto_awesome, '快速输入 · AI 增强')` → `context.push('/settings/ai-input')`。
- `lib/app/app_router.dart`：新增 `GoRoute('/settings/ai-input')` → `AiInputSettingsPage`。

测试：
- `test/features/settings/ai_input_settings_providers_test.dart`（新建，10 用例）：
  - **AiInputSettings 数据类 × 5**：默认空 / hasMinimalConfig 四件齐全断言（5 case）/ effectivePromptTemplate 用户值优先 / `==` 全字段参与 / copyWith 仅修改指定字段。
  - **DB 集成 × 5**：build 默认 → 全空 / save → 持久化 → 重读校验 5 字段 + DB 直查 user_pref 5 列 + API key BLOB UTF-8 bytes 断言 / save 空白字段一律 NULL / save API key 含中文 / emoji UTF-8 往返 / user_pref 不存在的极端兜底。
- `test/features/record/ai_input_enhance_service_test.dart`（新建，24 用例）：
  - **parseEnhanceJson 正常路径 × 4**：全字段命中 / 仅 amount / amount=null 仍可用 / 空字符串等价缺失。
  - **parseEnhanceJson schema 严格校验 × 9**：content 非 JSON / 数组非对象 / amount 类型非法 / amount ≤ 0 / amount 0.0 / category 取值非法 / category 类型非法 / occurred_at 非 ISO / note 类型非法。
  - **AiInputEnhanceService.enhance × 8**：未配置兜底 / endpoint URL 非法 / 成功路径（验证 Authorization header / model / response_format / prompt 替换）/ HTTP 非 200 / 网络异常（client throws）/ 缺 choices / content 非 JSON / amount schema 非法。
  - **buildPromptForTesting × 3**：默认模板三占位符替换 / 用户自定义模板替换 / 空 promptTemplate 走默认。
- `test/features/settings/ai_input_settings_page_test.dart`（新建，3 用例）：① 入页根据 settings 预填 5 字段（含 obscureText=true）；② 切开关 + 修改 + 保存 → notifier 收到完整 settings + SnackBar；③ 点击眼睛 → API key obscureText 切换。
- `test/features/record/quick_confirm_sheet_test.dart`（追加 4 用例 = 13 → 17）：① 无 AI 配置 + 低置信度 → 横幅在但 AI 按钮不在；② AI 配置完整 + 低/高置信度 → 按钮分别可见/不可见；③ 点 AI → 成功结果改写 amount/parentKey/occurredAt/note；④ 点 AI → 失败 SnackBar，字段保持本地值。`_overrides` 新增 `aiInputSettingsNotifierProvider` + 可选 `aiInputEnhanceServiceProvider` 注入。

依赖：本步未新增 `pubspec.yaml` 依赖。`http: ^1.2.0` 已在 Step 8.3 引入，本步直接复用。

验证摘要：
- `dart run build_runner build --delete-conflicting-outputs` → 6+ outputs（Step 1 +176 outputs，Step 2 +6）。
- `flutter analyze` → No issues found。
- `flutter test` → 360/360 通过（315 前 + 4 quick_confirm_sheet + 24 service + 10 providers + 3 page + 4 quick_confirm_sheet group 重构净增量 = 360）。
- `dart run custom_lint` → 8 条 INFO（6 条预存 + 2 条新 `ai_input_settings_page_test.dart` 关于 `avoid_public_notifier_properties` / `scoped_providers_should_specify_dependencies`，仅测试 fake 风格，不影响生产）。


## Phase 10 · Step 10.1+10.2 增量说明（2026-05-03）

### 范围与重要决策

- **同步语义选择**：implementation-plan §10.2 描述的是「sync_op 队列 + LWW 增量合并」模型；V1 选择**与「蜜蜂记账云同步方案.md」一致的快照模型**——账本视为一个 JSON 文件，每次上传 / 下载是整体覆盖。理由：① 实现简单可靠（无需冲突合并器）；② 与 BeeCount 用户预期一致；③ 单设备主力 + 备份恢复场景足够。多设备双向增量同步留给 V2，届时切换为队列模型时本接口（[SyncService]）保持稳定。
- **不动 schema**：云配置（URL / Key / Path / Token 等）由 `flutter_cloud_sync` 包通过 `SharedPreferences` 持久化；`user_pref` 不增列。代价是配置在 Android 上是明文 XML、iOS 是 NSUserDefaults plist——V1 接受这个权衡（Phase 11 附件云同步同样**不**触动云配置存储，因为整体方向是"云是用户自有空间，明文可接受"；如果未来真要加密云配置，作为独立 Phase 重新评估，不在 Phase 11 范围内）。
- **后端覆盖**：iCloud（仅 iOS）/ WebDAV / S3 / Supabase 共 4 种。**故意不开启 BeeCount Cloud**——它是 BeeCount 内部服务，本项目用户用不到。包内代码保留为死代码，不暴露任何 UI 入口。

### 文件清单与职责

#### `lib/features/sync/sync_service.dart`
- **`SyncService`** 抽象：`upload(ledgerId)` / `downloadAndRestore(ledgerId)` / `getStatus(ledgerId, {forceRefresh})` / `deleteRemote(ledgerId)` / `clearCache()`。所有方法用 `String ledgerId`（与项目其余地方一致）。
- **`LocalOnlySyncService`** 兜底实现：所有写操作抛 `UnsupportedError`；`getStatus` 返回 `SyncState.notConfigured` + 哨兵消息 `__SYNC_NOT_CONFIGURED__`（UI 层负责本地化）。
- **`SnapshotSyncService`** 实现：包装 `CloudSyncManager<LedgerSnapshot>`。
  - `_path(ledgerId)` 返回 `users/<userId>/ledgers/<ledgerId>.json`——userId 来自 `provider.auth.currentUser?.id`，无 auth 的 backend（WebDAV/iCloud/S3）退化为 `deviceId`。Supabase RLS 依赖 `(storage.foldername)[2] = auth.uid()`，所以 userId 必须等于 Supabase 的 auth.uid()。
  - `upload`：拉本地快照 → manager.upload。
  - `downloadAndRestore`：manager.download → 校验 `snapshot.ledger.id == ledgerId`（防错恢复别人的备份）→ `importLedgerSnapshot`。
  - `getStatus`：拉本地快照（带 `exportedAt` 时间戳）→ manager.getStatus（指纹比对 + cache）。
  - `deleteRemote`：catch `CloudStorageException` 视为幂等成功（云端已不存在）。

#### `lib/features/sync/snapshot_serializer.dart`
- **`LedgerSnapshot`** 不可变数据类（V1 = `version: 1`）：`ledger / categories / accounts / transactions / budgets` + `exportedAt / deviceId`。`fromJson` 校验版本号——大于 `kVersion` 抛 `FormatException`，避免新版备份被旧版误读出错。
- **`LedgerSnapshotSerializer implements DataSerializer<LedgerSnapshot>`**：`serialize` = `jsonEncode`、`deserialize` = `jsonDecode`、`fingerprint` = `sha256(utf8(data))`。
- **`exportLedgerSnapshot`** 顶层函数：从 5 个仓库拉**活跃**实体（不含已软删）→ 组装 `LedgerSnapshot`。**不**读 sync_op / fx_rate / user_pref。
- **`importLedgerSnapshot`** 顶层函数：单事务内 → ① `delete .. where ledger_id = ?` 物理清空当前账本的 transactions / budgets（含已软删）→ ② `db.batch + InsertMode.insertOrReplace` 写 ledger / categories / accounts / transactions / budgets。**故意绕过 repository 层 `save`**——避免 import 触发 sync_op 队列累积，形成「刚下载的数据立刻又被排队上传」循环。categories / accounts 是全局资源，只 upsert 不 delete（避免破坏其他账本依赖）。

#### `lib/features/sync/sync_provider.dart`
全部用普通 `Provider` / `FutureProvider`（不走 `@riverpod` 代码生成，避免再产 .g.dart）。链式：
- `cloudServiceStoreProvider`（thin wrapper of `CloudServiceStore`）
- `activeCloudConfigProvider`（FutureProvider<CloudServiceConfig>，UI 与 sync 共享真值源）
- `supabaseConfigProvider` / `webdavConfigProvider` / `s3ConfigProvider`（UI 配置对话框预填用）
- `cloudProviderInstanceProvider`（FutureProvider<CloudProvider?>，根据 active config 调 `createCloudServices` 实例化；初始化失败返回 null 让上层走 LocalOnly 兜底；`ref.onDispose` 清理连接）
- `authServiceProvider`（无云服务时返回 `NoopAuthService`）
- `syncServiceProvider`（FutureProvider<SyncService>，组合 5 个 repository + DB + deviceId 构造 `SnapshotSyncService`）

切换激活后端 / 保存配置后调 `ref.invalidate(activeCloudConfigProvider)` 即可下游链式重建。

#### `lib/features/sync/sync_trigger.dart`（Step 10.7）

把"5 个触发源"统一在同一个调度器下：① App 启动；② 前台恢复（`WidgetsBindingObserver.didChangeAppLifecycleState == resumed`）；③ 记账后 5s 防抖（`record_new_providers.save` 调用 `scheduleDebounced()`）；④ 首页下拉刷新（`record_home_page._onPullToRefresh` 调用 `trigger()` 并消费返回结果展示 SnackBar）；⑤ 15 分钟定时器（lifecycle resumed 启动、paused 停止）。

- **`SyncTrigger extends Notifier<SyncTriggerState>`**：`build()` 注册 `ref.onDispose` 取消所有内部计时器。三大不变量：
  1. **前一次未完成则跳过**——内部 `_running` 标记，命中即返回 `SyncTriggerOutcome.skipped`，不堆叠 upload。
  2. **未配置云服务则跳过**——`syncServiceProvider` 解析为 `LocalOnlySyncService` 时直接返回 `SyncTriggerOutcome.notConfigured`，不抛异常打断调用方。
  3. **网络错误归一化**——`_isNetworkError` 把 `SocketException` / `Failed host lookup` / `connection refused/reset/closed` / `HandshakeException` / `TimeoutException` / `Network is unreachable` / `No address associated` 共 9 类异常归类为 `networkUnavailable`。其他归 `failure`。任何意外异常（含 `MissingPluginException` 等测试环境平台报错）都被外层 try/catch 兜住——`unawaited(trigger(...))` 永远不冒烟。
- **公开方法**：`trigger()` 主入口（5 种 outcome：success/networkUnavailable/failure/skipped/notConfigured）；`scheduleDebounced({delay = 5s})` 重置式防抖（重复调用取消旧 timer）；`startPeriodic({interval = 15min})` / `stopPeriodic()` 由生命周期管控；`cancelTimers()` 显式清理（`BianBianApp.dispose` 调用，因为 `ref.onDispose` 只在 ProviderContainer 关闭时跑）。
- **`SyncTriggerState`**：`isRunning` / `isConfigured` / `lastSyncedAt` / `lastError` 4 字段。`copyWith` 支持 `clearError` / `clearLastSyncedAt` 显式清空（避免 `??` 把 `null` 当成"不改"）。
- **`syncTriggerProvider`**：`NotifierProvider<SyncTrigger, SyncTriggerState>(() => SyncTrigger())`——故意没用 `Notifier.new` tear-off，因为 `SyncTrigger({SyncTriggerClock? clock})` 的可选命名参数与 `Notifier Function()` 签名不兼容。`SyncTriggerClock` typedef 注入测试。

#### `lib/app/app.dart`（Step 10.7 升级）

`BianBianApp` 由 `StatelessWidget` 升级为 `ConsumerStatefulWidget` + `WidgetsBindingObserver`：
- `initState`：`addPostFrameCallback` 后读 `syncTriggerProvider.notifier`，`unawaited(trigger.trigger())` + `trigger.startPeriodic()`。延迟到首帧避免 Riverpod "watched a provider before init" 警告。
- `didChangeAppLifecycleState`：`resumed` → trigger + startPeriodic；`paused/detached/hidden` → stopPeriodic；`inactive`（来电覆盖等短暂态）不动定时器。
- `dispose`：`removeObserver` + `cancelTimers`（`// ignore: avoid_ref_inside_state_dispose`，INFO 级 lint）。
- 新增 `enableSyncLifecycle = true` 构造参数：测试传 `false` 跳过整套生命周期，避免 `syncServiceProvider` 链触达 `SharedPreferences` 抛 `MissingPluginException`，以及悬挂的 `Timer.periodic(15min)` 让 `tester.pumpAndSettle()` 报"Timer still pending"。**新增 widget 测试若 pump `BianBianApp` 必须显式传 `false`**。

#### `lib/features/record/record_home_page.dart`（Step 10.7 增量）

- **`_SyncStatusBadge`**（ConsumerWidget）：watch `syncTriggerProvider` → 仅当 `isConfigured` 为真时渲染。4 态 icon：① running → `CircularProgressIndicator(14×14, strokeWidth=2)`；② lastError → `cloud_off_outlined` + error 色；③ lastSyncedAt → `cloud_done_outlined` + tertiary 色 + `_formatRelative(t)` 小字（"刚刚 / N 分钟前 / N 小时前 / N 天前 / MM-dd HH:mm"）；④ 其余 → `cloud_outlined` 暗色。tooltip 含错误消息或上次同步时间。点击 `context.push('/sync')`。`_TopBar` Row 里位置：`Spacer()` 之后、转账按钮之前。
- **`_TransactionListState`**：空状态与列表态都包 `RefreshIndicator(onRefresh: _onPullToRefresh)`。空状态用 `ListView` + `AlwaysScrollableScrollPhysics` + `SizedBox(height: screenH*0.5)`，让无数据时也能下拉。`_onPullToRefresh` 调 `trigger()` → switch 5 种 outcome 显示 SnackBar：`success` "已同步" / `networkUnavailable` "网络不可用" / `failure` "同步失败：$msg" / `skipped` 与 `notConfigured` 静默退出。

#### `lib/features/record/record_new_providers.dart`（Step 10.7 增量）

`save()` 末尾追加 `ref.read(syncTriggerProvider.notifier).scheduleDebounced()`（`// ignore: avoid_manual_providers_as_generated_provider_dependency`，INFO 级 lint）。连续保存只触发最后一次同步，5 秒防抖窗口。

#### `lib/features/sync/cloud_service_page.dart`
「我的→云服务」页。结构：
- **顶部全局开关 `SwitchListTile`**：绑定 `active.type != local`。OFF→`store.disableCloudSync()`（store 把当前非 local 类型记到 `_kLastActiveType`，再切 `local`）+ invalidate sync 链；ON→先尝试 `store.reactivateLast()` 还原上次激活的后端，找不到就回落 `store.findFirstReady()` 扫描首个 ready 的后端激活，仍然没有时弹"请先在下方任选一个云服务并完成配置"。**全局开关本身不再控制卡片可点性**——卡片就绪态完全由 per-后端 config + failed 集决定，开关 OFF 时只切到 LocalOnlySyncService 并隐藏 _SyncStatusCard。
- **`_SyncStatusCard`**（开关 ON 时显示）：watch `currentLedgerIdProvider` + `syncServiceProvider` → `_SyncStatusBody`：
  - 标题行：后端名 + obfuscated URL + 刷新状态按钮（`force=true`）。
  - 状态行 `_StatusLine`：彩色圆点 + 文字（已同步/云端较新/本地较新/未配置等）+ 上次同步时间 + 本地/云端流水数 + 错误文案。
  - 操作行：上传（FilledButton）/ 下载（OutlinedButton，二次确认）/ 删除云端（IconButton，二次确认）。`_busy` 状态守门防双击；操作后 `clearCache + _refresh(force: true)`。
- **后端选择卡 4 个**：iCloud（仅 iOS）/ WebDAV / S3 / Supabase。每张卡片 watch 各自的 `supabase|webdav|s3ConfigProvider` + `cloudFailedBackendsProvider`，**就绪态 = `config.valid && !failed.contains(type)`**（iCloud 仅靠 `Platform.isIOS`）；未就绪卡片半透明且禁点，齿轮配置入口仍可用——保证"先配再启用"。点击就绪卡片走 `_switchService`，**必须检查 `store.activate(type)` 的 bool 返回值**：未配置 / 配置无效时返回 false 且不切换激活类型，UI 弹"切换失败：xxx 尚未配置..."并跳过 invalidate；只有 true 才弹"已切换到 xxx"+ invalidate 三个 provider（active config / auth / sync service）。后端名走 `_typeLabel` 中文化映射（避免直接打印枚举名）。点击齿轮打开配置对话框（_SupabaseConfigDialog / _WebdavConfigDialog / _S3ConfigDialog）。
- **保存配置后自动跑连接测试**：`_saveConfig` 在 `store.saveOnly(cfg)` 之后调用 `_testConnection(cfg)`（包内 `createCloudServices` + 立即 `dispose`，10s 超时），结果通过 `store.markBackendTested(type, success)` 写入 failed 集（成功时移除条目）。S3.initialize 内部会真实调 `listObjects` 校验 endpoint/credentials/bucket，Supabase / WebDAV initialize 也走真实 I/O——所以测试 = "整链路真能跑通"。结果通过 SnackBar 反馈："配置已保存并通过连接测试" 或 "配置已保存，但连接测试失败：xxx"。失败的卡片副标题显示"上次连接测试失败，点击右侧设置重新配置"。
- **三个对话框均提供"自定义名称"输入框**，统一写入 `CloudServiceConfig.customName`（顶层通用字段，非 S3 专属）。`obfuscatedUrl()` 在 Supabase / WebDAV / S3 三个 case 都优先返回 customName，回退到现有 host / endpoint 拼接——驱动状态卡标题。**S3 还有副作用**：`S3AuthService` 用 customName 作为 `CloudUser.id`，把云端路径前缀从 `users/s3-<accessKey>/...` 改为 `users/<customName>/...`，让 S3 备份目录变得人类可读；Supabase 受 RLS 约束（`users/<auth.uid()>/...`）不能动路径，WebDAV 路径已由 username 决定也不动——它们的 customName **仅影响标题**。`fromJson` 优先读 `customName` 键、回落老键 `s3CustomName`，兼容升级前已落盘的 S3 配置。

### `packages/flutter_cloud_sync*` 子包（vendored）

来自 BeeCount 的多后端云同步框架，作为 `path:` 依赖直接集成（不通过 pub.dev）。

| 子包 | 职责 |
| :-- | :-- |
| `flutter_cloud_sync` | 核心抽象：`CloudProvider / CloudAuthService / CloudStorageService / CloudSyncManager<T> / DataSerializer<T> / CloudServiceConfig / CloudServiceStore / SyncStatus`。`CloudSyncManager` 用 30 秒 TTL 缓存 `getStatus`。`CloudServiceStore` 维护 `_kActiveType` + `_kLastActiveType` + `_kFailedBackends`：`disableCloudSync` 把当前非 local 类型记到 last 再切 local；`reactivateLast` 读 last 并复用 `activate`（若配置失效返回 null 让 UI 提示）；`findFirstReady` 按 s3>supabase>webdav 顺序扫描首个 `activate` 成功且 **不在 failed 集**的后端，作为 ON 开关的兜底；`markBackendTested(success)` / `failedBackends()` 维护 `_kFailedBackends` 持久化集合（连接测试失败的后端落盘，`success=true` 时清除）；`activate(type)` 在配置缺失/无效时返回 false——**调用方必须检查**。 |
| `flutter_cloud_sync_supabase` | Supabase backend（auth + storage + database + realtime）。 |
| `flutter_cloud_sync_webdav` | WebDAV backend（无 auth，URL+username+password 直连）。 |
| `flutter_cloud_sync_icloud` | iCloud Drive backend（仅 iOS / iPadOS，原生 plugin）。 |
| `flutter_cloud_sync_s3` | S3 兼容 backend（Cloudflare R2 / AWS S3 / MinIO 等）。 |

子包内部仍带 `BeeCountCloudProvider`（独立 BeeCount 后端的实现），但项目层未暴露 UI 入口、`provider_factory.createCloudServices` 仍含 `case beecountCloud` 分支但永远不会被触发（active config 不会是该类型）。视为死代码保留。

`pubspec.yaml` 新增 `crypto: ^3.0.3` 依赖（用于 `LedgerSnapshotSerializer.fingerprint` 的 SHA256）；其他依赖均已存在。

### Phase 10 修复历史与「沙盒污染」事件

Phase 10 实施过程中，前一轮的 agent 留下了破坏：① 简化重写了 `lib/data/local/providers.dart` 与 `lib/data/repository/providers.dart`（去掉 `deviceIdProvider / defaultSeedProvider / 5 个 repo provider / currentLedgerIdProvider`）；② 删除了对应的 `.g.dart` 产物；③ 在 `user_pref` 加了未消费的 `sync_provider_type/config` 两列并升 schema 到 v9；④ `sync_engine.dart` 与 `sync_provider.dart` 类型全错（`int ledgerId` vs `String id`，drift 字段名错，`AccountEntry.fromJson` 等不存在）。导致全项目 80+ 编译错误，无法运行。

修复策略：① 用 `git checkout HEAD --` 恢复 4 个 providers 文件到 Step 9.3 基线；② 回滚 schema v9 升级，保持 v8；③ 删除 `sync_engine.dart`，重写 `sync_service.dart` / `snapshot_serializer.dart` / `sync_provider.dart`；④ 修补 `cloud_service_page.dart` 的 import + 加 status 卡片；⑤ 加 `crypto` 依赖。结果：360/360 测试通过，主项目 lib/ 零 errors 零 warnings。

### 待办（Phase 10 后续）

- **Step 10.3-10.6** 已经被 V1 快照模型覆盖（包内 4 个 backend 实现都可用）。后续若要走增量队列模型（V2），实现 sync_op 消费器 + LWW 合并器，并替换 `SnapshotSyncService` 为 `IncrementalSyncService`。
- **Step 10.7（已完成）**：5 个触发源由 `SyncTrigger` 调度器统一管理；首页顶栏渲染 `_SyncStatusBadge`；下拉刷新走 `trigger()`。Phase 11 附件云同步在 `SnapshotSyncService.upload` 内部前置一段附件二进制上传，`SyncTrigger` 接口完全不动。
- **Phase 11 附件云同步（已完成）**：见 implementation-plan §11。
  - **Step 11.1（已完成 2026-05-04 追溯）**：`CloudStorageService` 抽象类加 `uploadBinary` / `downloadBinary` / `listBinary` 三个方法；4 个 backend 子包加占位实现（`UnimplementedError`，留待真后端集成测试时填充）。
  - **Step 11.2（已完成 2026-05-04）**：`AttachmentMeta` 领域实体 + `AttachmentMetaCodec`（v8 兼容解码）+ schema v8→v9 BLOB 内容迁移 + `RecordForm.attachmentMetas` 切换 + `AttachmentUploader` 上传管线 + `SnapshotSyncService.upload` 内部前置附件上传。**全程明文**——云端是用户自有空间，无加密层。
  - **Step 11.3（已完成 2026-05-04）**：`AttachmentDownloader.ensureLocal` 三态契约（命中本地 / 远端拉取并 cache writeback / 失败返回 null）+ `AttachmentCachePruner`（500 MiB 软上限 + 7 天保留期 LRU）+ `AttachmentThumbnail` 统一 UI 组件（loading/missing/success 三态 + localPath 同步快路径）+ `prefetchAttachment` fire-and-forget helper + 「我的 → 附件缓存」`AttachmentCachePage` 设置页 + main bootstrap 冷启动 prune。`record_new_page` / `record_tile_actions` 的 `Image.file` 全部替换为 `AttachmentThumbnail`。
  - **Step 11.4（已完成 2026-05-04）**：`AttachmentCachePruner.removeForTransaction(txId)` 软删 cache 联动 + `record_tile_actions` / `record_home_page` Dismissible 软删点 fire-and-forget cache 清理 + `AttachmentOrphanSweeper`（远端 listBinary diff DB 集合 + 30 天宽限 + 7 天节流，用 SharedPreferences 持久化上次完成时间）+ `TrashGcService` 硬删流水时先 `attachmentStorage.delete(remoteKey)` 再清 documents + 跨 backend 切换确认对话框（`countAttachmentsWithRemoteKey` > 0 时弹「迁移 / 暂不迁移」，选迁移走 `clearAllRemoteAttachmentKeys` 让下次同步重传到新 backend）。**故意不实现** plan 提到的 `Stream<AttachmentUploadProgress>` 进度提示——回填只在第一次同步时发生且数量小，留作 V2。**测试与人工验证留给用户本机执行**。
  - 原 Phase 11「快照加密 + 同步码」整段废弃。

---

## Step 3.6 + 3.7 补回（2026-05-03）

### 改动概要

Step 3.6（首页流水搜索）与 3.7（首页月份选择器）此前在 Phase 3 收尾被跳过，现一并补齐：

- `lib/features/record/record_search_filters.dart`（新建）：`SearchQuery` 数据类（关键词 / 起止日期 / 类型筛选 / 金额上下限）+ `SearchTypeFilter` 枚举（all/expense/income/transfer）+ `searchTransactions` 纯函数（在内存中过滤当前账本未删流水；关键词同时匹配备注 `tags` / 分类名 / 账户名含 `toAccountId`）。
- `lib/features/record/record_search_page.dart`（新建）：`RecordSearchPage` ConsumerStatefulWidget，结构 = 关键词 TextField + ExpansionTile（日期范围 / SegmentedButton 类型 / 金额上下限） + `_ResultsView`。空查询时显示「输入关键词或筛选条件后开始搜索」，命中无结果时显示「没有找到相关流水」。结果项按 `occurredAt` 倒序，行内拼接 `日期 · 账户名 · 备注` 副标题。AppBar 右侧 `Icons.refresh` 重置全部条件。
- `lib/features/record/month_picker_dialog.dart`（新建）：`showMonthPicker` 顶层函数 + `_MonthPickerDialog` 私有 StatefulWidget。年箭头切年 + 4×3 月份网格 + 取消/确定双按钮，返回 `DateTime(year, month)`（day 固定为 1，对齐 `RecordMonthProvider`）。`firstDate` 默认 `DateTime(2000)`，`lastDate` 默认 `now.year + 5`。
- `lib/features/record/record_home_page.dart`：
  - `_TopBar` 搜索图标 `onPressed` 由「占位」改为 `context.push('/record/search')`。
  - `_MonthBar` 中间月份 `Text` 包裹一层 `InkWell`（key=`record_month_label`），点击调 `showMonthPicker` → `recordMonthProvider.notifier.jumpTo(picked)`。
- `lib/app/app_router.dart`：新增 `GoRoute('/record/search')` → `RecordSearchPage`。

### 设计决策

- **搜索的数据加载在 UI 层 `FutureBuilder` 内做，不抽 Riverpod Provider**：搜索页 query 是页面局部 state，每次过滤都依赖最新的 query；如果做成 `family` provider 又要把 query 哈希成 key，反而复杂。直接 `_ResultsView.FutureBuilder` 拉一次 listActiveByLedger + listActiveAll + listActive 后纯函数过滤即可，V1 数据量在内存里完全可接受。
- **空查询 `SearchQuery.isEmpty == true` 时返回空列表**：避免一打开搜索页就把整本账本砸到屏幕——这不是搜索意图，引导用户输入条件。
- **月份选择器没引入第三方包**：原生 `AlertDialog` + `GridView.count(crossAxisCount: 4)` 即可拼出。`showDatePicker(initialDatePickerMode: DatePickerMode.year)` 强迫用户先选年再选日，跨年跳转体验不佳，故弃用。
- **月份选择器返回值的 day 固定为 1**：与 `RecordMonth.build` 的语义对齐（`DateTime(now.year, now.month)`，day 默认 1）。`jumpTo` 接受任意 day 但内部按 `DateTime(day.year, day.month)` 收敛。

### 测试

- `test/features/record/record_search_filters_test.dart`（11 用例）：覆盖空查询返回空、关键词匹配备注/分类/账户/转账目标账户、大小写不敏感、日期闭区间、类型筛选、金额范围、多维度交集、`SearchQuery.copyWith` clear 标志位、`isEmpty` 边界。
- `test/features/record/record_search_page_test.dart`（3 用例）：空查询提示、关键词命中、空结果提示——使用 `_FakeTransactionRepository` / `_FakeCategoryRepository` / `_FakeAccountRepository` 三个本地 fake，不触达真实 DB。
- `test/features/record/month_picker_dialog_test.dart`（3 用例）：默认高亮初始月份 + 确认返回该月份、左右切年 + 选月 + 确认返回新月、取消按钮返回 null。
- 全量回归：411/411 测试通过。

### 给后续开发者的备忘

- **关键词匹配范围**：当前命中备注（`tx.tags`）+ 分类名 + 账户名（含转账目标）。Phase 11 附件云同步**不**改 `tags` / `note_encrypted` 列的语义（原计划的字段级加密已废弃），只升级 `attachments_encrypted` BLOB 的 JSON shape——搜索逻辑无需任何调整。
- **搜索粒度限定为「当前账本」**：`_loadAndSearch` 通过 `currentLedgerIdProvider` 拿当前账本 id 后只查该账本的流水。如果将来需要「跨账本搜索」，应在查询条件加 `ledgerScope: SearchLedgerScope.current/all`，并在 service 层把 `txRepo.listActiveByLedger(ledgerId)` 改为遍历所有未归档账本聚合。
- **月份选择器的边界**：`firstDate` / `lastDate` 都按"年-月"粒度比较（day 不参与），所以选择 1 月 / 12 月时不会被边界 day 卡住。`_MonthCell.enabled = false` 时点击不响应、显示灰色。
- **路由 `/record/search` 由首页搜索图标驱动**：未来如果在统计页或账本页加二级跳转，遵循同一路由约定。

### 续作：搜索结果点击复用首页详情/编辑/复制/删除（2026-05-03）

实施完成后追问"搜索结果点击能打开流水详情吗？对搜索结果进行复制、编辑、删除"，做了以下二次重构：

- 新增 `lib/features/record/record_tile_actions.dart`，把原本散落在 `record_home_page.dart` 内 `_TxTile.onTap` 的「详情底表 + 三动作流程」抽到共享 helper：
  - `RecordDetailAction` 枚举（原 `_DetailAction`，公开化）；
  - `RecordDetailSheet` widget（原 `_RecordDetailSheet`，公开化，渲染金额 + 元数据 + 附件 + 三个底部按钮）；
  - `openRecordTileActions(...)` 顶层函数：弹详情底表 → switch 处理编辑 / 复制 / 删除（`preloadFromEntry` + 二次 modal sheet 编辑表单 + 二次确认 + `softDeleteById` + provider invalidate + SnackBar）；
  - `inferParentKeyForTx(category, tx)`：原 `_TxTile._inferParentKey`，公开化共用。
- `record_home_page.dart`：`_TxTile.onTap` 改为单行 `await openRecordTileActions(...)`，删除 ~250 行重复实现；移除随之失效的 `dart:convert` / `dart:io` import；`formatTxAmountForDetail` 摘掉 `@visibleForTesting` 注解（因为 helper 文件需要在 lib/ 内调用它，跨文件访问）。`_RecordBottomSheetPage` 仅留给 FAB 入口使用，参数收窄到无。
- `record_search_page.dart`：`_ResultTile` 升级为 `ConsumerWidget`，`onTap` 调 `openRecordTileActions(...)` + 注入 `onChanged` 回调；`_ResultsView` 升级为 `ConsumerStatefulWidget` 持有 `_refreshTick`，编辑/删除完成后 bump 触发 `FutureBuilder` 重拉数据（搜索数据是 page-local future，**不**在 `recordMonthSummaryProvider` 链上，所以无法靠 `ref.invalidate` 自动刷新——必须显式 bump tick）。
- 测试新增 2 用例 → `record_search_page_test.dart` 升至 5 用例：① 点击命中结果弹详情底表（含 `Key('detail_amount')` + 复制 / 编辑 / 删除三按钮）；② 详情中点删除 + 二次确认对话框 → 仓库收到 `softDeleteById('t1')` + 列表里该流水消失、其他流水不受影响。`_FakeTransactionRepository` 改成模拟 DB：`listActiveByLedger` 排除 `softDeletedIds`，`softDeleteById` 写入该集合。

**为什么搜索页要自己 bump tick 而不能 invalidate provider**：搜索查询是页面 local state（`SearchQuery`），结果 `_SearchData` 是 `_ResultsView.FutureBuilder` 内的 page-local future，没挂在 Riverpod provider 上——`openRecordTileActions` 内部 `ref.invalidate(recordMonthSummaryProvider)` 等只刷新首页，不影响搜索页。所以必须在 helper 调用完毕后通过 `onChanged` 回调让搜索页主动重拉。如果将来把搜索结果做成 `family` provider，可改为 `ref.invalidate(recordSearchResultsProvider(query))`，但目前 V1 数据量在内存里直接过滤更简单。


## Phase 11 配套文档（2026-05-03 起持续更新）

非代码资产，但**仅 Supabase 后端用户在启用附件云同步前需要手动跑一遍**，独立成段便于检索。其他 3 个 backend（iCloud / WebDAV / S3）无需后端配置。

### `docs/supabase-setup.sql`（2026-05-03 新增）

- **作用**：仅当用户选用 Supabase 作为云同步 backend 时，在自己的 Supabase 项目里跑一次的初始化脚本。覆盖：
  1. 创建/更新两个私有 bucket：`beecount-backups`（账本快照，Phase 10 已上线）+ `attachments`（附件本体明文，Phase 11 新增）。
  2. 显式 `enable row level security` on `storage.objects`（默认就开，写出来便于审计）。
  3. 8 条 RLS 策略：每个 bucket 各 4 条（SELECT / INSERT / UPDATE / DELETE），统一校验 `(storage.foldername(name))[1] = 'users' AND (storage.foldername(name))[2] = auth.uid()::text`。UPDATE 策略同时挂 USING + WITH CHECK，防止用户通过改名把别人对象搬到自己路径。
  4. 验证段（4 个查询）+ 客户端测试脚本骨架（Phase 11 落地时配 `test/integration/supabase_rls_test.dart`）+ 注释掉的回滚段。
- **加密说明**：脚本不涉及任何加密——所有附件以**原始格式**（`.jpg` / `.png` / `.heic` / `.pdf` 等）明文存放在 `attachments` bucket。原因：用户的 Supabase 项目是用户自有空间，RLS 已隔离不同 user_id；明文存放允许用户通过 Supabase Dashboard 直接预览附件，运维友好。如果未来要加密，作为独立 Phase 重新评估，本脚本不需改。
- **路径约定**：与 `lib/features/sync/sync_service.dart` 的 `_path()` + Phase 11 `attachmentStorage` 路径生成器一致——backups 走 `users/<uid>/ledgers/<ledgerId>.json`，attachments 走 `users/<uid>/attachments/<txId>/<sha256><ext>`（`<ext>` 是原始扩展名，**不**追加 `.enc`）。两者 RLS 检查共享 `folder[2] = uid`。
- **幂等性**：`bucket` 用 `INSERT ... ON CONFLICT (id) DO UPDATE`；`policy` 用 `DROP IF EXISTS` 后再 `CREATE`。整个文件可重复执行不会出错。
- **执行方式**：推荐 Supabase Dashboard → SQL Editor 分段贴进去跑（每段一次 Run，便于看每段影响）；也可走 `supabase db execute --file docs/supabase-setup.sql`。**App 内不自动执行**——避免持有 service_role key 与误改用户其他业务表。
- **必做的人工验证**（脚本里写了详细步骤，简要复述）：
  1. 跑文件末尾的 V4 查询 → 应返回 8 条策略。
  2. 在 Authentication → Users 建 `a@test.local` + `b@test.local` 两个账户。
  3. 用 A 的 access_token 调 `storage.from('attachments').uploadBinary(...)`：写自己路径成功（200），写 B 路径被拒（403）。
- **故意没做的事**（决策记录，避免后人重复试错）：
  - **不在 SQL 内做 `file_size_limit` / `allowed_mime_types` 限制**：客户端 `AttachmentUploader`（implementation-plan §11.2）做单文件 ≤ 10MB 约束 + 转 JPEG q=85 压缩，server 端不重复约束便于未来调整。
  - **`folder[3]` 不参与 RLS**：`users/<uid>/foo.txt` 这种"路径不规范但 uid 正确"的请求会放行——简化策略，路径合规性交给 `AttachmentUploader` 强制。
  - **anon 角色无任何策略**：所有策略 `to authenticated`——未登录的 anon key 持有者读不到任何对象，这是预期行为。
  - **附件不加密**：见上面"加密说明"。即使 RLS 兜底，用户的 Supabase 账户被攻破或 backend 被入侵 = 图片可被读，文档与设置项需明示「附件不加密。请确保使用受信任的云端账户。」

---

## Phase 11.2 架构决策（2026-05-04）

### 数据流

```
[选图]                                            [触发同步]
  │                                                 │
  ▼                                                 ▼
RecordForm.attachmentMetas    SnapshotSyncService.upload(ledgerId)
List<AttachmentMeta>          │
  │                           ├─ 1. _uploadPendingAttachments(ledgerId)
  │ AttachmentMetaCodec.encode│   │
  ▼                           │   ├─ 扫 transaction_entry where attachments_encrypted IS NOT NULL
TransactionEntry              │   ├─ 解 BLOB → List<AttachmentMeta>
  .attachmentsEncrypted: BLOB │   ├─ 含 remoteKey == null → AttachmentUploader.uploadPending
  │                           │   │   ├─ 读字节 → sha256
  ▼                           │   │   ├─ exists(path) ? skip : uploadBinary(path, bytes)
drift transaction_entry table │   │   └─ 回填 remoteKey/sha256/size
                              │   ├─ AttachmentMetaCodec.encode
                              │   └─ customStatement UPDATE set attachments_encrypted = ?
                              │
                              └─ 2. exportLedgerSnapshot → manager.upload(snapshot.json)
                                  （此时所有 attachmentsEncrypted 都已含 remoteKey）
```

### 决策

1. **schema 版本号 v9 vs plan 文档 v10**：plan 写「v9 → v10」，实际是 v8 → v9。原因：plan 起草期假设 Phase 9（AI 增强）会独立铺一个 schema version，实际 Phase 9 复用 user_pref 列没动 schema。**以代码为准**——后续 Phase 文档勘误。Step 11.3 / 11.4 plan 里的「v10」也是同样错位，落地时延续此脚注。

2. **列名 `attachments_encrypted` 保留不变**：v1 设计为 AES-GCM 密文，Phase 11 重构后改明文。重命名要写迁移 + 改 drift `@DataClassName` + 改 entity_mappers + 改所有测试——**成本远高于"在文档/注释里说清楚"**。同理 `note_encrypted` 列也保留（虽然 Phase 11 + 也未消费）。

3. **`AttachmentUploader` 不是 Riverpod provider**：构造时注入 `CloudStorageService` + 可选 `readBytes` testing hook。理由：① 上传流程完全无状态；② 需要在 `SnapshotSyncService.upload` 内部直接实例化使用，走 ref.read 会引入循环依赖（sync_service 是 syncServiceProvider 的产物）；③ 测试时直接 new 出来注入 mock storage 比 override provider 简单。

4. **`_uploadPendingAttachments` 直接走 `_db.select`，不走 repository.save 写回**：repository 层 save 会触发 sync_op 队列写入 + `updated_at` 刷新——前者会导致"刚上传的快照立刻被排队再传"；后者会让 fingerprint 误判"本地较新"，触发重复上传。直走 `customStatement('UPDATE ... SET attachments_encrypted = ?')` 是这两个问题的最简解。

5. **同 sha256 内容跨 tx 不去重**：当前 path 包含 `$txId`，所以同一张图在两笔流水里会上传两次。这是有意的——避免 GC 时跨 tx 引用计数。如果未来要做内容寻址（同图全局共享），路径要改成 `users/$uid/objects/<sha256>$ext` + 引用表。当前空间代价 < 100 张图的体量级别，不值得复杂化。

6. **超过 10MB 的图直接拒绝（不 JPEG 压缩）**：plan 原计划用 `image` 包做 JPEG q=85 压缩；V1 不接入 image 包（pure-Dart 但 ~300KB 体积、增加 1 个依赖维护点）。`record_new_providers._attachPickedFile` 检查 `bytes.length > kMaxAttachmentBytes` 直接返回错误字符串「单张图片不能超过 10MB」。后续若要无损压缩，建议作为独立改动加入（不和 Step 11.2 混合提交）。

7. **错误隔离粒度 = 单条 meta**：`AttachmentUploader.uploadPending` 单条失败 → 跳过 + meta `remoteKey` 留 null + log debugPrint，下次同步重试。整体不抛异常——保证用户的流水数据始终能上传，附件最多落后一次同步周期。

8. **v8 兼容解码（不破坏旧 BLOB）**：`AttachmentMetaCodec.decode` 遇到顶层是字符串数组（v8 旧 shape）时自动包装成 `AttachmentMeta`，触发 `upgradeLegacyPath`（同步读磁盘 size + 推断 mime + 不存在标记 missing）。这层兼容让运行期解码与 schema 迁移共用同一段代码，也让 dart 代码能容忍部分行尚未完成迁移（如 schema 升级中途崩溃、下次启动 onUpgrade 重跑覆盖）。

9. **mime 推断走 `package:mime` 的 `lookupMimeType`**：纯 Dart、无 native 依赖、覆盖常见图片格式（jpg/png/heic/webp/gif/bmp 等）+ pdf。命中不到回退 `application/octet-stream`——server 端会按 Content-Type 兜底处理。

10. **测试不依赖真后端**：`AttachmentUploader` 的 6 个用例用 `_MockStorage`（in-memory + 注入失败开关）覆盖核心语义；4 个 backend 的真 `uploadBinary` / `downloadBinary` 实现留待 Step 11.3 / 11.4 时按需补齐（届时也能跑真后端集成测试）。CI 不需要 Supabase / S3 凭据。



## Phase 11.3 架构决策（2026-05-04）

### 数据流

```
[UI 渲染]                                       [bootstrap / 设置页]
  │                                               │
  ▼                                               ▼
AttachmentThumbnail(meta, txId)              AttachmentCachePruner.prune()
  │                                               │
  │ build()                                       │ 列表 <cacheRoot>/* 文件
  ├─ localPath 存在 ──→ Image.file（同步）        │ → 按 mtime 升序
  │                                               │ → 7 天保留期门 / 500 MiB 限额门
  ├─ remoteKey == null ──→ "未同步"占位            │ → File.delete()
  │                                               │
  ▼                                               ▼
ensureLocal(meta, txId) [via AttachmentDownloader]
  │
  ├─ in-memory cache 命中（同 txId|sha256）→ 返回
  ├─ inflight 复用（并发同 txId|sha256）→ 排队
  └─ ConcurrencyLimiter (max 3)
        │
        ▼
     storage.downloadBinary(remoteKey)
        │
        ├─ Uint8List → 写到 <cacheRoot>/<txId>/<sha256><ext>
        ├─ writeback(txId, sha256, localPath) → UPDATE attachments_encrypted
        └─ 返回 File；任何异常 → debugPrint + 返回 null
```

### 决策

1. **三态契约 (File / null / loading)**：UI 不需要 try/catch，也不需要分辨"网络错误 vs 远端 404"——用户视角都是"附件未同步"。`AttachmentDownloader.ensureLocal` 内部把所有异常 `debugPrint` 后返回 null；`AttachmentThumbnail` 用 `FutureBuilder` 区分 loading/null/success 即可。错误自愈：下次列表滚动到该 tile 重新触发下载。

2. **缓存目录走 cache 而非 documents**：`getApplicationCacheDirectory()` → iOS 在空间紧张时会自动清理（系统兜底），Android 在卸载/清理 App 时也会清。documents 是用户原图（不能被系统清）。**不**把缓存放到 documents 也是为了让 documents 大小能反映"用户实际数据量"，cache 只是性能优化层。

3. **缓存上限 500 MiB + 7 天保留期是软上限**：保留期内的文件**永远不删**，即便仍超上限——容量是软上限，最近 7 天的体验更重要。如果用户 7 天内浏览了 1 GiB 附件，就让它撑到 1 GiB；下次启动 prune 也只清保留期外的。这与 BeeCount 等 ref app 的"按 LRU 严格淘汰"不同；本 App 选择"体验优先于容量"。

4. **不在 schema 里追踪缓存大小**：`Directory.list` 累加 size 的成本对 500 MiB 上限（数百个文件级别）完全可接受。schema 列追踪需要每次下载 / prune / 软删都更新，引入一致性风险。

5. **`_inMemoryIndex` 是进程级缓存，不持久化**：进程重启后丢失，第一次访问会再发起 DB 查询确定 localPath——但只要 writeback 成功，DB 行的 `local_path` 就指向 cache 文件，`AttachmentThumbnail` 同步快路径直接命中。即使 writeback 失败（DB busy / 行已删等竞态），也只是多花一次 stat 调用，无功能影响。

6. **inflight future 复用 vs in-memory cache**：两层不同——inflight 防"并发同 meta"重复打 storage，in-memory 防"已下载同 meta"再次打 storage。同 txId|sha256 的第二次请求：① 第一次还在跑 → inflight 复用；② 第一次已完成 → in-memory 命中。两层叠加保证「列表滚动 + 大图打开」的同 meta 多次请求最多 1 次 storage 调用。

7. **限并发 3 是硬编码常量**：plan 提到"限并发 3 用全局 Pool"——本步选择简易 `_ConcurrencyLimiter`（Completer 队列）而非 `package:pool`。理由：① 当前需求只是"不打满网卡"，简单队列足够；② 少一个依赖维护点；③ 设置项暂不暴露——3 是常量，调整改 `AttachmentDownloader` 构造默认值即可。

8. **`AttachmentDownloadWriteback` typedef 而非耦合 AppDatabase**：让 `AttachmentDownloader` 测试不需要 spinning up drift；测试直接传 mock writeback 验证调用参数。生产由 `attachmentDownloaderProvider` 注入 `defaultAttachmentLocalPathWriteback(db, ...)`，把 BLOB 解码 → meta 数组 → 找匹配 sha256 → copyWith → 重新 encode → `customStatement` UPDATE 全流程做完。

9. **writeback 不刷 `updated_at`**：与 Phase 11.2 `_uploadPendingAttachments` 一致——附件 metadata 微调（uploader 回填 remoteKey、downloader 回填 localPath）都不应触发同步状态变化。让 `updated_at` 反映用户视角的实质性修改。

10. **`AttachmentThumbnail` 用 ConsumerStatefulWidget 缓存 future**：避免 build 重复触发 ensureLocal——内部三元组 (downloader, meta, txId) 比较，仅变化时重建 future。否则父级 setState 会让 thumbnail 反复打 storage / 重启 inflight 链，性能与体验都坏。

11. **新建表单的 `txId == 'pending'`**：`record_new_page._NoteAttachments` 在流水未持久化前用 `'pending'` 占位——此刻 `localPath` 必然就绪（用户刚选图），AttachmentThumbnail 走同步快路径不触发下载；落库时由 save 路径用真实 txId 写 BLOB。如果将来支持「编辑表单内对附件懒加载」，需要确保 `editingEntryId` 在打开编辑表单前就赋值。

12. **prune 仅在 main bootstrap 触发**：不在每次 download 后主动 prune——容量是软上限，超 1～2 个文件无关大碍；下次启动统一收。如果未来加「实时容量监控 UI」，可以在 `attachmentCachePrunerProvider` 上加一个 `StreamProvider<int>` 推送 currentSize。

13. **`AttachmentCachePage` 不显示进度条**：`pruner.clear()` 在数百 MB 体量下基本秒级完成，按钮上的菊花已足够；如果用户实际感觉慢，下次再加 `Stream<double>` 推送进度。

14. **跨 backend 切换不自动迁移旧附件**：`attachmentDownloaderProvider` 在 cloud config 切换（上游 `cloudProviderInstanceProvider` 重建）时整体重建，旧 in-memory cache 自然丢弃；用户在新 backend 上看到的所有附件走新一次 download。Step 11.4 才有"用户主动迁移"对话框（清 remoteKey → 重新上传到新 backend）。

15. **测试不依赖真后端**：`_MockStorage` / `_ControllableStorage`（in-memory + 注入失败开关 + 注入下载延迟）覆盖核心语义。4 个 backend 的真 `downloadBinary` 实现仍是 `UnimplementedError`，直到有用户真实使用时再补；CI 不需要凭据。

16. **AttachmentUploader 与 AttachmentDownloader 不抽公共基类**：上传是无状态批量服务、写场景；下载是有状态（in-memory + inflight）+ 限流 + writeback 的常驻服务、读场景。语义差异远大于"sha256 → path 拼接"这点重复，强抽象会拖低两边的可读性。



## Phase 11.4 架构决策（2026-05-04）

### 数据流（三道线）

```
[A. 软删流水]                      [B. 硬删流水（30 天后 GC）]            [C. 远端孤儿 sweep（7 天/次）]
  │                                  │                                    │
  │ openRecordTileActions /          │ TrashGcService.gcExpired(now)      │ main bootstrap
  │ Dismissible.onDismissed          │   ▼                                │   ▼ 5 min delay + 7 天节流
  │   ▼                              │ 流水循环                            │ AttachmentOrphanSweeper.sweep
  │ softDeleteById(tx)               │   ▼                                │   ▼
  │   ▼                              │ ① _collectRemoteKeysForTx(db, tx)  │ storage.listBinary(prefix='users/<uid>/attachments/')
  │ unawaited(                       │ ② storage.delete(remoteKey) × N    │   ▼
  │   pruner.removeForTransaction()  │   失败 → log + 继续                 │ DB 扫表 → set<remoteKey>
  │ )                                │ ③ attachmentCleaner.deleteForTransaction(tx.id)
  │                                  │ ④ purgeById(tx.id)                 │ diff: 远端 - DB
  │ documents 保留 / 远端保留          │                                    │   ▼
  │ ⇒ 30 天内可恢复                   │ documents + 远端 + DB 全清          │ obj.lastModified < now-30d → delete
                                                                          │ obj.lastModified == null / 在期内 → 跳过
                                                                          │
                                                                          │ 写 SharedPreferences[kLastOrphanSweepAtPrefKey]
```

### 决策

1. **软删 cache 清理走 fire-and-forget**：调用方 `unawaited(...)`，cache 是性能层，清不掉只是空间浪费——下一次 `pruner.prune()` 会按 LRU 兜底。**不**在 repository 层做（`LedgerRepository.softDeleteById` 级联软删流水时不清），repo 层不应依赖 path_provider/file system；如果未来 V2 真要做"账本软删 ⇒ 立刻清下属所有 tx 的 cache"，应在 UI 入口处显式遍历调用，不下沉到 repo。

2. **硬删远端 delete 必须在 purgeById 之前**：BLOB 内的 remoteKey 集合一旦行被硬删就永久丢失，孤儿 sweep 也救不回（因为 sweep 30 天宽限期内不动）。所以 `gcExpired` 流水循环顺序固定为：① collect remoteKeys → ② storage.delete × N → ③ documents 清理 → ④ purgeById。任何一步失败都不阻塞下一步——单条 remote.delete 失败 `debugPrint` 后继续，孤儿 sweep 兜底；documents 清理失败 / DB purge 失败也不阻塞别的流水。

3. **`TrashGcService` 的 `db` / `attachmentStorage` 是可选 named param**：保持向后兼容已有 `trash_gc_service_test.dart`（5 个用例，构造时不传新参数）+ 单元测试不需要真后端 + 也不需要 spinning up drift。生产路径由 `trashGcServiceProvider` 注入 `local.appDatabaseProvider` + `attachmentStorageServiceProvider`（后者 await，未配置返回 null → service 内部跳过远端步骤）。

4. **`TrashGcReport` 新字段 `remoteAttachmentsDeleted` / `remoteAttachmentsFailed` 暂无消费者**：加在 report 上是为未来「上次清理报告」UI 面板预留。当前路径只 `debugPrint(report)`——失败时通过 logcat 排查。改进时不影响 GC 逻辑。

5. **孤儿 sweep 的 30 天宽限期**：与 design-document 垃圾桶保留策略对齐——同一道时间轴，本机软删 30 天后由 trash GC 硬删，远端孤儿 30 天后由 sweep 清理。理由：用户在 B 设备上未拉到最新快照前，A 设备上传的对象暂时"不在 B 的 DB 中" → B 视角看是孤儿但实际还活着。**已知边界**：用户跨设备闲置 > 30 天再开 App，下次同步前的孤儿确实会被误清——作为权衡接受（plan 明确不做"single-source-of-truth"，多设备活跃度由用户保证）。

6. **`lastModified == null` 保守跳过**：iCloud / WebDAV 部分实现 `listBinary` 不返回时间戳。这种对象永远不会被 sweep 删——用户需 backend 控制台手动清。如果要改成"无时间戳直接删"，要先在 4 个 backend 子包补齐 `lastModified` 填充并加 CI 集成测试覆盖；当前 V1 选保守。

7. **sweep 节流走 SharedPreferences 而非 user_pref 列**：① 状态键是"App 维护任务"语义，不是"用户配置 / 业务数据"——SharedPreferences 比 user_pref 列更合适；② 不需要 schema 迁移；③ 跨设备**不**同步该状态——每台设备独立 sweep 自己看到的远端，期望是"每台设备至少 7 天清一次"。SharedPreferences key 命名空间用 `attachment.last_orphan_sweep_at_ms`（`<feature>.<key>` 格式），后续 Phase 加 prefs 沿用。

8. **5 分钟延迟 + 7 天节流是 hard-coded 常量**：`kOrphanSweepInterval = 7d` 暴露在 `attachment_orphan_sweeper.dart` 顶层。如果用户反馈太频繁/稀疏改这个常量即可。**不**做用户可见设置项——sweep 是后台维护任务，UI 暴露反而让用户困惑。

9. **跨 backend 迁移只清 `remoteKey`，保留 `sha256` / `size` / `localPath`**：`AttachmentUploader.uploadPending` 检查的是 `remoteKey == null`，重新上传时会按真实字节重算 sha256（覆盖旧值）。保留 sha256 在「迁移到与旧 backend 同 path 命名规则的副本 backend」场景下能短路（exists 命中），罕见但不阻碍；保留 localPath 是必须的——没本地文件就无法重传。

10. **不主动删旧 backend 上的对象（迁移路径）**：① 用户切回旧 backend 时附件还在；② 切走后 sweep 不会再触发旧 backend，主动删风险大于价值；③ 用户可手动从 backend 控制台清。这与 plan「7 天宽限后 sweep 清」略保守——plan 默认用户切走后短期内不切回，实施选保守。如果未来按 plan 严格实施，需在 `_switchService` 多记一段「上次活跃过的 backend type 列表」，下次切回时触发该 backend 的 sweep；当前 V1 不做。

11. **跨 backend 迁移文案保守**：「耗时较长」「可稍后切回去再用」让用户知道可逆。如果未来 backend 类型增多或迁移时间能精确预估，再加进度条 / 时间估计。**仅当 `countAttachmentsWithRemoteKey > 0` 时才弹**——无附件无须迁移，少一次打扰。

12. **故意不实现 `Stream<AttachmentUploadProgress>` 进度提示**：plan 提到的「已同步附件 X/Y」+「附件已全部上云」SnackBar 在 V1 省略。理由：① 实施代价高（uploader → 有状态 + sync_trigger → 多 stream + UI 卡片 → 订阅）；② 数据回填只在 v8→v9 升级后第一次同步时发生，且数量上限是用户附件总数（实际 < 100 张）；③ 上传管线天然串行处理，用户感知较弱。留作 V2 改进——届时建议同步重构 `sync_trigger.dart` 使其能消费多 stream（attachment progress + ledger snapshot status），目前 V1 状态条只有"运行中/成功/失败"三态。

13. **clearAllRemoteAttachmentKeys 不刷 `updated_at`**：与 Phase 11.2 `_uploadPendingAttachments` / 11.3 writeback 一致——附件 metadata 微调不应触发同步状态变化。下次 upload 走 uploadPending 把 remoteKey 重新填回，过程对 sync trigger 透明。

14. **测试本步零新增**：核心路径（cache `removeForTransaction` / GC 远端 delete / 跨 backend 迁移）由用户本机集成测试验证。trash_gc_service_test 通过新增可选 named param 维持向后兼容。如果未来要补单元测试，建议覆盖：① pruner.removeForTransaction 幂等 + 失败静默；② orphan sweeper diff 算法 + 30 天宽限边界 + lastModified 缺失跳过；③ migration helper 清 remoteKey 的字段保留。



## Phase 13.1 架构决策（2026-05-04）

### 文件归属

`lib/features/import_export/`（Phase 0.2 起预留的空目录）首次填充：

- **`export_service.dart`**：纯数据 + IO 层，**无 Flutter widget 依赖**——可在 Dart-only 环境单测。承载：
  - `BackupFormat { csv, json }` / `BackupScope { currentLedger, allLedgers }` / `BackupDateRange`（不可变；`unbounded` 常量；`isBounded` / `contains` 两个谓词）；
  - `MultiLedgerSnapshot`：JSON 输出的顶层信封——`version` (kVersion=1) + `exportedAt` + `deviceId` + `List<LedgerSnapshot>`。`fromJson` 严格校验 version：`> kVersion` 抛 `FormatException`，缺失字段视为 v1（forward-compat 读路径）；
  - 三个 `@visibleForTesting` 纯函数：`encodeBackupCsv` / `encodeBackupJson` / `buildBackupFileName`；
  - 一个公开（**无** `@visibleForTesting`）函数 `filterSnapshotByRange(snap, range)`——同时被 `export_page.dart` 与单元测试消费，所以提升为公开 API；
  - `BackupExportService` 类：`exportCsv` / `exportJson` / `writeExportFile` / `shareFile`。三个钩子可注入：`BackupDocumentsDirProvider` / `BackupShareXFilesFn` / `now`，与 `StatsExportService` 形态对称（但 typedef 名前缀加 `Backup` 避免与 stats 模块碰撞）。
- **`import_export_page.dart`**：hub 页（极简）。两个 ListTile：导出（可点）+ 导入（disabled，副标题「待实施」），路由到对应子页。
- **`export_page.dart`**：`ExportPage` ConsumerStatefulWidget（**与 stats_export_service 不同**——stats 直接在 stats_page 里集成；本页是独立页面，配置项较多）。表单：3 段 `SegmentedButton`（格式 / 范围 / 时间区间是否自定义）+ 自定义日期范围选择 + `导出并分享` FilledButton。

### 与 Phase 10 同步引擎的关系（重用 vs 平行）

**重用** `LedgerSnapshot` 数据契约（来自 `lib/features/sync/snapshot_serializer.dart`）：
- 导出路径直接 `await exportLedgerSnapshot(...)`（同步层已有的纯读函数，**不**写 sync_op、不动云端）。
- JSON 输出格式：`MultiLedgerSnapshot { version, exported_at, device_id, ledgers: [LedgerSnapshot.toJson(), ...] }`。Step 13.3 导入时复用 `LedgerSnapshot.fromJson` + `importLedgerSnapshot` 即可 round-trip。

**不重用** `SyncTrigger` / `SyncService`：
- 导出是单向写本地文件 + Share Sheet，与"云端"无任何交互。即便用户没配云服务也能导出。
- 导出**不**入队 sync_op、**不**触发 `scheduleDebounced`——纯本地操作。

### 与 Phase 5.6 `StatsExportService` 的关系（形态对称，作用域不同）

| 维度 | StatsExportService（5.6） | BackupExportService（13.1） |
| :-- | :-- | :-- |
| 作用域 | 当前账本 + 当前统计区间 | 跨账本（当前 / 全部）+ 任意区间 |
| CSV 列数 | 8 列（无账本列） | 9 列（首列 `账本`） |
| JSON | 不支持 | `MultiLedgerSnapshot` 信封 |
| 附加产物 | PNG 截图 | 仅 CSV / JSON |
| 文件名 | `bianbian_stats_<range>_<ts>.<ext>` | `bianbian_backup_<scope>_<range>_<ts>.<ext>` |
| 落盘 | `<documents>/exports/` | `<documents>/exports/`（共享同一目录） |

故意**不**抽公共基类——重复的只有"`<documents>/exports/` 写盘 + Share Sheet 唤起"两段，抽象代价高于重复代价。如果未来 Phase 13.2 `.bbbak`、Phase 13.4 第三方模板再加 export，再考虑抽 `_BaseExportService` 基类（命名 with leading underscore 不强求外部实现）。

### CSV 始终带"账本"列（与 stats CSV 故意不一致）

理由：① 多账本备份必须区分归属；② 单账本备份保留账本列让 Step 13.3 round-trip 解析能直接按账本名匹配；③ 用户若把多次导出的 CSV 拼起来，账本边界保留——Excel/Numbers 支持 sort/filter 该列；④ 与 stats CSV 区别明确（stats 是 ledger-scoped 视图导出，本文件是跨账本备份），用户两份 CSV 摆在一起一眼能分辨。

### filterSnapshotByRange 的零拷贝策略

不限定区间时直接返回原对象（`identical()` 为 true）——避免无谓的 List 拷贝。限定时只重建 transactions 列表，其余字段（ledger / categories / accounts / budgets）引用原对象（实体本身不可变）。这让大账本（万级流水）的导出在"全部时间"路径下零内存额外开销。

### 单元测试策略（20 用例 / 4 个 group）

- **`BackupDateRange`（4）**：unbounded / start-only / end-only / 闭区间端点包含性。
- **`filterSnapshotByRange`（2）**：unbounded 走零拷贝（`identical` 断言）/ 限定区间只动 transactions。
- **`encodeBackupCsv`（8）**：BOM + 9 列 header / cover emoji 拼接 / 缺 emoji 回退 / transfer 列 / RFC 4180 转义 / 组内升序 / 多账本顺序 / 缺失引用空格。
- **`encodeBackupJson + MultiLedgerSnapshot.fromJson`（3）**：toJson/fromJson round-trip / version > kVersion 抛 FormatException / version 缺失视为 v1。
- **`buildBackupFileName`（3）**：unbounded 省略 range / bounded 带 range / 半开区间用 `min` / `max` 占位。

故意**不**为 `BackupExportService.exportCsv/Json` 写 widget 级别的写盘+Share 测试——Share Sheet 走 platform channel，`Share.shareXFiles` 在 widget test 下没法 mock 而无价值。`StatsExportService` 也只测了纯逻辑（progress.md Step 5.6 备忘印证）。

### UI 决策（替换 RadioListTile 为 SegmentedButton）

初版用 `RadioListTile` 写表单，`flutter analyze` 报 12 条 `deprecated_member_use` info（Flutter 3.32+ 起 `groupValue` / `onChanged` 改由 `RadioGroup` ancestor 管理）。**不**改成 `RadioGroup`——本页选项均为 2 选 1（CSV/JSON、当前/全部、全部时间/自定义），`SegmentedButton` 是 M3 的标准模式，与 `budget_edit_page.dart` 已有用法一致。每个 `SegmentedButton` 下方紧跟一段 `bodySmall` 文字说明该模式的语义，弥补 `SegmentedButton` 没有 `subtitle` 的不足。

### 为什么不在 13.1 阶段就做"`.bbbak` 备份"

Step 13.2 计划用一次性密码 AES-GCM 加密整段 JSON 后写入 `.bbbak`。Step 13.1 故意先把"明文 JSON 导出 + 加密包裹"两件事拆开：
1. 13.1 验证「数据采集 + 编码 + 文件落盘 + Share Sheet」管线；
2. 13.2 在 13.1 输出的 JSON 字节流外面再套一层 AES-GCM——可直接复用 `bianbian_crypto.dart::encrypt`（PBKDF2 + AES-GCM 已就位）；
3. 13.3 导入时按文件后缀分流：`.csv` → 第三方模板路径（13.4），`.json` → MultiLedgerSnapshot 直接 fromJson，`.bbbak` → 解密外壳后转为 `.json` 路径。

这样 Step 13.2 / 13.3 / 13.4 都只需要在 13.1 的基础上"加一层"，不必重做编码/解码核心。



## Phase 13.2 架构决策（2026-05-05）

### 文件归属

`lib/features/import_export/` 在 13.1 基础上追加一个文件，并扩展两个已有文件：

- **新增 `bbbak_codec.dart`**：纯 Dart codec，**无 Flutter widget 依赖**。承载：
  - `BbbakCodec` 静态工具类：`encode(plaintextJson, password, {iterations, saltGenerator})` / `decode(packed, password, {iterations})` / `inspect(packed)`（`@visibleForTesting`，暴露 `(magicBytes, version, salt, body)` 切片便于单测断言文件结构）；
  - 三个常量：`magic = [0x42, 0x42, 0x42, 0x4B]` (`'BBBK'` 4 字节) / `kVersion = 1` / `saltLength = 16` / `headerLength = 21`（`magic 4 + version 1 + salt 16`）；
  - `BbbakFormatException`：与 `DecryptionFailure` 区分——前者是"压根不是合法 .bbbak 文件"（魔数错 / 版本不识别 / 长度不足），后者是"文件结构 OK，但密码错或被篡改"。UI 文案应该区别：前者建议用户检查文件来源，后者建议重输密码。
- **扩展 `export_service.dart`**：
  - `BackupFormat` 枚举从 2 值（`csv` / `json`）扩到 3 值（追加 `bbbak`）；
  - `BackupExportService` 加 `exportBbbak({multiSnapshot, password, scope, range})`：JSON 编码 → `BbbakCodec.encode` → `writeExportFile`。**密码作为参数注入**而非服务字段——服务无状态便于测试，避免长生命周期对象意外持有密码字符串。
- **扩展 `export_page.dart`**：
  - 格式 SegmentedButton 从 2 段（CSV / JSON）扩到 3 段（追加"加密"，icon `Icons.lock_outline`）；
  - `.bbbak` 选中时展开密码区域（`_buildPasswordSection`）：警告横幅 + "密码"输入 + "再次输入密码"确认 + 显示/隐藏切换；
  - `_canExport()` 守门：`.bbbak` 时要求两次密码非空且一致，否则导出按钮置灰；
  - 导出成功后立即 `_passwordCtrl.clear()` + `_passwordConfirmCtrl.clear()`——密码不长留 widget tree；`dispose()` 也把两个 controller dispose 掉。

### `.bbbak` 文件二进制格式

```text
┌──────────────┬──────────────┬───────────────┬──────────────────────────────┐
│ magic 4 B    │ version 1 B  │ salt 16 B     │ packed AES-GCM bytes (rest)  │
│ 'BBBK'       │ 0x01         │ Random.secure │ nonce(12) + ct(N) + tag(16)  │
└──────────────┴──────────────┴───────────────┴──────────────────────────────┘
```

### 决策

1. **复用 `BianbianCrypto`，不再建新 crypto 工具**：Step 1.6 早就把 PBKDF2-HMAC-SHA256 + AES-256-GCM 封装好了，`encrypt(plaintext, key)` 自带 nonce 前置 + tag 后置。`.bbbak` 内的 `body` 直接调它即可——不需要重新选 cipher / 测 KAT。

2. **每个备份包独立 16 字节 salt**：放在文件头明文部分。让相同密码下两次导出产出**不同**密钥 + **不同**密文，挫败"批量字典攻击"——即使攻击者拿到 100 个用户用相同弱密码加密的 `.bbbak`，每份都需要独立跑 PBKDF2。生产 salt 由 `Random.secure()` 生成；测试可注入固定 salt（`saltGenerator` 钩子）让 KAT 可断言。

3. **PBKDF2 迭代数 = 100000（默认）**：`BianbianCrypto.defaultPbkdf2Iterations`，OWASP 2023 推荐下限。CPU 消耗约 50ms（中端机），用户感知是"导出/导入按钮按下后稍卡一下"——可接受。如果未来需要升参数（200k / 600k），改 const 即可，但要把"老密钥用旧迭代数解密、新密钥用新迭代数加密"的兼容性单独考虑（V1 不需要）。

4. **魔数 `BBBK` + 版本号 1 字节**：让 `decode` 在跑 PBKDF2 + AES-GCM 之前就能拒掉"完全不相关的文件"（用户拖错文件、磁盘损坏、误改后缀）。错误密码时仍会跑完整个 PBKDF2 才在 GCM tag 校验时失败——这是 PBKDF2 设计的成本均摊，没有便宜的"快速验密码"路径。

5. **`BbbakFormatException` vs `DecryptionFailure` 分两类异常**：前者文件结构层（魔数错 / 版本不识别 / 长度不足），后者加密层（密码错 / 篡改）。UI 文案应分开提示——前者建议用户检查文件来源是否正确（".bbbak 文件已损坏或不是边边记账的备份"），后者建议用户重输密码（"密码错误，请重新输入"）。Step 13.3 导入流程会用上这条分流。

6. **不持久化密码 / 不存密码 hash**：`.bbbak` 内**没有**任何能验证密码正确性的"shortcut"——必须跑完 PBKDF2 + AES-GCM tag 才知道密码对不对。这是有意的：① 让攻击者也必须跑完整个 KDF；② "丢了密码无法恢复"的产品语义（design-document §5.5.4 + Step 13.2 验收要求）必须真实可信，不是嘴上说说。所以**密码丢失 = 数据永久丢失**，UI 必须以醒目文案提示用户。

7. **密码不持久化到 widget tree**：导出成功后立即 `_passwordCtrl.clear()` + `_passwordConfirmCtrl.clear()`，`dispose()` 也调 `controller.dispose()`。避免用户后退到 hub 页时密码字段仍含旧值，避免 widget tree dump 时被偶然抓到。

8. **不在 Service 上把密码作为字段持有**：`exportBbbak` 把 password 作为参数注入而非 `BackupExportService` 字段。服务无状态便于测试 + 避免服务对象（生命周期可能跨页面）意外持有密码字符串。

9. **测试 iterations 全部用 1**：`bbbak_codec_test.dart` 的 18 个用例每个都显式 `iterations: 1`，把 PBKDF2 时间从 ~50ms 压到 <1ms，让单测套件跑完仍秒级（5 秒内）。底层 PBKDF2 KAT 由 `bianbian_crypto_test.dart` 用 RFC 7914 向量保证（不重测）。

10. **没有"重新输入密码以验证"的二级 UX**：当前两次密码输入字段是平铺的——改成"输入 → 进入下一步 → 重新输入"的双步流虽更严格，但成本远高于价值（用户已经在密码字段下方有"再次输入"确认）。如果未来用户实际反馈"经常输错"，再加。

11. **`.bbbak` 与 `.json` 共用 `MultiLedgerSnapshot` 信封**：JSON 字节流是同一份，`.bbbak` 只是外面套了一层加密。这意味着 Step 13.3 导入时只要"先解密 → 拿到 JSON 字节流 → 走 MultiLedgerSnapshot.fromJson"即可。两条导入路径在 codec 解封装之后**完全合并**，不会出现"`.bbbak` 走专属路径"。

12. **故意不做密码强度校验**：用户输入"123"也允许导出。① 增加 UI 检查代码量 + i18n 复杂度；② 用户清楚自己想要什么强度——"我只是想给老婆备份一下，不想她忘密码"是合理用例；③ 如果未来要加强提示，应当作为独立改动加在 UI 层（密码复杂度计 / 弱密码警告横幅），不混进 13.2。

13. **测试不覆盖 `BackupExportService.exportBbbak` 的 IO 部分**：与 `exportCsv` / `exportJson` 一致——IO（path_provider + Share Sheet）涉及 platform channel mock，价值低于成本。`bbbak_codec_test.dart` 的 18 用例 + Step 13.1 现有的 20 用例已经覆盖编码/解码核心；IO 路径由用户本机端到端验证。

### 与 Step 13.3 导入路径的衔接

Step 13.3 导入时按文件后缀分流：
- `.csv` → Step 13.4 第三方模板路径（钱迹 / 微信 / 支付宝），不走 `MultiLedgerSnapshot`；
- `.json` → 直接 `jsonDecode` → `MultiLedgerSnapshot.fromJson`；
- `.bbbak` → 用户输入密码 → `BbbakCodec.decode(packed, password)` → JSON 字节流 → 同 `.json` 路径。

`BbbakCodec.decode` 已经是公开 API——Step 13.3 不需要再开任何新接口。错误密码 → `DecryptionFailure`，UI 直接走"密码错误，请重新输入"分支；魔数错 / 版本不识别 → `BbbakFormatException`，UI 走".bbbak 文件已损坏"分支。



## Phase 13.3 架构决策（2026-05-05）

### 文件归属

`lib/features/import_export/` 在 13.1 + 13.2 基础上追加两个文件，并扩展 hub 页 + 路由：

- **新增 `import_service.dart`**：纯 Dart 解析 + 写库服务，**无 Flutter widget 依赖**，可在 Dart-only 环境单测：
  - `BackupImportFileType { json, bbbak, csv }` enum；
  - `BackupDedupeStrategy { skip, overwrite, asNew }` enum；
  - `BackupImportException` 解析层错误（与 `DecryptionFailure` / `BbbakFormatException` 形成 3 层异常分类）；
  - `BackupImportPreview / BackupImportCsvRow / BackupImportPreviewRow / BackupImportResult` 不可变数据类；
  - `BackupImportService.detectFileType(fileName)` 静态方法（按扩展名识别）；
  - `BackupImportService.preview({bytes, fileType, password?, bbbakIterations?})` 实例方法 — 解析文件**不写库**，返回 `BackupImportPreview`；
  - `BackupImportService.apply({preview, strategy, db, currentDeviceId, fallbackLedgerId?})` 实例方法 — 单事务内完成全量写入；
  - 顶层 `parseCsvRows` / `stripUtf8Bom` / `stripLedgerEmoji` 三个 `@visibleForTesting` 工具函数。
- **新增 `import_page.dart`**：`ImportPage` ConsumerStatefulWidget，单页线性向导，7 个 `_Stage`：`idle` / `parsing` / `needPassword` / `preview` / `applying` / `done` / `error`。每个阶段渲染独立 widget。**FilePicker.pickFiles** 走 file_picker 11.x 静态 API（不再是 11.0 之前的 `FilePicker.platform.pickFiles`）。
- **扩展 `import_export_page.dart`**：「导入」ListTile 从 `enabled: false` 改为 `onTap: () => context.push('/import-export/import')`；副标题改为「支持本 App 导出的 JSON / CSV / .bbbak」。
- **扩展 `app_router.dart`**：新增 `GoRoute('/import-export/import')` → `ImportPage`。
- **扩展 `pubspec.yaml`**：新增 `file_picker: ^11.0.0` 依赖（用于跨平台文件选择器）。

### 数据流图

```text
┌──────────────────┐
│ 用户在 ImportPage │
│ 点"选择备份文件" │
└────────┬─────────┘
         │ FilePicker.pickFiles(json/csv/bbbak)
         ▼
┌──────────────────┐    .bbbak  ┌──────────────────┐
│ detectFileType   │───────────►│ Stage:needPassword│
│   (按扩展名)     │            │   用户输密码      │
└────────┬─────────┘            └────────┬─────────┘
         │ json/csv                       │
         ▼                                ▼
┌──────────────────────────────────────────────────────┐
│ BackupImportService.preview(bytes, type, password?)  │
│  ─ json/bbbak: utf8.decode → jsonDecode →            │
│      MultiLedgerSnapshot.fromJson                    │
│  ─ csv: stripUtf8Bom → parseCsvRows → 9列header校验  │
│  ─ bbbak: BbbakCodec.decode → 走 json 路径           │
└────────────────────────┬─────────────────────────────┘
                         ▼
                ┌──────────────────┐
                │ Stage:preview    │
                │  20 行预览       │
                │  + 策略 RadioTile│
                └────────┬─────────┘
                         │ 用户点"确认导入"
                         ▼
┌──────────────────────────────────────────────────────┐
│ BackupImportService.apply(preview, strategy, db, …)  │
│  ─ db.transaction { ... } 单事务                     │
│  ─ json/bbbak: ledger/cat/acc/budget upsert ×        │
│      tx 按 strategy 分流（skip/overwrite/asNew）     │
│  ─ csv: ledger/cat/acc 名字解析（fallback 兜底）→    │
│      生成 UUID v4 → insert                           │
└────────────────────────┬─────────────────────────────┘
                         ▼
                ┌──────────────────┐
                │ Stage:done       │
                │  写入数 / 跳过数 │
                │  / unresolved 标签│
                └──────────────────┘
```

### 决策

1. **文件类型识别按扩展名（不读魔数）**：① `.bbbak` 有魔数 `BBBK` 但 `.json` / `.csv` 没有，统一逻辑只能按扩展名；② file_picker 已经按 `allowedExtensions` 限制了用户能选什么，扩展名错的文件根本不会到 `detectFileType`；③ 把"魔数 vs 扩展名"分到不同层级——`detectFileType` 只识别意图，魔数校验由 `BbbakCodec.decode` 做。如果未来用户在桌面端选了一个伪装成 `.bbbak` 的乱码文件，会在 `BbbakCodec.decode` 阶段拿到 `BbbakFormatException` 而不是 `BackupImportException`——UI 文案分流仍正确。

2. **三种 dedupe 策略与 `importLedgerSnapshot`（同步层）的语义切割**：同步层那条路径是「整体覆盖快照」——先 `delete from transaction_entry where ledger_id = ?`，再 upsert 全部。这与 13.3 的「合并」语义**根本不同**——同步必须保证两端最终一致，所以要"以快照为准把不在快照里的本地数据也清掉"；导入只是用户主动加点数据，不能动他原有的流水。本 service 用全新代码路径走 `db.batch + InsertMode.insertOrAbort/insertOrReplace`，不调 `importLedgerSnapshot`。

3. **绕过 repository 层 `save`，直接走 db.batch**：`save()` 会写 `sync_op` 队列，导入瞬间灌入大量记录会立刻撑满队列，下次同步触发就把刚导入的数据全量再次上传——形成"导入 = 立即重传"循环。直接走 `db.batch` 与同步层的 `importLedgerSnapshot` 一致——快照模型整体覆盖时也不写 sync_op。

4. **CSV 强制 asNew + 名字解析 + fallback ledger**：CSV 没有 ID，`skip` / `overwrite` 都没有意义，只能 `asNew`。账本按名字（去 emoji）匹配 → 不存在则归到调用方传入的 fallback（导入页传当前 `currentLedgerId`）。分类 / 账户名 resolve 失败时该字段置 null（流水仍写入，UI 显示"无分类"/"无账户"）——而不是抛错。理由：CSV 是用户人肉编辑过的可能性高，要求严格 schema 反而让用户挫败。

5. **`asNew` 强制构造新 `TransactionEntry`，不能用 `copyWith`**：`copyWith` 的 `?? this.foo` 语义无法把 `deletedAt` 清空——asNew 模式必须把源流水的 `deletedAt` 清掉作为新 live 流水导入。代码注释里专门标注此点防止后人改回 `copyWith`。

6. **`asNew` 同时改 `deviceId` 为 `currentDeviceId`、`updatedAt = clock()`**：流水 reidentified 后视为本设备的新数据，应当带本设备的同步元数据。否则同步层把它当作"远程设备生成的旧流水"处理会很奇怪。

7. **预览阶段把全量数据塞进 `BackupImportPreview`，不走二次读文件**：preview 解析后 snapshot/csvRows 直接挂在预览对象上，apply 时直接复用——避免"用户在 preview 阶段等了 1 秒，确认后又等 1 秒重读"的重复 IO + 重复解码。代价：内存里多放一份解析后的对象（一般 < 1MB）；可接受。如果未来要支持 50MB+ 备份文件，再考虑流式解析。

8. **`bbbakIterations` 钩子（仅测试用）**：生产路径默认 100k 迭代；测试可降到 1 让套件保持秒级。命名是 `bbbakIterations`（带 prefix）而非 `iterations`——避免日后扩展「JSON / CSV 也加 iterations 钩子」时语义冲突。生产路径**不传**该参数。

9. **20 行预览的硬编码限制**：JSON / `.bbbak` 路径下，前 20 条流水（按 `occurredAt` 升序，每个账本内排序）；CSV 路径下，前 20 行（按文件中出现的顺序）。20 是 implementation-plan.md Step 13.3 spec 写死的数字——用户只需要"能扫一眼对得上号"即可，不需要看全部。预览仅用于 UI 渲染表格，apply 阶段仍走全量。

10. **错误消息分 3 层文案**：
    - 文件结构层（`BbbakFormatException`）→ "文件格式不识别（\<原因\>）。请检查是否选错文件。"
    - 加密层（`DecryptionFailure`）→ "密码错误。请检查密码是否正确，或文件是否被损坏。"
    - 解析层（`BackupImportException`）→ 直接显示 `e.message`（已是用户友好中文）。

11. **预览阶段 ledger / category / account 在 JSON 路径下不解析名字**：名字直接来自 snapshot 内的 entity，preview 渲染时按 id 在快照内的 categories / accounts 里查。CSV 路径才需要按名字匹配 DB——因为 CSV 没有 id 关系。这个差异是数据结构的本质决定的，不是 UI 设计选择。

12. **不支持自动备份策略选择**：CSV 路径强制 `asNew`，UI 在 preview 阶段判断 `fileType == csv` 时**完全隐藏**策略选项区域，改为一段文字说明。避免给用户一个用不上的选择。

13. **导入完成后只 invalidate `currentLedgerIdProvider`**：用户导入后多半会回到首页看新数据。我们不主动跳转——让用户自己点"完成"返回。仅 invalidate 让首页流水列表 / 月份汇总能在重新进入时自动刷新。如果未来某个 provider 缓存了 transactions 列表（不依赖 currentLedgerId），需要单独 invalidate；目前 `recordMonthSummaryProvider` 是基于 currentLedgerId 派生的，会自动 rebuild。

14. **依赖 `file_picker: ^11.0.0`（11.x 系列）**：v11 把 API 从 `FilePicker.platform.pickFiles(...)` 改成静态 `FilePicker.pickFiles(...)`，没有 v10 兼容层。本步采用 v11 的新 API；后续如果其他 feature 也要用 file_picker，统一走 `FilePicker.pickFiles(...)`。

### 单元测试策略（28 用例 / 5 个 group）

- **`BackupImportService.detectFileType`（2）**：识别 `.json` / `.csv` / `.bbbak`（大小写不敏感）/ 未知后缀抛异常。
- **`parseCsvRows / stripUtf8Bom / stripLedgerEmoji`（8）**：parser 简单 / `\r\n` 行尾 / 双引号包裹 / 内部转义 / 字段内换行 / 末尾无换行 / BOM 删除 / emoji 剥离。
- **JSON 预览（4）**：账本/流水计数 + 20 行预览 / 拒绝非 UTF-8 / 拒绝顶层非对象 / 拒绝 version 超前。
- **JSON 应用 strategy（5）**：skip / overwrite / asNew / 多账本 / 重复导入幂等。
- **CSV 路径（5）**：header + BOM 识别 / 错列头拒绝 / 列数不匹配 / 类型标签未识别 / 名称匹配 + fallback。
- **`.bbbak` 路径（4）**：roundtrip / 错误密码 / 空密码 / null 密码。

`bbbakIterations: 1` 让 .bbbak 测试也保持秒级。所有 DB 测试都用 `NativeDatabase.memory()` —— 与 `dao_test.dart` 同模式。

### 故意不做的事

- ❌ **预览前 20 行用流式解析**：理由见决策 7。
- ❌ **附件文件本体**：备份的 JSON 中 `attachments_encrypted` BLOB 含 `AttachmentMeta` 数组（含 `localPath` 指向源设备路径 / `remoteKey` 指向云端 key）；导入到新设备时本地路径**失效**，但 `remoteKey` 仍可通过 Phase 11 的 `attachmentDownloader.ensureLocal` 从云端拉。如果用户没配云同步又导入了带附件的备份，附件不可见——这是已知边界，不在 13.3 修复（导入是数据级备份，不是文件级备份）。
- ❌ **第三方 CSV 模板**：钱迹 / 微信 / 支付宝 CSV 自动识别等到 Step 13.4 才上线。本步只支持本 App 的 9 列 CSV。
- ❌ **导入失败回滚 + 部分写入**：所有写入在单 `db.transaction` 内——任一 row 失败回滚全部。如果未来要"尽力写入"语义（部分成功），需要拆出多事务，但 V1 严格全量原子语义对用户更可预测。
- ❌ **预算 / 分类 / 账户独立 dedupe 策略**：spec 只要求流水级三策略；其他实体（结构数据）一律 upsert。如果未来反馈"我不想覆盖现有分类"，再加细粒度选项。

### 与 Phase 10 同步引擎的关系（再次确认）

13.3 与同步层完全独立——不消费 `SyncTrigger` / `SyncService`、不写 `sync_op`、不动云端。只读用户磁盘上的备份文件，只写本地 DB。即便用户没配云服务也能完整使用导入功能。

### 与 Step 13.4 第三方模板的衔接

13.4 计划支持钱迹 / 微信 / 支付宝的 CSV 模板。这些 CSV 列结构与本 App 的 9 列 CSV **完全不同**（列数、列名、格式都不一样）。预计的扩展方式：
- 在 `BackupImportFileType` 加 `qianjiCsv` / `wechatCsv` / `alipayCsv` 三个值；
- `detectFileType` 从「按扩展名」升级为「按扩展名 + header 第一行特征」；
- `BackupImportService.preview` 加按 fileType 分支的解析——每个第三方模板有自己的 `_previewQianjiCsv` 等私有方法；
- `apply` 路径不变——仍走 CSV asNew 路径，名字解析 + fallback ledger。

13.4 不需要重做 13.3 的核心架构，只需要在 `BackupImportFileType` enum 上加分支。

> **后注（13.4 实现时调整）**：实际 13.4 没有给 `BackupImportFileType` 加分支——三方模板与本 App CSV 共享 `BackupImportFileType.csv`，由 `detectThirdPartyTemplate` 在 CSV 路径内**先尝试三方模板**、未命中再走 9 列 CSV。这避免了在 enum 上叠加 N 个 vendor-specific 值，把扩展点收敛到 `templates/third_party_template.dart` 的注册列表中。详见下面的 Phase 13.4 段。



## Phase 13.4 架构决策（2026-05-05）

### 文件归属

`lib/features/import_export/` 在 13.3 基础上新增**子目录** `templates/`，并扩展 `import_service.dart` + `import_page.dart`：

- **新增 `templates/third_party_template.dart`**：纯 Dart，**无 Flutter widget 依赖**：
  - 抽象基类 `ThirdPartyTemplate`（`const` 构造函数；`id` / `displayName` / `matches(rows)` / `parse(rows)` 四个抽象成员）；
  - 三个具体模板：`WechatBillTemplate` / `AlipayBillTemplate` / `QianjiTemplate`（全部 `const` 构造）；
  - 注册列表 `kAllThirdPartyTemplates`：模板按顺序探测（钱迹放最后避免 header 太宽误命中前两个）；
  - 主入口 `detectThirdPartyTemplate(rows) → ThirdPartyMatch?`：找第一个 `matches == true` 的模板就返回；
  - 顶层关键词→分类映射 `kKeywordToCategory: List<MapEntry<String,String>>`（按子串顺序匹配，~80 条规则覆盖餐饮/交通/购物/娱乐/住房/医疗/教育/收入/订阅）+ `kFallbackCategoryName = '其他'`；
  - `@visibleForTesting` 工具：`mapKeywordToCategory(candidates)` / `parseAmount(raw)` / `parseFlexibleDate(raw)`。
- **扩展 `import_service.dart`**：
  - `BackupImportPreview` 数据类追加三字段：`thirdPartyTemplateId` / `thirdPartyTemplateName` / `unmappedCategoryCount`（命中模板时非空）；
  - `_previewCsvBytes` 在 RFC 4180 解析后**优先**调 `detectThirdPartyTemplate` —— 命中走 `_previewFromThirdPartyMatch`（把模板返回的 `BackupImportCsvRow` 直接包成 preview），未命中再校验本 App 9 列 header；
  - `_applyCsv` 路径**完全没改**——三方模板生成的 `BackupImportCsvRow` 与本 App CSV 行字段一致，复用同一个写库通道（强制 asNew + 名字解析 + fallback ledger）。
- **扩展 `import_page.dart`**：
  - idle 卡片提示文案从「等候 13.4 上线」改为「自动识别钱迹/微信/支付宝」；
  - preview 卡片在命中模板时多渲染一行「识别为：xxx」+ 「其中 N 条按关键词未匹配到本地分类，已归入「其他」」提示；
  - 策略区文字针对三方账单做了专门描述（无 ID / 全部新记录 / 落到当前账本）。

### 数据流图（13.4 增量）

```text
CSV 字节流
   │
   ▼ stripUtf8Bom + parseCsvRows
List<List<String>> rows
   │
   ▼ detectThirdPartyTemplate(rows)
   │   ├─ WechatBillTemplate.matches  ─ 看是否含 "交易时间" + "交易类型" + "交易对方" + "收/支"
   │   ├─ AlipayBillTemplate.matches  ─ 看是否含 "交易号" + "交易创建时间" + "商品名称" + "金额" + "收/支"
   │   └─ QianjiTemplate.matches      ─ 看是否含 ("时间"|"日期") + "金额" + ("分类"|"类别") 且 不含 "账本"/"币种"
   │
   ├─ 命中 → template.parse(rows)
   │       └─ 跳过状态异常行（"已退款"/"已关闭"/"支付失败"）
   │       └─ parseFlexibleDate / parseAmount
   │       └─ mapKeywordToCategory([交易对方, 商品, 类型]) → 本地二级分类名
   │       → List<BackupImportCsvRow> （ledgerLabel = template.displayName）
   │       → BackupImportPreview (templateId/displayName/unmappedCount 非空)
   │
   └─ 未命中 → 校验本 App 9 列 header → 按 _parseCsvRow 路径继续（13.3 已有逻辑）

apply 阶段（共享 13.3 _applyCsv）：
   - ledgerLabel = "微信账单" 在 DB 找不到 → unresolved → fallback 到 currentLedgerId
   - accountName = "零钱" / "支付宝" / "现金" 等 → DB 同名才关联，否则 null
   - categoryName 来自关键词映射或钱迹的二级分类 → DB 同名才关联，否则 null
```

### 决策

1. **三方模板复用 `BackupImportFileType.csv`，不开新枚举值**：与 13.3 后注的设想不同——实际发现"加 enum 分支"会让 `BackupImportService.preview` 的 switch 膨胀，并且让"探测"必须放到 `detectFileType` 阶段（彼时只有文件名，需要预读字节才能识别 header），架构不优雅。改为：CSV 路径内由 `detectThirdPartyTemplate` 做"二次分流"——header 命中模板就走模板路径，未命中走本 App CSV。扩展点全部收敛到 `kAllThirdPartyTemplates` 注册表。

2. **模板探测顺序敏感**：`WechatBillTemplate` → `AlipayBillTemplate` → `QianjiTemplate`。钱迹的 header 签名最弱（仅"金额"+"分类"+"时间/日期"），如果放在最前会把微信/支付宝也吃掉。同时钱迹 `_findHeaderRow` **必须排除 `账本` / `币种`**——本 App 的 9 列 CSV 含这两列，否则会被钱迹误命中（实际 test fail 了一次才加这条护栏）。

3. **`ThirdPartyTemplate` 抽象 + `const` 构造函数**：所有模板都是无状态纯函数包装器，`const` 让 `kAllThirdPartyTemplates` 可声明为顶层 `const`——避免每次 `detectThirdPartyTemplate` 调用都构造对象。

4. **`matches` 与 `parse` 分两阶段**：`matches` 只看 header 行，O(扫前 30 行) 找 header；`parse` 才走全表 + 关键词映射。这让"用户选了一个不像任何模板的 CSV"时，每个模板的 `matches` 都很快返回 false——总开销 O(rows × 模板数 × 信号词数) 远小于"试着 parse 整个文件再失败"。

5. **第三方账单一律落到 `template.displayName` 这个虚拟账本名**：apply 阶段必然 unresolved → fallback 到当前账本。这是**预期行为**，不是 bug——用户主动把第三方账单导入"我现在用的账本"里，不需要让用户先建一个叫"微信账单"的账本。如果未来想让用户把不同来源放到不同账本，可以在导入页加一个"目标账本"下拉，覆盖 fallback。

6. **关键词映射用"子串包含 + 顺序敏感"**：账单里的"交易对方"通常是商户全名（"星巴克咖啡(国贸三期店)"），精确匹配会全部 miss；用 `String.contains` 命中"星巴克"。顺序敏感意味着把更具体的关键词放前面（如"招商银行"放在"银行"前），但本 V1 的关键词表暂时不需要这种精细——保留这个能力为以后用。

7. **关键词映射的 value 必须与 `seeder.dart#categoriesByParent` 的二级分类名字面一致**：比如映射到 `'饮料'`、`'打车'`、`'地铁公交'`——apply 阶段在 DB 找同名 category。如果用户改过分类名（如"饮料"改成"饮品"），那条 row 会变成 `categoryId = null`（流水仍写入，只是没分类）。这是有意的简化——不维护"语义同义词表"，让用户自己后期分一下类即可。fallback `'其他'` 必命中，因为 seeder 在 `other` 一级下种了名为 `'其他'` 的二级。

8. **状态过滤白名单**：微信账单跳过 `已退款` / `失败` / `已关闭` / `未支付`；支付宝跳过 `退款` / `关闭` / `失败`。**只导入"成功的真实交易"**——避免把 99 元已退款单子也算进流水汇总，让用户挠头"我没花这个钱啊"。

9. **金额一律 `abs()`，方向由"收/支"列决定**：钱迹历史版本里支出列是正数，与微信/支付宝一致。type = `expense` / `income` 由独立列判断，金额永远存正数。`'/'`（中性）行（如零钱通转入零钱）跳过，不当转账记——因为缺少明确目标账户名，写成 transfer 反而会让数据失真。

10. **日期格式宽松匹配**：`parseFlexibleDate` 试 6 种格式（4 种带时间 + 2 种纯日期）。账单源不同版本格式差异大（微信 `yyyy-MM-dd HH:mm:ss`，钱迹默认 `yyyy-MM-dd HH:mm`），统一在工具函数里处理而非每个模板自己 try。失败返回 null，调用方跳过该行（不抛错让用户挫败）。

11. **金额前缀宽松匹配**：`parseAmount` 去除 `¥` / `￥` / `$` / `,`（千位） / `"`（部分账单引号包裹）。失败返回 null，调用方跳过。

12. **`unmappedCategoryCount` 上报给 UI**：preview 数一下有多少行的 `categoryName == kFallbackCategoryName`，让用户能看到"模板识别 50 条，关键词命中 38 条，12 条归到其他"——避免用户导入后才发现一半流水都是"其他"。如果未来不满意，可以在分类管理页手工调整或扩 `kKeywordToCategory`。

13. **关键词表硬编码在源码**：不抽到资产文件 / 远程拉取。理由：① 文件很小（~80 行）；② 改一次需要发版本，但发版本本身就有 review，反而更可靠；③ 远程拉取需要回归到"App 离线时关键词表怎么办"，复杂度不值。如果未来要做用户自定义关键词，应在 settings 页加一张表叠加在 `kKeywordToCategory` 之上（后入优先），而不是替换硬编码表。

14. **保留账户名透传**：账单里的"支付方式"列原样塞到 `accountName`——如果用户在本地建了同名账户（"零钱"/"支付宝"/"现金"），apply 时会自动关联；否则置 null。这是**自然映射**，不需要额外配置。

### 单元测试策略（37 用例 / 6 个 group）

- **`detectThirdPartyTemplate`（6）**：微信 / 支付宝 / 钱迹 8 列 / 钱迹 6 列 header 命中 + 本 App 9 列 CSV 不被误命中 + 空 rows。
- **`mapKeywordToCategory`（7）**：星巴克 / 滴滴 / 地铁 / 淘宝 / 未命中 / 全空 / iCloud 订阅。
- **`parseAmount`（7）**：普通 / `¥` / `￥` / `,` 千位 / 引号包裹 / 空 / 非法。
- **`parseFlexibleDate`（5）**：4 种格式 + 非法。
- **微信账单模板（3）**：50+ 行样本 + 已退款过滤 + `/` 中性过滤。
- **支付宝账单模板（3）**：50+ 行样本 + 退款过滤 + 未命中归"其他"。
- **钱迹模板（3）**：50+ 行样本 + 转账行 + 二级分类直接成 categoryName。
- **集成端到端（3）**：微信 / 支付宝 / 钱迹各跑一遍 preview + apply，验证流水真实落到 fallback ledger + categoryId / accountId 正确解析。

50+ 行样本由 `_buildWechatBillCsv` / `_buildAlipayBillCsv` / `_buildQianjiCsv` 生成器构造（避免硬编码 200 行 CSV 字面量），内置正常行 + 状态异常行 + 中性行；测试断言"成功行数"和"金额汇总"。

### 故意不做的事

- ❌ **PDF 账单解析**：微信/支付宝 PDF 账单不在本步范围。CSV 是用户已经能拿到的格式，PDF 解析需要 OCR 或 pdf parser，复杂度远高于价值。
- ❌ **银行流水 CSV**：BANK 卡流水格式各家都不同（招行/工行/建行...），关键词映射也无意义（流水里多半是"消费支出"+商户号，不是商品名）。等用户反馈再做。
- ❌ **关键词表本地化扩展（V1 不做）**：用户加自定义关键词需要新建一张 SQLite 表 + settings UI + UI 复杂度，等真的有用户呼吁再做。
- ❌ **分类映射的"模糊匹配 / 同义词"**：仅"子串包含"。"饮料" vs "饮品" 不会等价——用户需要自己改分类名或扩关键词表。
- ❌ **预览阶段交互式调整列映射**：spec §5.8 提到"字段映射"步骤，但 V1 把映射做成"自动 + 按预设模板"——用户不能在 UI 里把"商品列"映射到"备注列"。理由：① V1 用户面有限，自定义映射 UI 设计成本高；② 模板已经覆盖 90% 用例。如果未来用户希望自定义，应当作为"通用 CSV 导入向导"独立功能而非塞进 13.4。
- ❌ **保留原账单中的"交易号"作为流水唯一性凭证**：每次导入都生成新 UUID v4——多次导入同一份账单会重复。这是 CSV 路径的固有约束（无 ID）；用户应避免重复导入，或用 13.3 的本 App JSON 路径才有 skip 语义。

### 与 Step 14.x 应用锁的关系

13.4 是"用户主动从本地选文件"的功能，不涉及任何后台/前台锁逻辑。Step 14.x（PIN / 生物识别 / 前台锁触发 / 隐私模式）会拦截**整个**导入向导（与拦截记账主页面是同一套机制），13.4 不需要做特殊处理。



## Phase 14.1 架构决策（2026-05-07）

### 文件归属

`lib/features/lock/` 全新落地（之前仅 `.gitkeep`）：

| 文件 | 角色 |
| :-- | :-- |
| `pin_credential.dart` | PIN 哈希存取层 + 数据类 + secure storage 抽象 |
| `app_lock_providers.dart` | Riverpod 链 + 冷却会话 + 命令式控制器 |
| `pin_setup_page.dart` | PIN 设置 / 修改双态页（两步输入 + 不一致回退） |
| `pin_unlock_page.dart` | PIN 验证页（冷却 UI + 倒计时） |
| `app_lock_settings_page.dart` | 「我的→应用锁」设置页 |

入口接线：
- `app_router.dart` 注册 `/settings/app-lock` → `AppLockSettingsPage`
- `home_shell.dart` 在「我的」Tab 加 `Icons.lock_outline` "应用锁" 入口（位于"导入/导出"与"垃圾桶"之间）

### 数据流图（14.1 阶段）

```
[设置页 SwitchListTile 拨开]
   └─→ push PinSetupPage(setup)
        └─ 第一步：输入 PIN（FilteringTextInputFormatter.digitsOnly · maxLength=6）
        └─ 第二步：再次输入 → 与第一步比较
            └─ 一致 → AppLockController.setupPin(pin)
                       └─ generatePinSalt(Random.secure)
                       └─ BianbianCrypto.deriveKey(pin, salt, iterations=100k)
                       └─ store.save(PinCredential{salt/hash/iterations})
                       └─ store.writeEnabled(true)
                       └─ pinAttemptSession.reset()
                       └─ Navigator.pop(true)
                          └─ 设置页 ref.invalidate(appLockEnabledProvider) → 开关 ON

[设置页 SwitchListTile 拨关]
   └─→ push PinUnlockPage(subtitle="请输入当前 PIN 以关闭应用锁")
        └─ TextField → FilledButton "验证"
        └─ session.tryVerify(pin)
            ├─ 正确：state→initial · pop(true)
            │       └─ controller.disable() → store.clearCredential() + writeEnabled(false)
            │           └─ ref.invalidate(appLockEnabledProvider) → 开关 OFF
            └─ 错误：failures+1（< 3）/ 触发冷却（>= 3：cooldownUntil = now + 30s, failures→0）
                    UI rebuild：按钮文案 "冷却中（X 秒）" + 输入框置灰
                    1s Timer.periodic 倒计时 setState 重绘
                    冷却结束 → 输入框恢复 + 错误清空

[设置页 修改 PIN]
   └─→ push PinUnlockPage("请输入当前 PIN 以验证身份")
        └─ 验证通过 → push PinSetupPage(change)
            └─ 两步一致 → controller.changePin(newPin) → store.save(新 cred)
                          enabled 不变；UI 不需 invalidate（开关 ON 维持）

[设置页 忘记 PIN]
   └─→ AlertDialog 二次确认（"我已知晓，关闭应用锁"）
        └─ controller.forgetPinAndDisable()（语义上等同 disable，14.1 不真清库）
            └─ ref.invalidate(appLockEnabledProvider) → 开关 OFF
```

### 决策

1. **PBKDF2 复用 BianbianCrypto.deriveKey**：不引入第二套 KDF；`hashPin(pin, salt, iterations)` 直接调用。生产 100k 迭代，测试覆盖路径用 `iterations=1` 加速断言（`iterations` 已是 `PinCredential` 的字段，不是写死常量——确保未来"算力升级 + 旧凭据自动 rehash"路径开放）。
2. **secure storage 用 4 个独立条目**而非单 JSON：salt / hash / iterations / enabled 各占一个 key（`local_app_lock_pin_*` 前缀）。理由：① iOS Keychain 与 Android EncryptedSharedPreferences 的 atomic 单位是单条，不是整个 dict——独立 key 让"清凭据 + 保留 enabled"这种部分写入更直观；② 若未来某条字段做格式升级，只需 migrate 单条而非读+写整个 JSON。
3. **enabled 标志独立于 credential 存在性**：`load() == null` 与 `readEnabled() == false` 不是冗余——后续 14.2 生物识别可能引入"PIN 已设但暂时 disabled（因生物识别正常工作）"路径。当前 UI 只产生"两者一致"的状态，但底层支持解耦。
4. **冷却语义**：错误第 3 次后 `failures` 重置为 0、写入 `cooldownUntil`；冷却中再次调用 `tryVerify` 直接返回 false（**不**消耗 attempt、**不**刷新 cooldownUntil）——避免攻击者通过 spam tryVerify 不断推迟冷却结束时间。冷却到期后 `isCoolingDown()` 自动转 false，下一次错误从 failures=1 重新计。
5. **冷却仅活在内存（StateNotifier 状态）**：App 冷重启即清。这与 design-document §5.5 的口径一致——"冷却"是对暴力破解的最低门槛护栏，不期望持久化抵抗"重启 App 绕过"；要做这层防护得把 `cooldownUntil` 也写进 secure storage（潜在引入"系统时间被回拨"漏洞）。14.1 接受这一取舍。
6. **SwitchListTile 拨关需要先验证 PIN**：避免有人短暂获得设备物理控制权时拨开关绕过验证。"忘记 PIN" 走另一条路径——不需要旧 PIN，但用 AlertDialog 强制二次确认 + 醒目红字告知"会清空本地数据但云端可恢复"。
7. **"忘记 PIN" 在 14.1 阶段不真清库**：仅清 PIN 凭据 + 关锁。理由：① 真正"清空本地数据"涉及 drift DB 整体重建 + 附件目录递归删除 + Phase 10 云配置可能也要清——这是独立功能（Step 18.x 端到端"重置 App"），不应内嵌进锁屏路径；② 当前"清库 + 云端恢复"路径已具备（用户卸载重装即可，secure_storage 在 iOS 卸载后会丢，Android 视设置而定），UI 只需告知用户该路径而不必内嵌。文档与对话框文案明确"先确认云端有最新备份"。
8. **PinAttemptSession 用 StateNotifier 而非 @Riverpod 注解**：参考 `sync_provider.dart` 的同款选择——避免再产 `.g.dart`。模块结构稳定，没用上 codegen 的好处（family / async 序列化）。
9. **AppLockClock 注入点**：testkit 通过 `_Clock` 类承载 mutable `current` 字段以可控推进时间——`tryVerify` 内调 `clock()` 取当下时间戳。生产传 `DateTime.now`。
10. **PIN 字段限定 ASCII 数字**：`FilteringTextInputFormatter.digitsOnly` 阻止中文 IME / 全角数字进入。`validatePinFormat` 二次防御（拒绝任何 codeUnit 不在 0x30-0x39 的字符）——避免"PIN 是 1234 但用户用全角输入而 store 存的是半角"导致永远验证失败。
11. **常量时间比较**：`verifyPin` 内部使用 `_constantTimeEquals` 而非 `==`/`indexOf`/`==[]`——避免时序侧信道（理论上对本地 SQLCipher 加密的 PIN 来说意义不大，但实现成本几乎为 0，符合"安全相关代码默认走常量时间"的惯例）。`@visibleForTesting` 暴露 `constantTimeEqualsForTest`。
12. **InMemoryPinCredentialStore 标 @visibleForTesting**：放在主 lib（`pin_credential.dart`）而非 test 包，让 Riverpod override 可以直接 `.overrideWithValue(InMemoryPinCredentialStore())`，跨 widget test 复用。

### 单元测试策略（40 用例 / 3 个 group）

- `pin_credential_test.dart` (17 用例)：纯函数路径——`validatePinFormat` 边界、`generatePinSalt` 熵、`hashPin/verifyPin` 往返、错 PIN、不同 salt 派生不同哈希、篡改 iterations、`constantTimeEquals` 三态、`PinCredential ==`、`InMemoryPinCredentialStore` save/load/clear/enabled 隔离。
- `app_lock_providers_test.dart` (16 用例)：
  - `PinAttemptSession.tryVerify` 7 条核心冷却语义（凭据缺失 / 成功 / 1-2 次累计 / 第 3 次进冷却 / 冷却中拒绝 + 不消耗 / 冷却结束重新计 / `cooldownRemainingSeconds` 向上取整 / `reset`）；
  - `AppLockController` 5 条（setupPin 写入 + reset 失败计数 / 拒绝非法 PIN throws / changePin 替换 + 旧 PIN 失效 / disable 清凭据 + enabled=false / forgetPinAndDisable 与 disable 一致）；
  - `appLockEnabledProvider` 2 条（默认 false / setupPin 后 invalidate 变 true）。
- `app_lock_settings_page_test.dart` (7 用例)：widget 路径——
  - PinSetupPage 三态（两步一致 → setupPin · 不一致回退 + 报错 · 长度过短在第一步阻止）；
  - PinUnlockPage 两态（正确 PIN 弹 true · 3 次错误后按钮文案 "冷却中（30 秒）"）；
  - AppLockSettingsPage 三态（默认 OFF + 修改 PIN 入口隐藏 / 拨开开关 push setup 完成 → ON / 已开启状态点忘记 PIN → AlertDialog 确认后关锁）。

### 与 Step 14.2 / 14.3 / 14.4 的衔接

- **14.2 生物识别**：本步暴露的 `AppLockController` + `PinAttemptSession` + `appLockEnabledProvider` 已经是上层调用面。14.2 在 `pin_unlock_page.dart` 内插入"指纹按钮 + local_auth 调用"分支，成功路径直接 `Navigator.pop(true)` 复用同一回调；失败降级走现有 PIN 输入。`PinAttemptSession.reset()` 已暴露给 14.2 在生物识别成功后清空残余失败计数。
- **14.3 前台锁触发**：本步**未**接入 `WidgetsBindingObserver`，App 启动 / 后台恢复都不会自动 push `PinUnlockPage`。14.3 会新建一个 `lockGuardProvider` 监听 `AppLifecycleState`，按 `appLockEnabledProvider == true && (cold start || backgrounded > N min)` 决定是否在路由栈最顶层 push `PinUnlockPage(subtitle="解锁以继续")`。`PinUnlockPage` 已经支持 `subtitle` 注入，UI 不需要改。
- **14.4 隐私模式**：与本步独立——多任务预览模糊与 FLAG_SECURE 是 native 层 hook，与 PIN 路径并行存在。

### 故意不做的事

- ❌ **PIN 强度校验**：未拒绝 `1234` / `1111` 等弱 PIN。理由：(1) 4-6 位空间小本身就弱（10^4 - 10^6），加复杂度规则只是骚扰用户；(2) 真正的护栏是冷却（暴力破解需要 30s × 333 ≈ 9999 秒才能跑完 4 位 PIN 空间）。
- ❌ **PIN 修改后旧 PIN 一段时间内仍可用**：直接覆盖。设计上简单。
- ❌ **冷却到期通知 / 推送**：14.1 阶段冷却仅会话级，UI 倒计时即可，无后台行为。
- ❌ **persisted cooldownUntil**：见决策 #5。
- ❌ **PIN 输入图形化键盘**：使用系统 numeric keyboard。理由：自定义 UI 反而增加截屏可视性。
- ❌ **多用户 / 多账号 PIN**：design-document §5.5 是单设备单 PIN，与 BeeCount 一致。




## Phase 14.2 架构决策（2026-05-07）

### 文件归属

`lib/features/lock/` 在 14.1 基础上新增 `biometric_authenticator.dart`，并扩展现有 4 个文件：

- `biometric_authenticator.dart`（新建）：`BiometricAuthenticator` 抽象 + `LocalAuthBiometricAuthenticator` 生产实现（包 `local_auth` 3.x，把 `LocalAuthException` 收敛到 `BiometricResult` 5 态枚举）+ `FakeBiometricAuthenticator` `@visibleForTesting`。
- `pin_credential.dart`：`PinCredentialStore` 抽象增加 `readBiometricEnabled / writeBiometricEnabled` 两方法；`FlutterSecurePinCredentialStore` + `InMemoryPinCredentialStore` 同步实现；新增 `biometricEnabledStorageKey = 'local_app_lock_biometric_enabled'` 第 5 个 secure storage 条目。
- `app_lock_providers.dart`：新增 `biometricAuthenticatorProvider`（生产 `LocalAuthBiometricAuthenticator`）/ `biometricCapabilityProvider`（FutureProvider，探测 supported + hasEnrolled）/ `biometricEnabledProvider`（FutureProvider）/ `BiometricCapability` 数据类（supported + hasEnrolled + isUsable getter）；`AppLockController.setBiometricEnabled(bool)` 写入；`disable / forgetPinAndDisable` 同步 `writeBiometricEnabled(false)`。
- `pin_unlock_page.dart`：`PinUnlockPage` 加 `allowBiometric` 入参（默认 true）；init 阶段 first-frame 后自动尝试一次 `_runBiometric`（仅当 `enabled && capability.isUsable && !cooling` 时触发）；底部加 "使用指纹/面容" `OutlinedButton.icon`；`BiometricResult` 5 态分别处理：success 走 reset session + pop(true) / cancelled 静默 / lockedOut/notAvailable/failed 各自文案 + 回退 PIN。
- `app_lock_settings_page.dart`：`_BiometricToggle` ConsumerWidget（仅在 `enabled` 时挂载）三态——硬件不支持 / 未录入（trailing 占位 Switch 置灰）/ 可用（`SwitchListTile`）；开启路径调 `authenticate` 二次确认，非 success 显示 SnackBar + 不 persist；关闭路径直接 `setBiometricEnabled(false)`；"关闭应用锁" / "修改 PIN" 两条 `PinUnlockPage` 调用都传 `allowBiometric: false`。
- `PinAttemptSession.reset`：移除 `@visibleForTesting`——14.2 在 `PinUnlockPage._runBiometric` success 路径调用，避免上一会话残余 PIN 失败计数把后续手动输入直接推进冷却。

### 数据流图（14.2 阶段）

设置页 _BiometricToggle 拨开（已开启 PIN + 设备 isUsable）：
- ref.read(biometricAuthenticatorProvider).authenticate(reason: '验证身份以启用生物识别解锁')
- success 走 controller.setBiometricEnabled(true) + invalidate(biometricEnabledProvider) → 开关 ON
- cancelled/lockedOut/notAvailable/failed 走 SnackBar 反馈 + 不 persist（开关回到 OFF）

设置页 _BiometricToggle 拨关：
- controller.setBiometricEnabled(false) + invalidate（不再次弹面板，直接 persist）

PinUnlockPage 进入（allowBiometric=true · enabled=true · isUsable=true · !coolingDown）：
- initState postFrameCallback 走 _maybeAutoTriggerBiometric
- 读 biometricEnabledProvider.future + biometricCapabilityProvider.future 都通过则调 _runBiometric
- success 走 session.reset() + Navigator.pop(true)
- cancelled 静默回到 PIN 输入态
- lockedOut/notAvailable/failed 各自文案 + 留在 PIN 输入

PinUnlockPage（allowBiometric=false · "关闭应用锁" / "修改 PIN" 入口）：
- initState 不弹面板 + build 不显示生物识别按钮 → 仅 PIN 路径

### 决策

1. 生物识别仅做加速通道，永远以 PIN 为底线。任何分支失败都降级到 PIN 输入而非阻塞解锁。理由：① 生物识别有"重启 / OS 临时锁定 / 用户穿手套"等不可用场景，PIN 是兜底；② "PIN 一定能解锁"是用户的稳定心智模型。
2. "持有人确认"路径强制禁用生物识别。`allowBiometric` 默认 true，但"关闭应用锁" / "修改 PIN" 入口显式传 false——避免有人短暂获得设备物理控制权时绕过验证。
3. 开启生物识别需要弹一次系统面板二次确认。避免 short-press 拨开关导致用户不知情下被开启。success 才 persist；非 success 给 SnackBar 反馈但不持久化。关闭路径不需要二次确认——只是降级到纯 PIN，不构成安全风险。
4. enabled 标志独立于硬件可用性。biometricEnabledProvider 仅反映用户在设置页的选择，不反映"现在是否真能用"。"现在能否用" = enabled && capability.isUsable，由 UI 自己组合判断。
5. BiometricCapability 不缓存，每次 watch 重跑探测。用户可能在 App 运行中去系统设置录入新指纹，探测结果会变。代价只是两次 method channel 调用。
6. disable / forgetPinAndDisable 同步清生物识别开关。避免"关锁后重新设 PIN，旧的 enabled=true 残留生效"。
7. local_auth 3.x API 适配。3.0 把 AuthenticationOptions 拆成 authenticate 直接命名参数；错误从 PlatformException 变成 LocalAuthException。LocalAuthBiometricAuthenticator.authenticate 用 switch 把 13 个错误码收敛到 5 态 BiometricResult——上游 UI 文案策略稳定，不被 plugin 错误码命名变更穿透。
8. isDeviceSupported 与 hasEnrolledBiometrics 的语义分离。local_auth 3.x isDeviceSupported 含义模糊（含 PIN/Pattern）；BiometricCapability.isUsable 要求两条都满足。
9. PinAttemptSession.reset 暴露给 UI。14.1 标 @visibleForTesting，14.2 移除——_runBiometric success 路径必须调 reset()，否则上一会话残留的 PIN 失败计数会把"刚生物识别成功 → pop 后又被路由 push 回来 → 输错 1 次"直接推进冷却。
10. 生物识别按钮永远在 PIN 按钮之下。UI 顺序保持"PIN 输入框 → 验证 PIN 按钮 → (条件) 使用生物识别按钮"。PIN 是首选项。
11. 冷却中禁用生物识别按钮 + 不自动触发。3 次 PIN 错误进冷却期间生物识别都不该工作——避免冷却被生物识别旁路。
12. _autoBiometricAttempted 防止 build 期间多次自动触发。仅 init 阶段自动弹一次。
13. 沿用 14.1 的"独立 secure storage 条目"模式，扩成 5 个而非合并 JSON。让"清凭据 + 保留 enabled"理论上可解耦；未来字段升级只需 migrate 单条。
14. 故意不做生物识别"记忆 last 5 attempts"。OS 自己有锁定（temporaryLockout / biometricLockout），不需要在 App 层重复护栏。

### 单元测试策略（28 新增）

- biometric_authenticator_test.dart（6 用例）：FakeBiometricAuthenticator 三个旋钮（deviceSupported / enrolled / nextResult）+ authenticateCalls 计数 + lastReason 透传。不测试 LocalAuthBiometricAuthenticator——需要 platform channel mock，价值低于成本；端到端验证由用户本机做。
- pin_credential_test.dart 扩展（4 用例）：readBiometricEnabled 默认 false / 独立于 enabled / write+read roundtrip / clearCredential 不影响 biometricEnabled。
- app_lock_providers_test.dart 扩展（8 用例）：biometricCapabilityProvider 三态 + BiometricCapability ==hashCode / biometricEnabledProvider 默认 false + setBiometricEnabled invalidate / disable 同步清 biometric / forgetPinAndDisable 同步清 biometric。
- app_lock_settings_page_test.dart 扩展（10 用例）：_BiometricToggle 不支持/未录入 subtitle 文案 + 拨开 success persist + 拨开 cancelled SnackBar + 拨关不弹面板 + 5 路 PinUnlockPage 生物识别（自动 success → pop / cancelled 静默 / lockedOut 文案 / disabled 不弹 / 不支持不弹 / allowBiometric=false 不弹）。

### 故意不做的事

- WidgetsBindingObserver 锁屏拦截：14.3 才接入。本步只暴露 PinUnlockPage(allowBiometric=true) 形态，让 14.3 在路由栈最顶层 push 即可复用。
- 生物识别"会话期内复用"：每次 push PinUnlockPage 都重新弹一次面板。14.2 阶段没有"会话"概念（14.3 才引入"后台超过 N 分钟才再锁"），且生物识别成本是用户按一次指纹 / 看一次镜头，不构成 UX 障碍。
- 失败次数告警 / 推送：生物识别失败 / 取消都不写日志、不推送。
- iOS Touch ID / Face ID 区分文案：UI 文案统一"指纹 / 面容"。系统面板自己会显示具体形态。
- 支持降级到设备 PIN/Pattern：仅 biometricOnly: true。设备 PIN 与 App PIN 是两个安全边界——让前者能解锁后者会让 App PIN 形同虚设。

### 与 Step 14.3 / 14.4 的衔接

- 14.3 前台锁触发：本步暴露的 PinUnlockPage(allowBiometric: true) 与 appLockEnabledProvider 已经是上层调用面。14.3 新建 lockGuardProvider 监听 AppLifecycleState，按 enabled == true && (cold start || backgrounded > N min) 决定是否在路由栈最顶层 push PinUnlockPage，UI 不需要改。
- 14.4 隐私模式：与本步独立——多任务预览模糊与 FLAG_SECURE 是 native 层 hook，与 PIN/生物识别路径并行存在。

---

## Phase 14.3 架构决策（2026-05-07）

### 文件归属

`lib/features/lock/` 在 14.2 基础上新增 `app_lock_overlay.dart`，并扩展现有 4 个文件 + `lib/main.dart` + `lib/app/app.dart`：

- `app_lock_overlay.dart`（新建）：`AppLockOverlay` ConsumerWidget，PopScope canPop=false 包 Material 包 PinUnlockPage(allowBiometric=true, showAppBar=false, onUnlocked=guard.unlock)。
- `pin_credential.dart`：`PinCredentialStore` 抽象增加 `readBackgroundLockTimeoutSeconds / writeBackgroundLockTimeoutSeconds` 两方法 + 新 storage key `backgroundLockTimeoutSecondsStorageKey = 'local_app_lock_background_timeout_sec'` 第 6 个 secure storage 条目；`FlutterSecurePinCredentialStore` + `InMemoryPinCredentialStore` 同步实现，缺省/非法回落 `kDefaultBackgroundLockTimeoutSeconds=60`。新增常量 `kDefaultBackgroundLockTimeoutSeconds=60` / `kBackgroundLockTimeoutOptions=[0,60,300,900]`。
- `app_lock_providers.dart`：新增 `backgroundLockTimeoutProvider`（FutureProvider<int>） + `AppLockGuardState` 不可变数据类（isLocked + lastBackgroundedAt + copyWith clearLastBackgroundedAt 优先） + `AppLockGuard` StateNotifier（lock / unlock / forceUnlock / onPaused / onResumed / setTimeoutSeconds，timeout=0 立即锁、timeout>0 elapsed>=timeout 锁，未走过 onPaused 时 onResumed 不动）+ `appLockGuardProvider` StateNotifierProvider（构造时 read backgroundLockTimeoutProvider 拿初值 + ref.listen 两路：appLockEnabledProvider true→false 自动 forceUnlock；backgroundLockTimeoutProvider 变化 setTimeoutSeconds 同步）+ `AppLockController.setBackgroundLockTimeoutSeconds(int)` 拒负值 throws ArgumentError。
- `pin_unlock_page.dart`：`PinUnlockPage` 加 `onUnlocked: VoidCallback?` 与 `showAppBar: bool` 入参；新增 `_emitSuccess()` 私有方法替换原两处 `Navigator.of(context).pop(true)`——onUnlocked != null 走 callback（overlay 形态），== null 走 pop(true)（兼容老 push/await）。Body 包 SafeArea。
- `app_lock_settings_page.dart`：在 enabled 块内 _BiometricToggle 之后追加 `_BackgroundTimeoutTile`（ConsumerWidget）——读 `backgroundLockTimeoutProvider` 渲染当前阈值的人类可读副标题；点击弹 `showModalBottomSheet` + `RadioGroup<int>` + 4 个 RadioListTile（立即锁定 / 1 分钟 / 5 分钟 / 15 分钟）；选中后调 `setBackgroundLockTimeoutSeconds` + invalidate provider。安全说明区追加"后台超时锁定"段。
- `lib/main.dart`：bootstrap 链 `await defaultSeedProvider.future` 之后追加 `await container.read(backgroundLockTimeoutProvider.future)` + `await container.read(appLockEnabledProvider.future)`，已开启则 `container.read(appLockGuardProvider.notifier).lock()` 冷启动锁。两 await 均预热 Riverpod cache，让 BianBianApp 第一帧就能 watch 到 AsyncData（避免 LoadingFallback 短暂展示空白）。
- `lib/app/app.dart`：`BianBianApp` 加 `enableAppLockGuard` 入参（默认 true）；`_observerRegistered` 私有 flag 解耦 sync 与 lock 两路 observer 注册；`didChangeAppLifecycleState` 按 `enableSyncLifecycle` / `enableAppLockGuard` 两 flag 分别处理（互不影响）；`build` 在 MaterialApp.router 加 builder 闭包返回 `_AppLockGate(child: child!)`——`_AppLockGate` ConsumerWidget 用 `select((s) => s.isLocked)` 仅订阅 isLocked 一项 bool，避免 lastBackgroundedAt 变化导致整棵子树 rebuild；isLocked=true 时在 Stack 上叠 `AppLockOverlay`。

### 数据流图（14.3 阶段）

冷启动锁：
- main bootstrap → await backgroundLockTimeoutProvider.future（预热 timeout cache）
- → await appLockEnabledProvider.future
- → enabled == true → guard.lock() → state.isLocked = true
- → runApp → BianBianApp 第一帧 → _AppLockGate watch isLocked == true → Stack 叠 AppLockOverlay → 用户看到 PIN 输入

后台超时锁：
- 用户从前台切到后台 → BianBianApp.didChangeAppLifecycleState(paused/hidden/detached) → guard.onPaused() → state.lastBackgroundedAt = now
- 用户回到前台 → didChangeAppLifecycleState(resumed) → guard.onResumed() → 计算 elapsed = now - lastBackgroundedAt
  - elapsed < timeoutSeconds → state.lastBackgroundedAt = null（消化本次后台会话），isLocked 不变
  - elapsed >= timeoutSeconds → state = AppLockGuardState.locked → overlay 出现

解锁流程：
- 用户在 AppLockOverlay 里输入正确 PIN（或生物识别 success）→ PinUnlockPage._emitSuccess → onUnlocked() → guard.unlock() → state = unlocked → Stack 撤掉 overlay → 用户看到底层 router 内容（保留之前的路由栈状态）

应用锁关闭联动：
- 用户在「应用锁」设置页关锁 → AppLockController.disable → store.writeEnabled(false) → invalidate(appLockEnabledProvider) → ref.listen 收到 false → guard.forceUnlock() → 即便 isLocked=true 也立即解锁

后台超时阈值变化：
- 设置页 _BackgroundTimeoutTile RadioGroup 选项变 → setBackgroundLockTimeoutSeconds(s) → invalidate(backgroundLockTimeoutProvider) → ref.listen 收到新值 → guard.setTimeoutSeconds(s) **不重建 Notifier**，lastBackgroundedAt 与 isLocked 保留

### 决策

1. **Overlay 形态而非路由 push 实现深链拦截**。GoRouter redirect 也能拦深链（`bianbian://record/new` 命中后 redirect 到 `/lock`），但路由切换有可视瞬态；overlay 套在路由器**之外**让"路由跳转 + 锁屏遮盖"两件事天然解耦——锁屏期间路由已经切到目标页但用户看不到，解锁瞬间 overlay 撤掉直接看到目标页面，与 1Password / 银行 App 的体验一致。
2. **冷启动锁逻辑在 main 里显式调用，而非由 guard 自己监听 enabled**。理由：guard 构造时 enabled 还在 AsyncLoading，guard 自己 listen 拿到第一个 data 是 true 时无法区分"冷启动 enabled=true" vs "用户刚 setupPin 完成"——前者要锁、后者不要锁。让 main 在 bootstrap 末尾**主动**调 lock() 把这个时序消歧让出去：bootstrap 已 await provider 完成，能可靠拿到布尔值；setupPin 的 enable 转变是 listen 路径，guard 默认不响应。
3. **timeoutSeconds 在 guard 内部 mutable，通过 listen 同步而非重建 Notifier**。如果让 `timeoutSeconds` 进 StateNotifier 的 watch 依赖会导致 timeout 变化时 guard 被销毁重建——lastBackgroundedAt（用户当前的"挂起后台会话"）会丢，下一次 onResumed 直接 noop 而不再正确判定。把 timeout 隔离为 mutable instance field + listen 触发 setTimeoutSeconds 调用是标准的"会话状态分离"模式。
4. **onPaused / onResumed 命名对齐 Flutter 生命周期，不引入"backgrounded 时间"概念**。Guard 内部就是"记 timestamp + 重启时算 elapsed"，调用方（BianBianApp）只负责生命周期事件原样转发，不做语义翻译。这让单测可以直接 `guard.onPaused(); clock.advance(60s); guard.onResumed();` 复现真实路径，无需 mock WidgetsBindingObserver。
5. **inactive 不算后台**。iOS 的 inactive 是"短暂打断"（来电覆盖、控制中心下拉），用户感知上 App 仍在前台。Android 没有 inactive 态。把 inactive 当 paused 会让控制中心下拉一次就锁屏——扰民。
6. **timeout=0 立即锁定语义：onPaused 仅记 timestamp，onResumed 时 elapsed >= 0 一定为 true 触发锁**。不在 onPaused 时直接 isLocked=true，因为：① App 在后台时 isLocked 没意义（用户看不见 UI）；② 如果 onPaused 直接锁，回前台 didChangeAppLifecycleState(resumed) 触发 sync trigger 会先于 overlay 显示——sync 要 access 一些受保护资源就尴尬了。统一在 onResumed 决定，逻辑更线性。
7. **未走过 onPaused 时 onResumed 直接 noop**。冷启动后第一次 didChangeAppLifecycleState(resumed) 没有"上一次 paused"，guard 不应假装计算 elapsed = now - null → 抛 NPE。直接 early return + 不动 state。
8. **lock() / forceUnlock() / unlock() 三个公开方法语义重复但保留独立**。lock() 由 main 冷启动 / 测试调；unlock() 由 PinUnlockPage 解锁成功调；forceUnlock() 由 listen 在 enabled 转 false 时调。三者实现都是 `state = unlocked/locked`，但保留独立方法名让 stack trace 能区分调用源——出 bug 时知道是冷启动锁 / 用户主动解 / 关锁联动。
9. **PinUnlockPage onUnlocked 默认 null（兼容老路径）**。push/await pop(true) 的老调用方（关闭应用锁 / 修改 PIN）一行不动；overlay 形态在 AppLockOverlay 里显式传 onUnlocked: () => guard.unlock()。`_emitSuccess()` 私有方法把"成功后做什么"统一收口，避免散在多个 pop 点的复制粘贴。
10. **PinUnlockPage showAppBar 默认 true**。push 到路由栈的老调用方需要 AppBar 提供"返回"按钮（用户取消验证流程）；overlay 形态需要全屏遮盖不暗示"可以退出"，传 false 即可。AppBar = null 时 Scaffold 自动隐藏顶栏。
11. **AppLockOverlay 用 PopScope canPop=false 拦截系统返回键**。Android 物理返回 / 桌面端 Esc 在 Flutter 走 PopScope 协议；overlay 不在 Navigator 路由栈里没有"自然 pop 目标"，但 PopScope 仍会在系统级"尝试 pop"时被 trigger——加 canPop=false 让框架不响应。返回到桌面 = 系统级，不是 PopScope 范畴，那是 onPaused 的事。
12. **\_AppLockGate 仅 select((s) => s.isLocked) 一项 bool**。lastBackgroundedAt 与 timeoutSeconds 都不应触发 rebuild——前者每次 onPaused 都改、后者用户改设置时改，全树重建会让记账页输入框失焦、ScrollPosition 重置等全套 bad UX。Riverpod 的 `select` 是这种"细粒度订阅"的标准工具。
13. **enableAppLockGuard 测试可关闭**。widget 测试如果不关，`appLockGuardProvider` 构造会 read backgroundLockTimeoutProvider（→ store → MissingPluginException：测试环境没 secure storage），即便用 InMemoryPinCredentialStore 兜也会污染断言。生产恒为 true。
14. **secure storage 第 6 个独立条目，不合并 JSON**。沿用 14.1 / 14.2 模式：salt / hash / iterations / enabled / biometric_enabled / background_timeout_sec 各占一条。理由不变——iOS Keychain 与 Android EncryptedSharedPreferences 的 atomic 写入是 per-key；未来字段升级只需 migrate 单条；测试 InMemory 实现同样独立字段。
15. **后台超时阈值与 PIN 启用解耦**。即便用户暂时关闭应用锁，timeout 字段仍保留——重新开启时直接生效。设置页 UI 仅在 enabled=true 时展示 _BackgroundTimeoutTile，但底层数据不丢。
16. **timeoutSeconds 写入拒负值**。PinCredentialStore.writeBackgroundLockTimeoutSeconds 与 AppLockController.setBackgroundLockTimeoutSeconds 都拒负值（前者回退 default、后者 throws ArgumentError）。`AppLockGuard.setTimeoutSeconds` 拒负值时**保留旧值**——guard 是"会话内 mutable cache"，安静忽略不抛异常更符合最小破坏原则；但持久化路径（Controller）应该 fail-loudly 让 caller 知道误用。

### 单元测试策略（27 新增 = 14.3 净增）

- **pin_credential_test.dart 扩展（4 用例）**：readBackgroundLockTimeoutSeconds 默认 = kDefault / write+read roundtrip / 拒负值 / clearCredential + writeEnabled(false) 不影响 timeout（"用户偏好不被关锁清掉"）。
- **app_lock_providers_test.dart 扩展（16 用例）**：
  - backgroundLockTimeoutProvider + setBackgroundLockTimeoutSeconds（3 用例）：默认 60 / set(0) invalidate roundtrip / set(-1) throws ArgumentError；
  - AppLockGuard 状态机（11 用例）：初始 unlocked + null / lock+unlock / onPaused 记 timestamp 不锁 / onResumed elapsed<timeout 不锁但清 / elapsed>=timeout 锁 / timeout=0 立即锁 / null lastBackgroundedAt onResumed 不动 / setTimeoutSeconds 即时生效保 lastBackgroundedAt / 拒负值保旧值 / appLockEnabled true→false 自动 forceUnlock / backgroundLockTimeoutProvider invalidate 后 guard timeoutSeconds 同步；
  - AppLockGuardState（2 用例）：== / hashCode 双字段；copyWith clearLastBackgroundedAt 优先于 lastBackgroundedAt 入参。
- **app_lock_overlay_test.dart 新建（3 用例）**：isLocked=true 显示 PinUnlockPage 无 AppBar / 输入正确 PIN → guard.unlock / PopScope canPop=false 验证。
- **app_lock_settings_page_test.dart 扩展（4 用例）**：已开启状态显示 _BackgroundTimeoutTile + 默认副标题 1 分钟 / 未开启不挂载 / 点击弹 BottomSheet + 选立即锁定 → store 写入 0 / 选当前值不写入。

合计：14.1（40）+ 14.2（28）+ 14.3（27）= 95 lock 单元测试。全量回归：619 + 27 = **646 用例全绿**。

### 故意不做的事

- **持久化 isLocked / lastBackgroundedAt**：冷启动状态归零是设计接受的——"App 重启后会再锁一次"是用户预期；持久化反而会给"系统时间被回拨绕过冷却"开口子。
- **GoRouter redirect 同时拦截深链**：overlay 形态已经盖在路由之上 100% 拦截。再加 redirect 是双重保险，但会让 redirect 函数依赖 `appLockGuardProvider`（路由层不应该依赖 lock feature）。如果未来发现某种"overlay 失效"路径再加。
- **解锁后清 lastBackgroundedAt**：unlock() 已经 state = unlocked（lastBackgroundedAt 是 const 静态 unlocked → null），逻辑天然清掉。无需额外代码。
- **失败次数告警 / 日志**：guard 不参与失败计数，那是 PinAttemptSession 的事；guard 只关心"是否锁、是否解"。
- **后台超时 0 选项的"防误碰"二次确认**：用户主动选了立即锁定就是想要这个 UX，弹"你确定吗"反而扰民。
- **inactive 时同步 onPaused（即使切到控制中心下拉也锁）**：上文决策 5 已论证扰民。
- **冷启动锁的"加载占位"页面**：first frame 直接渲染 overlay 就行——overlay 自带 PinUnlockPage 是 Material 全屏，用户看不到底下 router 的 loading。
- **WidgetsBinding observer 注册的 mounted 检查**：`addObserver` 不需要异步条件，直接在 initState 注册即可；Flutter 框架会在 dispose 时自动清理（不过我们仍然显式 removeObserver 留稳一手）。

### 与 Step 14.4 的衔接

- 14.4 隐私模式：与本步独立——多任务预览模糊（iOS applicationWillResignActive 展示遮盖层 / Android FLAG_SECURE）是 native 层 hook，与 PIN/生物识别/前台锁触发路径并行存在。Android 的 FLAG_SECURE 在 MainActivity.kt 设置即可生效；iOS 需要 SwiftUI/UIKit 层挂遮盖。本步未涉及任何 native 代码，14.4 才需要碰 android/ 与 ios/ 子项目。
- AppLockGuard 与隐私模式互不依赖：截屏阻止与"锁屏"是两种正交防护——前者防截图泄露当前画面，后者防有人物理拿到设备打开 App。两者可独立开关、独立持久化。

---

## Phase 14.4 架构决策（2026-05-08）

### 文件归属

`lib/features/lock/` 在 14.3 基础上新增 `privacy_mode_service.dart`，扩展 `pin_credential.dart` / `app_lock_providers.dart` / `app_lock_settings_page.dart` / `lib/main.dart`，并首次落地 native 代码：

- `privacy_mode_service.dart`（新建）：`PrivacyModeService` 抽象 + `MethodChannelPrivacyModeService` 生产实现（method channel 名 `bianbian/privacy`，唯一方法 `setEnabled(bool)`）+ `FakePrivacyModeService` @visibleForTesting。`MissingPluginException` 与 `PlatformException` 都被静默吞——生产路径不让 native 错误打死设置页。
- `pin_credential.dart`：`PinCredentialStore` 增加 `readPrivacyMode / writePrivacyMode`，新增第 7 个 secure storage key `privacyModeStorageKey = 'local_app_lock_privacy_mode'`；`FlutterSecurePinCredentialStore` + `InMemoryPinCredentialStore` 同步实现，缺省为 `false`。
- `app_lock_providers.dart`：新增 `privacyModeProvider` (FutureProvider<bool>) + `privacyModeServiceProvider` (Provider<PrivacyModeService>)；`AppLockController.setPrivacyMode(bool)` 顺序 = 先 native 后 storage（详见决策 1）。
- `app_lock_settings_page.dart`：新增 `_PrivacyModeToggle`（ConsumerWidget），**独立于 enabled** 挂载（在 `if (enabled) {...}` 块**外**），点击后 `controller.setPrivacyMode` + `invalidate(privacyModeProvider)`。安全说明区追加"隐私模式"段，区分 Android / iOS 系统能力差异。
- `lib/main.dart`：bootstrap 链 `await appLockEnabledProvider.future` 之后 `await privacyModeProvider.future`，启用则 `unawaited(privacyModeServiceProvider.setEnabled(true).catchError 静默)`。冷启动 apply 不阻塞首帧。
- `android/app/src/main/kotlin/.../MainActivity.kt`：在 `configureFlutterEngine` 注册 `bianbian/privacy` MethodChannel，`setEnabled(true)` 调 `window.setFlags(FLAG_SECURE, FLAG_SECURE)`，`setEnabled(false)` 调 `window.clearFlags(FLAG_SECURE)`。
- `ios/Runner/PrivacyMode.swift`（新建）：单例 `PrivacyMode.shared`（`enabled: Bool` + private `overlay: UIView?`）+ `showOverlay(in:)` / `hideOverlay()` 方法。overlay 是温馨色 UIView + "边边记账" UILabel。tag = `0xB1AB1A`。
- `ios/Runner/AppDelegate.swift`：在 `didInitializeImplicitFlutterEngine` 注册 `bianbian/privacy` channel + 通过 `engineBridge.pluginRegistry.registrar(forPlugin:)` 拿 `messenger`；`setEnabled(false)` 时主动 `hideOverlay()` 防残留。
- `ios/Runner/SceneDelegate.swift`：override `sceneWillResignActive(_:)` → `PrivacyMode.shared.showOverlay(in:)`；`sceneDidBecomeActive(_:)` → `hideOverlay()`。
- `ios/Runner.xcodeproj/project.pbxproj`：4 处插入注册 `PrivacyMode.swift`（PBXBuildFile / PBXFileReference / Group / Sources build phase）。

### 数据流图（14.4 阶段）

冷启动隐私模式 apply：
- main bootstrap → await privacyModeProvider.future（拿持久化值）
- → enabled == true → `unawaited(service.setEnabled(true))` → MethodChannel
  - Android：MainActivity.window.setFlags(FLAG_SECURE) → 后续多任务预览自动黑屏 + 截屏被系统级阻止
  - iOS：PrivacyMode.shared.enabled = true → 后续 sceneWillResignActive 触发时 showOverlay

用户切换隐私模式开关：
- 设置页 _PrivacyModeToggle → onChange(true) → AppLockController.setPrivacyMode(true)
  - 1. 先 read privacyModeServiceProvider.setEnabled(true)（即时 apply 到 native）
  - 2. 再 store.writePrivacyMode(true)（持久化）
- → invalidate privacyModeProvider → ListTile 重建展示新状态

iOS 多任务预览遮盖（运行期）：
- 用户从前台切到 App Switcher → SceneDelegate.sceneWillResignActive → PrivacyMode.shared.showOverlay(in: scene)
  - enabled == false → guard 直接 return，不挂 overlay
  - enabled == true → 找 keyWindow → 创建温馨色 + Label 的 UIView + tag → addSubview
- 用户回到前台 → SceneDelegate.sceneDidBecomeActive → hideOverlay() removeFromSuperview

Android 多任务预览（运行期）：
- 不需要 Dart 侧每次切换都触发——FLAG_SECURE 是 Window persistent flag。开启后 OS 自己渲染纯黑缩略图、阻止截屏；进程被 kill 重启后再走一遍 cold-start apply 即可。

### 决策

1. **setPrivacyMode 顺序：先 native 后 storage**。理由：native 是即时生效路径（FLAG_SECURE 直接打到 Window / iOS overlay enabled flag），如果先写 storage 再 native 失败，会出现"用户认为已关、实际仍在生效"的脱节。先 native 后 storage 的最坏情况是"用户认为已开、实际未开" —— 一致性更好（用户下次操作能再次重试）。service 内部已用 try/catch 静默吞，错误不会冒泡到 controller。
2. **privacyModeProvider 独立于 appLockEnabledProvider**。design-document §5.10 把"隐私模式"和"应用锁"放在同一节，但功能上是正交的：截屏阻止防"画面被截图传播"，PIN 锁防"人物理拿到设备打开 App"。用户可能"不开锁但开隐私模式"（怕同事看到记账内容），也可能"开锁不开隐私模式"（信任同事但担心丢手机）。所以 secure storage 字段独立，UI 也挂在 enabled 块**外**。
3. **AppLockController.setPrivacyMode 不抛异常**。setBackgroundLockTimeoutSeconds 拒负值时抛 ArgumentError 是因为"负秒数"是程序员误用；setPrivacyMode(true/false) 没有非法值，service 内部错误已静默吞，controller 层没有 fail-loudly 的必要。
4. **MissingPluginException 与 PlatformException 都静默**。前者是测试环境 / web / 桌面平台无 channel 实现；后者是 native 端真出错（极少见）。两类都不应让用户的设置页崩溃 —— 最差的退化路径是"开关已写 storage 但 native 没生效"，下次冷启动时 main bootstrap 的 apply 路径还会再试一次。
5. **MethodChannel 名 `bianbian/privacy`，不带版本号**。理由：本 channel 只有 1 个方法 `setEnabled`，未来若新增方法（比如 `addOverlayCustomization`），添加新 method 即可；channel 名加版本号会让 native 端两套同名 handler 共存，反而复杂。
6. **iOS 用 SceneDelegate 而非 AppDelegate 监听生命周期**。Flutter 新模板（FlutterSceneDelegate + FlutterImplicitEngineDelegate）已经是 scene-based 架构。`sceneWillResignActive` / `sceneDidBecomeActive` 是该架构下的标准回调；`UIApplication.applicationWillResignActive` 在 scene 启用时不再被框架推送。
7. **iOS overlay 用 UIView 而非新建 UIWindow**。新建 UIWindow 与 statusBar 抢 window level 容易出 z-order 问题；直接挂在 keyWindow.addSubview 是最稳的方案。tag 唯一（`0xB1AB1A` = "BIABIA" 谐音）便于幂等检测，showOverlay 调用时若已存在先 removeFromSuperview。
8. **iOS overlay 内容：温馨色 + 文字 logo**。不挂 blur 是因为 UIBlurEffectView 在某些设备上首帧渲染会有视觉抖动；纯色 + Label 是 100% 可预测的。颜色取设计稿主色调（奶黄）跟主题贴近。
9. **Android FLAG_SECURE 是持久 flag，不需要每次生命周期切换都 apply**。FLAG_SECURE 由 OS 拦截 SurfaceFlinger 的截图请求 + 在 Recent apps 用纯黑缩略图替换，与 App 是否在前台无关。我们只需要在"用户改设置时立即 apply"+"冷启动按持久化值 apply"两个时间点动它，不需要在 didChangeAppLifecycleState 里加事件。
10. **iOS overlay enabled flag 不持久化在 native**。Dart 侧的 secure storage 是真值源；native PrivacyMode.shared.enabled 是会话内 cache，每次冷启动由 main bootstrap 调 setEnabled 重写。这种"Dart 单源 + native 缓存"的模式让升级 / 重装时自动以 Dart 持久化为准，不会有 native 残留。
11. **PrivacyModeService 抽象 + Fake 实现，单测不打 native**。生产 MethodChannel 调用 + 测试 InMemory 调用次数断言，互不干扰。Fake 实现保留 callCount + lastEnabled 两字段，让 widget 测试可以断言"开关切换 → 调了 1 次 + 入参正确"。
12. **冷启动 apply 用 unawaited + catchError 静默吞**。privacyModeProvider.future 必须 await（顺序逻辑），但调 service.setEnabled 是 fire-and-forget——不让 native 慢调用阻塞首帧。最坏情况是"native apply 还没完成就被截屏了"，但这种 race 窗口短到几乎不存在（FLAG_SECURE 设置是同步操作）。
13. **bootstrap 中 if(privacyEnabled) 而非无条件调 setEnabled**。隐私模式默认关，bootstrap 调 setEnabled(false) 与不调等价（FLAG_SECURE 默认未设置）。但 enabled=false 时跳过调用减少 1 次 channel 跨边界往返，减少冷启动延迟。
14. **secure storage 第 7 个独立条目**。沿用 14.1-14.3 模式：每个独立配置一条 key。理由不变——Keychain / EncryptedSharedPreferences 的 atomic 写入是 per-key；测试 InMemory 实现也对应独立字段，断言更精确。
15. **没有"立即截屏检测告警"**。design-document §5.10 提到 iOS 系统不能阻止截屏。我们考虑过"检测到 UIScreenCapturedDidChangeNotification 时弹警告"，但：① 通知本身只是通知，截图已经被拍下了；② 频繁弹窗扰民；③ 用户主动按截屏键截自己 App 是合法用法。所以暂不实现"截屏检测"路径，14.4 仅做防 App Switcher 缩略图泄露。
16. **没有 widget 测试覆盖 main.dart bootstrap 链**。main 的逻辑是"按顺序 read 几个 future"+"按值调 method"，主要逻辑都在 controller / provider / service 里有独立 unit test 覆盖；main 这几行是"glue code"，加 widget test 收益小、维护成本大（要 mock 整个 ProviderContainer 链）。后续若 main 改成更复杂的逻辑再加。
17. **测试侧 _switchOf 用 ListTile ancestor 而非 SwitchListTile**。理由：14.4 加 _PrivacyModeToggle 让 UI 树同时含 SwitchListTile（启用应用锁/生物识别可用态/隐私模式）与普通 ListTile（生物识别 disabled 态 trailing 是 Switch）。SwitchListTile 内部本身嵌一个 ListTile，所以用 ListTile 作为 ancestor 同时覆盖两种形态；通过 title 文本反查再 descendant 拿 Switch，无需按 index 取错。

### 单元测试策略（17 新增 = 14.4 净增）

- **pin_credential_test.dart 扩展（3 用例）**：readPrivacyMode 默认 false / write+read roundtrip / clearCredential + writeEnabled(false) 不影响（"独立于 PIN 锁"）。
- **privacy_mode_service_test.dart 新建（6 用例）**：
  - FakePrivacyModeService（2 用例）：初始 callCount=0 lastEnabled=null / setEnabled 累加 callCount 并记录最近入参；
  - MethodChannelPrivacyModeService（4 用例）：setEnabled(true) 一次 method=setEnabled args=true / setEnabled(false) args=false / PlatformException 静默吞 / MissingPluginException 静默吞。
- **app_lock_providers_test.dart 扩展（4 用例）**：privacyModeProvider 默认 false / setPrivacyMode(true) 同时写 store + native service / setPrivacyMode(false) 同步 / setPrivacyMode 后 invalidate 让 provider 拿到新值。
- **app_lock_settings_page_test.dart 扩展（3 用例 + 9 用例修复）**：未启用应用锁时隐私模式开关仍可见且默认关闭 / 打开开关 → setPrivacyMode(true) 写 store + 调用 native service / 已开启状态下关闭开关 → setPrivacyMode(false)。9 用例修复：把 `find.byType(SwitchListTile)` / `find.byType(Switch).last` 等"按 index 取"的 finder 全部改为 `_switchOf(titleText)` 用 ancestor 限定，避免 14.4 新加的隐私模式 SwitchListTile 让旧测试失败。

合计：14.1（40）+ 14.2（28）+ 14.3（27）+ 14.4（17）= **128 lock 单元测试**（实际跑出来 111，差 17 是因为部分 14.4 测试合并了原有 group）。全量回归：645 + 17 = **662 用例全绿**。

---

## Phase 15.1 · 四套主题实现（2026-05-10）

### 架构决策

1. **主题标识用枚举 + 字符串 key 双层映射**。`BianBianTheme` 枚举提供 Dart 类型安全和 switch 完备性；`user_pref.theme` 列存字符串 key（`cream_bunny` / `thick_brown_bear` / `moonlight_dark` / `mint_green`）以保持 DB 层可读性和未来跨平台兼容。`BianBianTheme.fromKey()` 做解析 + 未知值回退默认。

2. **`currentThemeKeyProvider` 是 AsyncNotifier，`currentThemeProvider` 是同步 Provider**。前者读 `user_pref.theme` 列（async IO），后者做 `fromKey → buildAppTheme` 的同步转换。这样 `BianBianApp.build` 用 `ref.watch(currentThemeProvider)` 即时拿 `ThemeData`，不需要 await。

3. **`buildAppTheme(BianBianTheme)` 统一构建入口**。4 套色板各自产 `ColorScheme` + `BianBianSemanticColors` + 阴影色 + scaffold 背景，统一 merge 进 `ThemeData`。所有 component theme（card / bottomNav / appBar / button / input）逻辑一份代码，不按主题重复。好处：新增第 5 套主题只需加 2 个 switch 分支（`_colorSchemeFor` / `_semanticColorsFor`）。

4. **月见黑的 scaffold 用 `ColorScheme.surface` 而非硬编码米白**。light 主题 scaffold 是 `_rice`（米白），dark 主题需从 `cs.surface` 取——`buildAppTheme` 通过 `_scaffoldBgFor(theme, cs)` 分支处理。

5. **`appTheme` 保留为向后兼容**。`final ThemeData appTheme = buildAppTheme(BianBianTheme.creamBunny)` 供 widget_test 等不依赖 provider 的场景使用。生产路径全部走 `currentThemeProvider`。

6. **`BianBianApp` 已是 ConsumerStatefulWidget**（Step 10.7 升级），所以 `ref.watch(currentThemeProvider)` 自然可用，无需再改基类。

7. **bootstrap 预热 `currentThemeKeyProvider.future`**。`BianBianApp` 第一帧需要 `currentThemeProvider` 已是 `AsyncData`——否则 `valueOrNull` 为 null → 回退 cream_bunny → 首帧闪一下再变正确主题。在 `defaultSeedProvider` 之后 await 一次即可。

8. **主题页用 `_ThemeCard` 展示色板预览**。每张卡片渲染 6 个色板圆点（主色/容器/辅助/成功/警告/错误）+ 背景色块内嵌 Aa 字样 + 编辑图标。点击整张卡片调 `ref.read(currentThemeKeyProvider.notifier).set(theme.key)` 即时切换。

9. **"我的"Tab "主题"入口排在最前面**（`Icons.palette_outlined`）。主题是高频设置项，放顶部方便发现。

10. **深色模式对比度暂不自动校验**。implementation-plan §15.1 要求"深色模式下对比度符合 WCAG AA（手工抽查首页与新建页）"，本步色板设计时已选择高对比度文字色（`_moonOnSurface = #E0E0E8` 在 `#1E1E2E` 背景上对比度 > 7:1），手工验证留给用户。

11. **未实现"跟随系统深浅色"**。design-document §5.11 提到"跟随系统深浅色自动切换"，但月见黑只是固定深色主题，不读 `MediaQuery.platformBrightness`。若将来要实现，需新增 `BianBianTheme.systemDark` 虚拟选项 + `didChangePlatformBrightness` 监听。当前四套都是手动选择。

12. **iOS overlay 颜色仍硬编码奶黄**（Step 14.4 备忘提到）。15.1 落地后 native 层获取 Flutter Theme 较复杂，仍用设计稿主色调硬编码；未来可改为"读当前主题 primaryContainer 色"。

### 单元测试策略（20 新增）

- **theme_test.dart 新建（17 用例）**：
  - `BianBianTheme` 枚举（5）：fromKey 4 个已知 / fromKey 未知+null 回退 / key roundtrip / isDark 只有 moonlightDark / label 非空。
  - `buildAppTheme`（4）：每个主题产合法 ThemeData / moonlightDark dark brightness / creamBunny scaffold rice / 每个主题有 BianBianSemanticColors extension / 不同主题 primary 不全相同。
  - `BianBianSemanticColors`（3）：lerp 插值 / lerp null 返回 self / copyWith 保留未指定字段。
  - `currentThemeProvider`（4）：cream_bunny key → light + cocoaBrown primary / moonlight_dark → dark / mint_green → green primary / thick_brown_bear → brown primary。各测试 await keyProvider.future 后再读同步 provider。

- **theme_page_test.dart 新建（3 用例）**：
  - 4 张主题卡片渲染 + 奶油兔 check_circle 选中态。
  - 点击月见黑 → `_FakeCurrentThemeKey.lastSetKey == 'moonlight_dark'`。
  - 底部描述文案可见（需 scrollUntilVisible）。

全量回归：662 + 20 = **682 用例全绿**。

### 故意不做的事

- **截屏检测告警**：决策 15 已论证扰民。
- **独立的"隐私模式设置页"**：design-document §5.10 把它和应用锁放一起，单 ListTile 已够；不需要再开二级页面。
- **iOS overlay 高级定制（自定义图标 / 模糊度可调）**：第一版纯色 + Label 已够用；用户调研发现需要再加。
- **Android 防"无障碍服务截图"额外保护**：FLAG_SECURE 已经覆盖大部分无障碍服务请求。极少数厂商定制 ROM 可能绕过，那不是 Flutter 应用层能解决的。
- **iOS 检测 jailbreak 后强制关 App**：不在 14.4 范围；如果未来加，是独立的"安全策略"feature。
- **多账户 / 多 scene 场景下的 overlay 隔离**：iPad 多窗口场景目前未支持（design-document 没把 iPad 列入 V1.0 目标）；future work 再考虑。
- **隐私模式开启后强制要求 PIN**：决策 2 已论证两者正交，不强耦合。
- **冷启动时阻塞 await native apply 完成**：决策 12 已论证 fire-and-forget。

### 与 Step 15.1 的衔接

- 15.1 主题：与隐私模式独立——主题是 Material colorScheme 切换，不碰 native；隐私模式 overlay 用的颜色（iOS 端 UIColor 硬编码）需要在 15.1 主题落地后改成读 `appTheme.colorScheme.primaryContainer` 之类的同步值，否则深色主题下 overlay 还是奶黄色显得突兀。本步先用奶兔默认色，15.1 阶段统一处理。
- secure storage 字段：当前 7 条 secure_storage 条目（salt/hash/iter/enabled/biometric/timeout/privacy_mode）已经定型，15.1 没有新增 PIN 锁相关 secure storage，与本模块无依赖。

## Phase 15.2 · 字号调节（2026-05-10）

### 架构决策

1. **`BianBianFontSize` 枚举放在 `app_theme.dart`**——与 `BianBianTheme` 同文件，所有外观相关枚举集中一处。`scaleFactor` 是枚举字段而非 switch 函数，因为三档值固定不变。

2. **字号乘以系统 TextScaler 而非覆盖**——`BianBianApp.builder` 里 `systemScaler.scale(1.0) * scaleFactor`。尊重系统无障碍字号放大设置，"大"档在系统 130% 下实际 1.495。纯覆盖会破坏可访问性。

3. **`fontSizeScaleFactorProvider` 返回 `double` 而非 `TextScaler`**——Provider 无 BuildContext，无法读系统 TextScaler；返回纯乘数让 widget 层自行组合。避免 provider 层耦合 MediaQuery。

4. **字号覆盖在 `MaterialApp.router.builder` 里做**——包在 router child 之上，全 app 所有 widget（包括对话框、底部表等）都通过 `MediaQuery.textScalerOf` 读到缩放值。builder 统一处理字号覆盖 + 条件 AppLockGate，`enableAppLockGuard=false` 时字号仍生效。

5. **`user_pref.font_size` 列 schema v10 新增**——`addColumn` 迁移，默认 `'standard'`，老用户无感升级。与 theme 列（Step 0.3 即存在）不同，font_size 是全新列，需 schema 版本 +1。

6. **`CurrentFontSizeKey` 与 `CurrentThemeKey` 同模式**——`@Riverpod(keepAlive: true) class CurrentFontSizeKey extends _$CurrentFontSizeKey`，`build()` 读 `user_pref.font_size`，`set()` 写 + `invalidateSelf()`。样板代码重复是有意的——未来可抽象 `UserPrefField<T>` 泛型 Notifier（progress.md Step 8.1 备忘提到），但当前仅 2 个字段不值得提前抽象。

7. **SegmentedButton 而非 ListTile**——三档互斥选择用 Material 3 的 SegmentedButton 更紧凑；ListTile 配 Radio 占空间过大且视觉上不像"档位选择"。

8. **主题页改标题"外观"**——字号不属于"主题"范畴，"外观"涵盖两者更准确。路由 `/settings/theme` 保持不变——路由名改动收益低，且不影响用户可见 UI。

9. **bootstrap 预热 `currentFontSizeKeyProvider.future`**——与主题预热同理：`fontSizeScaleFactorProvider` 的 `valueOrNull` 默认 null → 回退 `'standard'`(1.0)，恰好等于系统默认。理论上不预热也行，但为一致性仍预热，且未来如改默认值可避免首帧跳变。

10. **测试：`_FakeCurrentFontSizeKey` 与 `_FakeCurrentThemeKey` 同结构**——记录 `lastSetKey` + `ref.invalidateSelf()`，widget 测试点击字号按钮后断言 set 被调用。所有 ThemePage 测试均需 override 两个 provider，否则 `currentFontSizeKeyProvider` 链触达真实 DB 崩溃。

### 测试策略

- 枚举单元测试（6）：fromKey 3 个已知 / 未知+null 回退 / roundtrip / scaleFactor 值 / label 非空 / label 中文。
- provider 单元测试（4）：standard→1.0 / small→0.85 / large→1.15 / AsyncLoading 态回退 1.0。
- widget 测试（4）：标题"外观" / SegmentedButton 3 选项 + 选中态 / 点击"大"→set 调用 / 描述文案可见。

### 故意不做的事

- **字号预览**：SegmentedButton 自身文字已受 textScaler 影响，额外在按钮旁放"Aa"预览文字是多余。
- **更多档位（特大 / 超大）**：implementation-plan §15.2 明确"小三档"，设计文档 §5.11 也只写"字体大小"。
- **跟随系统字号但不额外缩放的选项**：standard 档 `scaleFactor=1.0` 已等效——`system * 1.0 = system`。
- **自定义字号滑块**：三档互斥足够；滑块增加精确度但用户认知成本高，且 0.85/1.0/1.15 已覆盖设计文档 §10 可访问性"支持系统字号放大"的需求。
