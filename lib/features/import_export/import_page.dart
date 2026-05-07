import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/bianbian_crypto.dart';
import '../../data/local/providers.dart' as local;
import '../../data/repository/providers.dart';
import 'bbbak_codec.dart';
import 'import_service.dart';

/// 导入向导页（Step 13.3）。
///
/// 单页线性流程（4 stage）：
/// 1. **选择文件**：唤起 `FilePicker`（限 .json / .csv / .bbbak）；
/// 2. **解密 / 解析**：`.bbbak` 选中后弹密码字段；JSON / CSV 直接解析；
/// 3. **预览 + 策略**：显示文件元数据 + 前 20 行表格 + 去重策略选项；
/// 4. **应用**：调用 [BackupImportService.apply] 写库 → 显示结果统计。
///
/// **不**复用 `ImportExportPage` hub——hub 极简，本页承担完整向导。
///
/// 安全考量：`.bbbak` 密码用局部变量保存，应用结束/页面销毁时立即清空 controller。
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  /// 当前向导阶段。
  _Stage _stage = _Stage.idle;

  /// 用户选中文件的元数据。
  PlatformFile? _pickedFile;
  BackupImportFileType? _pickedType;

  /// 文件二进制内容（一次读完，避免 IO 阶段反复读）。
  Uint8List? _bytes;

  /// 预览结果——`_Stage.preview` 之后非空。
  BackupImportPreview? _preview;

  /// 用户选中的去重策略（仅 JSON / `.bbbak` 路径生效）。
  BackupDedupeStrategy _strategy = BackupDedupeStrategy.skip;

  /// 应用结果——`_Stage.done` 之后非空。
  BackupImportResult? _result;

  /// 用户可见错误文本——`_Stage.error` 时显示，其他阶段为 null。
  String? _errorText;

  /// `.bbbak` 密码输入（仅 `_Stage.needPassword` 时使用）。
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _passwordObscured = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('导入')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildStage(context),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    switch (_stage) {
      case _Stage.idle:
        return _buildIdle(context);
      case _Stage.parsing:
        return const Center(child: CircularProgressIndicator());
      case _Stage.needPassword:
        return _buildNeedPassword(context);
      case _Stage.preview:
        return _buildPreview(context);
      case _Stage.applying:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('正在写入数据库…'),
            ],
          ),
        );
      case _Stage.done:
        return _buildDone(context);
      case _Stage.error:
        return _buildError(context);
    }
  }

  // ─── Stage 1: idle ────────────────────────────────────────────────────

  Widget _buildIdle(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('支持的文件格式', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const _BulletLine(text: 'JSON：本 App 导出的结构化备份（推荐）'),
                const _BulletLine(text: '.bbbak：本 App 导出的加密备份（需要密码）'),
                const _BulletLine(text: 'CSV：本 App 导出的表格（按账本名匹配）'),
                const _BulletLine(text: '第三方账单：钱迹 / 微信 / 支付宝 CSV（自动识别）'),
                const SizedBox(height: 12),
                Text(
                  '提示：第三方账单会被识别为单一账本，自动归入当前账本；分类按关键词推测，'
                  '不能命中的归到「其他」。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('选择备份文件'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'bbbak'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        return; // 用户取消，保持 idle
      }
      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        _showError('文件路径不可读');
        return;
      }
      final BackupImportFileType detected;
      try {
        detected = BackupImportService.detectFileType(file.name);
      } on BackupImportException catch (e) {
        _showError(e.message);
        return;
      }
      // 读字节
      final bytes = await File(path).readAsBytes();
      setState(() {
        _pickedFile = file;
        _pickedType = detected;
        _bytes = bytes;
      });

      if (detected == BackupImportFileType.bbbak) {
        // .bbbak 需要密码——切到密码输入阶段
        setState(() => _stage = _Stage.needPassword);
        return;
      }
      await _runPreview(password: null);
    } catch (e) {
      _showError('选择文件失败：$e');
    }
  }

  // ─── Stage 2: need password (.bbbak) ──────────────────────────────────

  Widget _buildNeedPassword(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('已选择：${_pickedFile?.name ?? ""}',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline,
                    color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '此文件已加密。请输入导出时设置的密码。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          obscureText: _passwordObscured,
          decoration: InputDecoration(
            labelText: '密码',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_passwordObscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _passwordObscured = !_passwordObscured),
              tooltip: _passwordObscured ? '显示密码' : '隐藏密码',
            ),
          ),
          onSubmitted: (_) => _onPasswordSubmit(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetToIdle,
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _passwordCtrl.text.isEmpty ? null : _onPasswordSubmit,
                child: const Text('解密并预览'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onPasswordSubmit() async {
    final pw = _passwordCtrl.text;
    if (pw.isEmpty) return;
    await _runPreview(password: pw);
  }

  Future<void> _runPreview({required String? password}) async {
    final bytes = _bytes;
    final type = _pickedType;
    if (bytes == null || type == null) {
      _showError('内部状态错误：缺少文件字节或类型');
      return;
    }
    setState(() => _stage = _Stage.parsing);
    final service = BackupImportService();
    try {
      final preview = await service.preview(
        bytes: bytes,
        fileType: type,
        password: password,
      );
      setState(() {
        _preview = preview;
        _stage = _Stage.preview;
      });
    } on DecryptionFailure {
      _showError('密码错误。请检查密码是否正确，或文件是否被损坏。');
    } on BbbakFormatException catch (e) {
      _showError('文件格式不识别（${e.message}）。请检查是否选错文件。');
    } on BackupImportException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('解析失败：$e');
    }
  }

  // ─── Stage 3: preview + strategy ──────────────────────────────────────

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview!;
    final isCsv = preview.fileType == BackupImportFileType.csv;
    final isThirdParty = preview.thirdPartyTemplateId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  icon: Icons.description_outlined,
                  label: '文件',
                  value: '${_pickedFile?.name ?? ""}'
                      ' · ${_typeLabel(preview.fileType)}',
                ),
                if (isThirdParty)
                  _SummaryRow(
                    icon: Icons.auto_awesome,
                    label: '识别为',
                    value: preview.thirdPartyTemplateName!,
                  ),
                _SummaryRow(
                  icon: Icons.menu_book_outlined,
                  label: '账本数',
                  value: '${preview.ledgerCount}',
                ),
                _SummaryRow(
                  icon: Icons.list_alt,
                  label: '流水数',
                  value: '${preview.transactionCount}',
                ),
                if (isThirdParty && preview.unmappedCategoryCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '其中 ${preview.unmappedCategoryCount} 条按关键词未匹配到本地分类，'
                      '已归入「其他」。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
                if (preview.exportedAt != null)
                  _SummaryRow(
                    icon: Icons.schedule,
                    label: '导出时间',
                    value: preview.exportedAt!.toLocal().toString(),
                  ),
                if (preview.sourceDeviceId != null)
                  _SummaryRow(
                    icon: Icons.devices_other,
                    label: '来源设备',
                    value: preview.sourceDeviceId!,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('前 ${preview.sampleRows.length} 行预览', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: preview.sampleRows.isEmpty
                ? const Center(child: Text('备份内不含流水'))
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: preview.sampleRows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (context, i) =>
                        _PreviewRowTile(row: preview.sampleRows[i]),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text('去重策略', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (isCsv)
          Text(
            isThirdParty
                ? '第三方账单不含本 App 的 ID，会作为「全部新记录」导入；账本归入当前账本，'
                    '账户列若与现有账户同名会被关联，否则置空。'
                : 'CSV 文件不含 ID，只能作为「全部新记录」导入；账本/分类/账户按名称匹配，'
                    '匹配不到时归到当前账本，分类/账户列空。',
            style: theme.textTheme.bodySmall,
          )
        else
          Column(
            children: [
              _StrategyTile(
                value: BackupDedupeStrategy.skip,
                groupValue: _strategy,
                title: '跳过已存在',
                subtitle: '已经存在相同 ID 的流水会被忽略——适合多次导入同一份备份',
                onChanged: (v) => setState(() => _strategy = v!),
              ),
              _StrategyTile(
                value: BackupDedupeStrategy.overwrite,
                groupValue: _strategy,
                title: '覆盖',
                subtitle: '已存在的 ID 会被备份内容覆盖——适合用备份恢复部分流水',
                onChanged: (v) => setState(() => _strategy = v!),
              ),
              _StrategyTile(
                value: BackupDedupeStrategy.asNew,
                groupValue: _strategy,
                title: '全部作为新记录',
                subtitle: '每条都生成新 ID，可能产生重复——适合合并别人的备份',
                onChanged: (v) => setState(() => _strategy = v!),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetToIdle,
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _applyImport,
                child: const Text('确认导入'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _applyImport() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() => _stage = _Stage.applying);
    try {
      final db = ref.read(local.appDatabaseProvider);
      final deviceId = await ref.read(local.deviceIdProvider.future);
      // CSV 路径需要 fallback ledger（找不到名字时落到当前账本）。
      String? fallbackLedgerId;
      if (preview.fileType == BackupImportFileType.csv) {
        fallbackLedgerId = await ref.read(currentLedgerIdProvider.future);
      }
      final service = BackupImportService();
      final result = await service.apply(
        preview: preview,
        strategy: _strategy,
        db: db,
        currentDeviceId: deviceId,
        fallbackLedgerId: fallbackLedgerId,
      );
      // 清空密码 + 切结果阶段
      _passwordCtrl.clear();
      setState(() {
        _result = result;
        _stage = _Stage.done;
      });
      _invalidateAffectedProviders();
    } catch (e) {
      _showError('写入失败：$e');
    }
  }

  /// 让首页流水列表 / 资产 / 统计等页 invalidate 重读最新数据。
  void _invalidateAffectedProviders() {
    // 仅在 mounted 时调用——cleanup 时该 ref 已 disposed。
    if (!mounted) return;
    ref.invalidate(currentLedgerIdProvider);
  }

  // ─── Stage 4: done ────────────────────────────────────────────────────

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle,
                    color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '导入完成',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(
                  icon: Icons.menu_book_outlined,
                  label: '账本',
                  value: '${r.ledgersWritten} 条 upsert',
                ),
                _SummaryRow(
                  icon: Icons.category_outlined,
                  label: '分类',
                  value: '${r.categoriesWritten} 条 upsert',
                ),
                _SummaryRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '账户',
                  value: '${r.accountsWritten} 条 upsert',
                ),
                _SummaryRow(
                  icon: Icons.list_alt,
                  label: '流水',
                  value:
                      '${r.transactionsWritten} 条写入 / ${r.transactionsSkipped} 条跳过',
                ),
                _SummaryRow(
                  icon: Icons.savings_outlined,
                  label: '预算',
                  value: '${r.budgetsWritten} 条 upsert',
                ),
                if (r.unresolvedLedgerLabels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '提示：账本「${r.unresolvedLedgerLabels.join("、")}」未匹配到，'
                      '已归入当前账本。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resetToIdle,
                child: const Text('继续导入其他文件'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Stage error ─────────────────────────────────────────────────────

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline,
                    color: theme.colorScheme.error, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorText ?? '未知错误',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _resetToIdle,
          child: const Text('重新选择'),
        ),
      ],
    );
  }

  void _showError(String message) {
    setState(() {
      _stage = _Stage.error;
      _errorText = message;
    });
  }

  void _resetToIdle() {
    _passwordCtrl.clear();
    setState(() {
      _stage = _Stage.idle;
      _pickedFile = null;
      _pickedType = null;
      _bytes = null;
      _preview = null;
      _result = null;
      _errorText = null;
      _strategy = BackupDedupeStrategy.skip;
    });
  }

  String _typeLabel(BackupImportFileType t) {
    switch (t) {
      case BackupImportFileType.json:
        return 'JSON';
      case BackupImportFileType.bbbak:
        return '加密备份 (.bbbak)';
      case BackupImportFileType.csv:
        return 'CSV';
    }
  }
}

enum _Stage {
  /// 未选文件。
  idle,

  /// 解析中（短暂——通常 <100ms 不会被用户看见，长 .bbbak 会停几百毫秒）。
  parsing,

  /// 文件已选，需要用户输入密码（仅 .bbbak）。
  needPassword,

  /// 已解析，等待用户选策略并确认。
  preview,

  /// 应用中（写库）。
  applying,

  /// 应用成功，显示结果。
  done,

  /// 任一阶段失败。
  error,
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRowTile extends StatelessWidget {
  const _PreviewRowTile({required this.row});
  final BackupImportPreviewRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      row.date,
      if (row.category != null && row.category!.isNotEmpty) row.category!,
      if (row.account != null && row.account!.isNotEmpty) row.account!,
      if (row.toAccount != null && row.toAccount!.isNotEmpty)
        '→ ${row.toAccount}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (row.ledgerLabel != null) ...[
                Text(
                  row.ledgerLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
              ],
              Text(row.type, style: theme.textTheme.bodySmall),
              const Spacer(),
              Text(
                '${row.amount} ${row.currency}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitleParts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (row.note != null && row.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                row.note!,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _StrategyTile extends StatelessWidget {
  const _StrategyTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final BackupDedupeStrategy value;
  final BackupDedupeStrategy groupValue;
  final String title;
  final String subtitle;
  final ValueChanged<BackupDedupeStrategy?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
