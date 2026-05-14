import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../data/local/providers.dart' as local;
import '../../data/repository/providers.dart';
import '../../domain/entity/ledger.dart';
import '../sync/snapshot_serializer.dart';
import 'export_service.dart';

/// 导出配置页(Step 13.1 + Step 13.2)。
///
/// 表单：格式(CSV / JSON / .bbbak)、范围(当前/全部账本)、时间区间(全部 / 自定义)。
/// `.bbbak` 选中时额外展开"密码 + 确认密码 + 警告"区域。
///
/// 点"导出"后：
/// 1. 拉取选中账本的 LedgerSnapshot；
/// 2. 按区间过滤流水；
/// 3. 编码(CSV / JSON / `.bbbak`)→ 落盘到 `<documents>/exports/`；
/// 4. 唤起系统 Share Sheet。
///
/// **不**直接消费同步引擎——同步是"账本快照上传到云"，本页是"账本快照写到本地导出文件"。
/// 两者底层共享 `LedgerSnapshot` 数据契约，但路径完全独立(不动 sync_op、不动云端)。
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  BackupFormat _format = BackupFormat.csv;
  BackupScope _scope = BackupScope.currentLedger;

  /// null = 不限定区间。
  DateTimeRange? _range;

  bool _exporting = false;

  /// `.bbbak` 加密密码 + 确认。两个 controller 各自管理 obscure 状态。
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _passwordConfirmCtrl = TextEditingController();
  bool _passwordObscured = true;

  @override
  void dispose() {
    // 安全考量：导出页关闭时清空密码字段，避免内存常驻。
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.exportTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(text: context.l10n.exportFormat),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<BackupFormat>(
              segments: [
                ButtonSegment(
                  value: BackupFormat.csv,
                  label: const Text('CSV'),
                  icon: const Icon(Icons.table_chart_outlined),
                ),
                ButtonSegment(
                  value: BackupFormat.json,
                  label: const Text('JSON'),
                  icon: const Icon(Icons.data_object),
                ),
                ButtonSegment(
                  value: BackupFormat.bbbak,
                  label: Text(context.l10n.exportEncrypted),
                  icon: const Icon(Icons.lock_outline),
                ),
              ],
              selected: {_format},
              onSelectionChanged: _exporting
                  ? null
                  : (s) => setState(() => _format = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _formatDescription(context, _format),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_format == BackupFormat.bbbak) _buildPasswordSection(context),
          const Divider(),
          _SectionHeader(text: context.l10n.exportRange),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<BackupScope>(
              segments: [
                ButtonSegment(
                  value: BackupScope.currentLedger,
                  label: Text(context.l10n.exportCurrentLedger),
                ),
                ButtonSegment(
                  value: BackupScope.allLedgers,
                  label: Text(context.l10n.exportAllLedgers),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: _exporting
                  ? null
                  : (s) => setState(() => _scope = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _scope == BackupScope.currentLedger
                  ? context.l10n.exportCurrentLedgerHint
                  : context.l10n.exportAllLedgersHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          _SectionHeader(text: context.l10n.exportTimeRange),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(context.l10n.exportAllTime),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(context.l10n.exportCustomTime),
                ),
              ],
              selected: {_range != null},
              onSelectionChanged: _exporting
                  ? null
                  : (s) async {
                      final picked = s.first;
                      if (picked == false) {
                        setState(() => _range = null);
                      } else {
                        await _pickDateRange();
                      }
                    },
            ),
          ),
          if (_range != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: Text(
                  '${_formatDate(_range!.start)} – ${_formatDate(_range!.end)}',
                ),
                trailing: TextButton(
                  onPressed: _exporting ? null : _pickDateRange,
                  child: Text(context.l10n.modify),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: Text(_exporting ? context.l10n.exporting : context.l10n.exportAndShare),
              onPressed: (_exporting || !_canExport()) ? null : _runExport,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDescription(BuildContext context, BackupFormat f) {
    switch (f) {
      case BackupFormat.csv:
        return context.l10n.exportCsvDesc;
      case BackupFormat.json:
        return context.l10n.exportJsonDesc;
      case BackupFormat.bbbak:
        return context.l10n.exportBbbakDesc;
    }
  }

  /// `.bbbak` 选中时显示的密码区域。
  Widget _buildPasswordSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mismatch = _passwordConfirmCtrl.text.isNotEmpty &&
        _passwordCtrl.text != _passwordConfirmCtrl.text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 警告横幅：醒目颜色 + 不可漏读文案
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.exportPasswordWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: _passwordObscured,
            enabled: !_exporting,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.exportPassword,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordObscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: _exporting
                    ? null
                    : () => setState(
                          () => _passwordObscured = !_passwordObscured,
                        ),
                tooltip: _passwordObscured ? context.l10n.exportShowPassword : context.l10n.exportHidePassword,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordConfirmCtrl,
            obscureText: _passwordObscured,
            enabled: !_exporting,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: context.l10n.exportReEnterPassword,
              border: const OutlineInputBorder(),
              errorText: mismatch ? context.l10n.exportPasswordMismatch : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 当前表单是否允许"导出"按钮可点击。
  ///
  /// CSV / JSON：始终允许；
  /// `.bbbak`：要求两次密码非空且一致。
  bool _canExport() {
    if (_format != BackupFormat.bbbak) return true;
    final pw = _passwordCtrl.text;
    final confirm = _passwordConfirmCtrl.text;
    return pw.isNotEmpty && pw == confirm;
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(2000, 1, 1);
    final initial = _range ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
    }
  }

  Future<void> _runExport() async {
    final l10n = context.l10n;
    setState(() => _exporting = true);
    File? outFile;
    try {
      // 1. 解析时间区间
      final range = _range == null
          ? BackupDateRange.unbounded
          : BackupDateRange(
              start: DateTime(
                _range!.start.year,
                _range!.start.month,
                _range!.start.day,
              ),
              // showDateRangePicker 返回的 end 是当天 0 时——我们需要包含整天。
              end: DateTime(
                _range!.end.year,
                _range!.end.month,
                _range!.end.day,
                23,
                59,
                59,
              ),
            );

      // 2. 选择目标账本
      final ledgerRepo = await ref.read(ledgerRepositoryProvider.future);
      final List<Ledger> targetLedgers;
      if (_scope == BackupScope.currentLedger) {
        final id = await ref.read(currentLedgerIdProvider.future);
        final l = await ledgerRepo.getById(id);
        if (l == null) {
          throw StateError(l10n.exportCurrentLedgerNotExist);
        }
        targetLedgers = [l];
      } else {
        targetLedgers = await ledgerRepo.listActive();
        if (targetLedgers.isEmpty) {
          throw StateError(l10n.exportNoLedgerToExport);
        }
      }

      // 3. 拉取每个账本的快照 + 区间过滤
      final categoryRepo = await ref.read(categoryRepositoryProvider.future);
      final accountRepo = await ref.read(accountRepositoryProvider.future);
      final transactionRepo =
          await ref.read(transactionRepositoryProvider.future);
      final budgetRepo = await ref.read(budgetRepositoryProvider.future);
      final deviceId = await ref.read(local.deviceIdProvider.future);
      final exportedAt = DateTime.now();

      final snapshots = <LedgerSnapshot>[];
      for (final l in targetLedgers) {
        final raw = await exportLedgerSnapshot(
          ledgerId: l.id,
          deviceId: deviceId,
          ledgerRepo: ledgerRepo,
          categoryRepo: categoryRepo,
          accountRepo: accountRepo,
          transactionRepo: transactionRepo,
          budgetRepo: budgetRepo,
          clock: () => exportedAt,
        );
        snapshots.add(filterSnapshotByRange(raw, range));
      }

      // 4. 编码 + 落盘
      final service = BackupExportService(now: () => exportedAt);
      switch (_format) {
        case BackupFormat.csv:
          outFile = await service.exportCsv(
            snapshots: snapshots,
            scope: _scope,
            range: range,
          );
          break;
        case BackupFormat.json:
          {
            final multi = MultiLedgerSnapshot(
              version: MultiLedgerSnapshot.kVersion,
              exportedAt: exportedAt,
              deviceId: deviceId,
              ledgers: snapshots,
            );
            outFile = await service.exportJson(
              multiSnapshot: multi,
              scope: _scope,
              range: range,
            );
            break;
          }
        case BackupFormat.bbbak:
          {
            final multi = MultiLedgerSnapshot(
              version: MultiLedgerSnapshot.kVersion,
              exportedAt: exportedAt,
              deviceId: deviceId,
              ledgers: snapshots,
            );
            // 从 controller 读出后立即拷贝出局部变量 + 清空 controller，
            // 避免密码长时间留在 widget tree 内存。
            final pw = _passwordCtrl.text;
            outFile = await service.exportBbbak(
              multiSnapshot: multi,
              password: pw,
              scope: _scope,
              range: range,
            );
            // 导出成功后清空密码字段——用户应当通过密码管理器记忆，本页不要再留。
            _passwordCtrl.clear();
            _passwordConfirmCtrl.clear();
            break;
          }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.exportedFile(outFile.path.split('/').last))),
      );

      await service.shareFile(
        outFile,
        subject: context.l10n.exportShareSubject,
        text: context.l10n.exportShareText(_formatLabel(_format)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.operationFailedWithError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _formatLabel(BackupFormat f) {
    switch (f) {
      case BackupFormat.csv:
        return 'CSV';
      case BackupFormat.json:
        return 'JSON';
      case BackupFormat.bbbak:
        return context.l10n.exportBbbakLabel;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
