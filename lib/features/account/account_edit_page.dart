import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import 'account_providers.dart';

/// 账户新建 / 编辑页（Step 7.2 + Step 7.3）。
///
/// `accountId` 为 null → 新建模式；非 null → 编辑模式。字段集合按
/// design-document §5.6 资产账户：名称 / 类型 / 图标 emoji / 初始余额 /
/// 默认币种 / 是否计入总资产。Step 7.3：当类型为 `credit` 时额外渲染
/// 账单日 / 还款日两字段（仅展示，1-28 整数校验）；切换到非信用卡时本地
/// 输入清空，保存时也写入 null，避免“切回信用卡又出现旧值”。
class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, this.accountId});

  /// 编辑模式传入此参数；新建模式留空。
  final String? accountId;

  @override
  ConsumerState<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends ConsumerState<AccountEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _iconController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  final _billingDayController = TextEditingController();
  final _repaymentDayController = TextEditingController();

  String _type = 'cash';
  String _currency = 'CNY';
  bool _includeInTotal = true;
  bool _initialized = false;
  bool _saving = false;

  late Future<Account?> _loadFuture;

  static const _typeOptions = <(String, String)>[
    ('cash', '现金'),
    ('debit', '储蓄卡'),
    ('credit', '信用卡'),
    ('third_party', '第三方支付'),
    ('other', '其他'),
  ];

  static const _currencyOptions = <(String, String)>[
    ('CNY', '人民币 (CNY)'),
    ('USD', '美元 (USD)'),
    ('EUR', '欧元 (EUR)'),
    ('JPY', '日元 (JPY)'),
    ('KRW', '韩元 (KRW)'),
    ('GBP', '英镑 (GBP)'),
    ('HKD', '港币 (HKD)'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAccount();
  }

  Future<Account?> _loadAccount() async {
    if (widget.accountId == null) return null;
    final repo = await ref.read(accountRepositoryProvider.future);
    return repo.getById(widget.accountId!);
  }

  void _hydrate(Account acc) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = acc.name;
    _iconController.text = acc.icon ?? '';
    _initialBalanceController.text = acc.initialBalance == 0
        ? ''
        : acc.initialBalance.toStringAsFixed(2);
    _billingDayController.text = acc.billingDay?.toString() ?? '';
    _repaymentDayController.text = acc.repaymentDay?.toString() ?? '';
    _type = acc.type;
    _currency = acc.currency;
    _includeInTotal = acc.includeInTotal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _initialBalanceController.dispose();
    _billingDayController.dispose();
    _repaymentDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.accountId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑账户' : '新建账户'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: FutureBuilder<Account?>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }
          final acc = snapshot.data;
          if (isEdit && acc == null) {
            return const Center(child: Text('账户不存在'));
          }
          if (acc != null) _hydrate(acc);

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
                      labelText: '账户名称',
                      hintText: '例如：现金、工商银行卡',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return '请输入账户名称';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: '账户类型',
                      border: OutlineInputBorder(),
                    ),
                    items: _typeOptions
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.$1,
                            child: Text(e.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _type = v;
                        // 切到非信用卡时，清掉本地输入，避免"再切回 credit
                        // 又出现旧值"的视觉残留；保存时同样按当前 type 写入 null。
                        if (v != 'credit') {
                          _billingDayController.clear();
                          _repaymentDayController.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _iconController,
                    decoration: const InputDecoration(
                      labelText: '图标 Emoji（可选）',
                      hintText: '例如 💰、💳、🏦',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _initialBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    inputFormatters: [
                      // 允许负号 + 最多两位小数
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: '初始余额',
                      hintText: '可为负（信用卡欠款填负值）',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v.trim()) == null) {
                        return '请输入合法的数字';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      labelText: '默认币种',
                      border: OutlineInputBorder(),
                    ),
                    items: _currencyOptions
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.$1,
                            child: Text(e.$2),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _currency = v);
                    },
                  ),
                  if (_type == 'credit') ...[
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const Key('billing_day_field'),
                            controller: _billingDayController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              labelText: '账单日（1-28）',
                              hintText: '例如 5',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateDay,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: const Key('repayment_day_field'),
                            controller: _repaymentDayController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            decoration: const InputDecoration(
                              labelText: '还款日（1-28）',
                              hintText: '例如 22',
                              border: OutlineInputBorder(),
                            ),
                            validator: _validateDay,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('计入总资产'),
                    subtitle: const Text('关闭后该账户余额不参与总资产合计'),
                    value: _includeInTotal,
                    onChanged: (v) => setState(() => _includeInTotal = v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 1-28 整数校验：空字符串视为"未填"放行（信用卡也允许暂时不填）。
  String? _validateDay(String? v) {
    final raw = v?.trim() ?? '';
    if (raw.isEmpty) return null;
    final n = int.tryParse(raw);
    if (n == null || n < 1 || n > 28) {
      return '请输入 1-28 的整数';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final repo = await ref.read(accountRepositoryProvider.future);
      final now = DateTime.now();
      final isEdit = widget.accountId != null;

      final balance = _initialBalanceController.text.trim().isEmpty
          ? 0.0
          : double.parse(_initialBalanceController.text.trim());
      final iconText = _iconController.text.trim();
      final iconValue = iconText.isEmpty ? null : iconText;
      final name = _nameController.text.trim();

      // 仅信用卡保存账单日 / 还款日；其它类型一律落 null。
      final billingDay = _type == 'credit'
          ? int.tryParse(_billingDayController.text.trim())
          : null;
      final repaymentDay = _type == 'credit'
          ? int.tryParse(_repaymentDayController.text.trim())
          : null;

      Account entity;
      if (isEdit) {
        final existing = await repo.getById(widget.accountId!);
        if (existing == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('账户不存在，无法保存')),
          );
          return;
        }
        // 信用卡字段需要支持"清空"语义——copyWith 不能把 T? 清回 null。
        // 改为裸构造保留所有其它字段，同时 billingDay / repaymentDay 显式传 null
        // 时就是清空（非 credit 类型同样清空，这里也走裸构造路径）。
        entity = Account(
          id: existing.id,
          name: name,
          type: _type,
          icon: iconValue,
          color: existing.color,
          initialBalance: balance,
          includeInTotal: _includeInTotal,
          currency: _currency,
          billingDay: billingDay,
          repaymentDay: repaymentDay,
          updatedAt: now,
          deletedAt: existing.deletedAt,
          deviceId: existing.deviceId,
        );
      } else {
        entity = Account(
          id: const Uuid().v4(),
          name: name,
          type: _type,
          icon: iconValue,
          initialBalance: balance,
          includeInTotal: _includeInTotal,
          currency: _currency,
          billingDay: billingDay,
          repaymentDay: repaymentDay,
          updatedAt: now,
          deviceId: '', // repo 会覆写
        );
      }

      await repo.save(entity);
      if (!mounted) return;
      ref.invalidate(accountsListProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(totalAssetsProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
