import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
      appBar: AppBar(title: const Text('导出')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader(text: '格式'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<BackupFormat>(
              segments: const [
                ButtonSegment(
                  value: BackupFormat.csv,
                  label: Text('CSV'),
                  icon: Icon(Icons.table_chart_outlined),
                ),
                ButtonSegment(
                  value: BackupFormat.json,
                  label: Text('JSON'),
                  icon: Icon(Icons.data_object),
                ),
                ButtonSegment(
                  value: BackupFormat.bbbak,
                  label: Text('加密'),
                  icon: Icon(Icons.lock_outline),
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
              _formatDescription(_format),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (_format == BackupFormat.bbbak) _buildPasswordSection(context),
          const Divider(),
          const _SectionHeader(text: '范围'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<BackupScope>(
              segments: const [
                ButtonSegment(
                  value: BackupScope.currentLedger,
                  label: Text('当前账本'),
                ),
                ButtonSegment(
                  value: BackupScope.allLedgers,
                  label: Text('全部账本'),
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
                  ? '仅当前选中账本'
                  : '包含所有未删除账本(含归档)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          const _SectionHeader(text: '时间区间'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('全部时间'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('自定义'),
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
                  child: const Text('修改'),
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
              label: Text(_exporting ? '正在导出…' : '导出并分享'),
              onPressed: (_exporting || !_canExport()) ? null : _runExport,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDescription(BackupFormat f) {
    switch (f) {
      case BackupFormat.csv:
        return 'Excel / Numbers 直接打开';
      case BackupFormat.json:
        return '结构化全量备份(可被「导入」恢复)';
      case BackupFormat.bbbak:
        return '加密备份包(.bbbak)：JSON + AES-256 密码加密，仅本 App 能导入';
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
                    '该密码用于解密备份。一旦丢失，备份内容将永远无法恢复——'
                    '请使用密码管理器记录或写在安全的纸上，不要只存在脑子里。',
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
              labelText: '密码',
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
                tooltip: _passwordObscured ? '显示密码' : '隐藏密码',
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
              labelText: '再次输入密码',
              border: const OutlineInputBorder(),
              errorText: mismatch ? '两次输入不一致' : null,
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
          throw StateError('当前账本不存在');
        }
        targetLedgers = [l];
      } else {
        targetLedgers = await ledgerRepo.listActive();
        if (targetLedgers.isEmpty) {
          throw StateError('没有可导出的账本');
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
        SnackBar(content: Text('已导出：${outFile.path.split('/').last}')),
      );

      await service.shareFile(
        outFile,
        subject: '边边记账导出',
        text: '边边记账数据导出 (${_formatLabel(_format)})',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
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
        return '加密备份 .bbbak';
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
