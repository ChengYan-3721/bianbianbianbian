import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/ledger.dart';

/// 账本编辑/新建页
class LedgerEditPage extends ConsumerStatefulWidget {
  const LedgerEditPage({super.key, this.ledgerId});

  /// 传入 ledgerId 则为编辑模式，否则为新建模式
  final String? ledgerId;

  @override
  ConsumerState<LedgerEditPage> createState() => _LedgerEditPageState();
}

class _LedgerEditPageState extends ConsumerState<LedgerEditPage> {
  final _formKey = GlobalKey<FormState>();
  late Future<Ledger?> _loadLedgerFuture;

  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  String _defaultCurrency = 'CNY';
  bool _archived = false;

  @override
  void initState() {
    super.initState();
    _loadLedgerFuture = _loadLedger();
  }

  Future<Ledger?> _loadLedger() async {
    if (widget.ledgerId == null) return null;
    final repo = await ref.read(ledgerRepositoryProvider.future);
    return repo.getById(widget.ledgerId!);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.ledgerId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑账本' : '新建账本'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: FutureBuilder<Ledger?>(
        future: _loadLedgerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败: ${snapshot.error}'));
          }
          final ledger = snapshot.data;
          if (isEdit && ledger == null) {
            return const Center(child: Text('账本不存在'));
          }

          // 初始化表单数据
          if (ledger != null) {
            _nameController.text = ledger.name;
            _emojiController.text = ledger.coverEmoji ?? '';
            _defaultCurrency = ledger.defaultCurrency;
            _archived = ledger.archived;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '账本名称',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入账本名称';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emojiController,
                    decoration: const InputDecoration(
                      labelText: '封面 Emoji',
                      hintText: '例如 📒、💼、✈️',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _defaultCurrency,
                    decoration: const InputDecoration(
                      labelText: '默认币种',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CNY', child: Text('人民币 (CNY)')),
                      DropdownMenuItem(value: 'USD', child: Text('美元 (USD)')),
                      DropdownMenuItem(value: 'EUR', child: Text('欧元 (EUR)')),
                      DropdownMenuItem(value: 'JPY', child: Text('日元 (JPY)')),
                      DropdownMenuItem(value: 'KRW', child: Text('韩元 (KRW)')),
                      DropdownMenuItem(value: 'GBP', child: Text('英镑 (GBP)')),
                      DropdownMenuItem(value: 'HKD', child: Text('港币 (HKD)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _defaultCurrency = value);
                      }
                    },
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('归档'),
                      subtitle: const Text('归档后账本将移至归档区，不再显示在切换器中'),
                      value: _archived,
                      onChanged: (value) => setState(() => _archived = value),
                      activeTrackColor: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final repo = await ref.read(ledgerRepositoryProvider.future);
    final now = DateTime.now();
    final isEdit = widget.ledgerId != null;

    Ledger ledger;
    if (isEdit) {
      final existing = await repo.getById(widget.ledgerId!);
      if (existing == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('账本不存在，无法保存')),
        );
        return;
      }
      ledger = existing.copyWith(
        name: _nameController.text.trim(),
        coverEmoji: _emojiController.text.trim().isEmpty
            ? null
            : _emojiController.text.trim(),
        defaultCurrency: _defaultCurrency,
        archived: _archived,
        updatedAt: now,
      );
    } else {
      ledger = Ledger(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        coverEmoji: _emojiController.text.trim().isEmpty
            ? null
            : _emojiController.text.trim(),
        defaultCurrency: _defaultCurrency,
        archived: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        deviceId: '', // repo 会覆写
      );
    }

    try {
      await repo.save(ledger);
      if (!mounted) return;
      // 刷新账本列表
      ref.invalidate(ledgerRepositoryProvider);
      // 如果是编辑当前账本，刷新 currentLedgerId 的验证
      if (isEdit && widget.ledgerId == ref.read(currentLedgerIdProvider).valueOrNull) {
        ref.invalidate(currentLedgerIdProvider);
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }
}