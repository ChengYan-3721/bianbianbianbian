import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/l10n_ext.dart';
import '../../core/util/currencies.dart';
import '../../data/repository/providers.dart';
import '../../domain/entity/account.dart';
import 'account_providers.dart';

class AccountEditPage extends ConsumerStatefulWidget {
  const AccountEditPage({super.key, this.accountId});

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

  static const _typeKeys = ['cash', 'debit', 'credit', 'third_party', 'other'];

  String _typeLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    return switch (key) {
      'cash' => l10n.accountTypeCash,
      'debit' => l10n.accountTypeDebit,
      'credit' => l10n.accountTypeCredit,
      'third_party' => l10n.accountTypeThirdParty,
      _ => l10n.accountTypeOther,
    };
  }

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
    final l10n = context.l10n;
    final isEdit = widget.accountId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.accountEditTitle : l10n.accountNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
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
            return Center(child: Text(l10n.loadFailedWithError(snapshot.error.toString())));
          }
          final acc = snapshot.data;
          if (isEdit && acc == null) {
            return Center(child: Text(l10n.accountNotExist));
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
                    decoration: InputDecoration(
                      labelText: l10n.accountName,
                      hintText: l10n.accountNameHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.accountNameRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: InputDecoration(
                      labelText: l10n.accountType,
                      border: const OutlineInputBorder(),
                    ),
                    items: _typeKeys
                        .map(
                          (key) => DropdownMenuItem(
                            value: key,
                            child: Text(_typeLabel(context, key)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _type = v;
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
                    decoration: InputDecoration(
                      labelText: l10n.accountIconEmoji,
                      hintText: l10n.accountIconEmojiHint,
                      border: const OutlineInputBorder(),
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
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.accountInitialBalance,
                      hintText: l10n.accountInitialBalanceHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v.trim()) == null) {
                        return l10n.accountBalanceInvalid;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: l10n.accountDefaultCurrency,
                      border: const OutlineInputBorder(),
                    ),
                    items: kBuiltInCurrencies
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.code,
                            child: Text(c.localizedName(l10n)),
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
                            decoration: InputDecoration(
                              labelText: l10n.accountBillingDay,
                              hintText: l10n.accountBillingDayHint,
                              border: const OutlineInputBorder(),
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
                            decoration: InputDecoration(
                              labelText: l10n.accountRepaymentDay,
                              hintText: l10n.accountRepaymentDayHint,
                              border: const OutlineInputBorder(),
                            ),
                            validator: _validateDay,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(l10n.accountIncludeInTotal),
                    subtitle: Text(l10n.accountIncludeInTotalHint),
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

  String? _validateDay(String? v) {
    final raw = v?.trim() ?? '';
    if (raw.isEmpty) return null;
    final n = int.tryParse(raw);
    if (n == null || n < 1 || n > 28) {
      return context.l10n.accountDayRangeError;
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
            SnackBar(content: Text(context.l10n.accountCannotSave)),
          );
          return;
        }
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
          deviceId: '',
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
        SnackBar(content: Text(context.l10n.saveFailedWithError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
