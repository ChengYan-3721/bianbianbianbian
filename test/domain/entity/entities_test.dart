import 'dart:io';
import 'dart:typed_data';

import 'package:bianbianbianbian/domain/entity/account.dart';
import 'package:bianbianbianbian/domain/entity/budget.dart';
import 'package:bianbianbianbian/domain/entity/category.dart';
import 'package:bianbianbianbian/domain/entity/ledger.dart';
import 'package:bianbianbianbian/domain/entity/transaction_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 2.1 验证：5 个领域实体的 JSON roundtrip + copyWith + 依赖隔离。
///
/// 每个实体两条用例（全字段非空 / 可空字段为 null）+ 一条 copyWith。
/// 另加一条"整棵 lib/domain 不得 import 任何 package:drift/"的依赖扫描——
/// 实施计划 Step 2.1 的硬约束，防止领域层悄悄泄漏数据访问库。
void main() {
  group('Ledger', () {
    final full = Ledger(
      id: 'ledger-1',
      name: '生活',
      coverEmoji: '📒',
      defaultCurrency: 'CNY',
      archived: true,
      createdAt: DateTime.utc(2026, 4, 20, 10),
      updatedAt: DateTime.utc(2026, 4, 21, 12, 30),
      deletedAt: DateTime.utc(2026, 4, 22),
      deviceId: 'device-a',
    );

    test('fromJson(toJson(x)) == x （全字段）', () {
      expect(Ledger.fromJson(full.toJson()), full);
    });

    test('fromJson(toJson(x)) == x （coverEmoji / deletedAt 为 null）', () {
      final minimal = Ledger(
        id: 'ledger-2',
        name: '工作',
        createdAt: DateTime.utc(2026, 4, 20),
        updatedAt: DateTime.utc(2026, 4, 20),
        deviceId: 'device-a',
      );
      expect(Ledger.fromJson(minimal.toJson()), minimal);
      // 默认值落地：defaultCurrency='CNY' / archived=false
      expect(minimal.defaultCurrency, 'CNY');
      expect(minimal.archived, isFalse);
    });

    test('copyWith 单字段改，其他保留', () {
      final renamed = full.copyWith(name: '家庭');
      expect(renamed.name, '家庭');
      expect(renamed.id, full.id);
      expect(renamed.coverEmoji, full.coverEmoji);
      expect(renamed.archived, full.archived);
      expect(renamed.createdAt, full.createdAt);
    });
  });

  group('Category', () {
    final full = Category(
      id: 'cat-1',
      parentKey: 'food',
      name: '餐饮',
      icon: '🍚',
      color: '#FFB7C5',
      isFavorite: true,
      sortOrder: 3,
      updatedAt: DateTime.utc(2026, 4, 21),
      deletedAt: DateTime.utc(2026, 4, 22),
      deviceId: 'device-a',
    );

    test('fromJson(toJson(x)) == x （全字段）', () {
      expect(Category.fromJson(full.toJson()), full);
    });

    test('fromJson(toJson(x)) == x （icon/color/deletedAt 为 null + 默认 sortOrder）',
        () {
      final minimal = Category(
        id: 'cat-2',
        parentKey: 'income',
        name: '工资',
        updatedAt: DateTime.utc(2026, 4, 21),
        deviceId: 'device-a',
      );
      expect(Category.fromJson(minimal.toJson()), minimal);
      expect(minimal.sortOrder, 0);
    });

    test('copyWith 改 sortOrder 不动 parentKey', () {
      final moved = full.copyWith(sortOrder: 10);
      expect(moved.sortOrder, 10);
      expect(moved.parentKey, 'food');
      expect(moved.parentKey, full.parentKey);
    });
  });

  group('Account', () {
    final full = Account(
      id: 'acc-1',
      name: '招商信用卡',
      type: 'credit',
      icon: '💳',
      color: '#E76F51',
      initialBalance: -1200.5,
      includeInTotal: false,
      currency: 'USD',
      billingDay: 5,
      repaymentDay: 22,
      updatedAt: DateTime.utc(2026, 4, 21),
      deletedAt: DateTime.utc(2026, 4, 22),
      deviceId: 'device-a',
    );

    test('fromJson(toJson(x)) == x （全字段，含信用卡日）', () {
      expect(Account.fromJson(full.toJson()), full);
    });

    test('fromJson(toJson(x)) == x （icon/color/deletedAt 为 null + 全默认）',
        () {
      final minimal = Account(
        id: 'acc-2',
        name: '现金',
        type: 'cash',
        updatedAt: DateTime.utc(2026, 4, 21),
        deviceId: 'device-a',
      );
      expect(Account.fromJson(minimal.toJson()), minimal);
      expect(minimal.initialBalance, 0.0);
      expect(minimal.includeInTotal, isTrue);
      expect(minimal.currency, 'CNY');
      expect(minimal.billingDay, isNull);
      expect(minimal.repaymentDay, isNull);
    });

    test('copyWith 改 initialBalance 不动 includeInTotal / 信用卡日', () {
      final topped = full.copyWith(initialBalance: -800.0);
      expect(topped.initialBalance, -800.0);
      expect(topped.includeInTotal, isFalse);
      expect(topped.currency, 'USD');
      expect(topped.billingDay, 5);
      expect(topped.repaymentDay, 22);
    });

    test('信用卡日仅存其一也能 roundtrip（Step 7.3：允许部分填写）', () {
      final partial = Account(
        id: 'acc-3',
        name: '工商信用卡',
        type: 'credit',
        billingDay: 10,
        // repaymentDay 留空
        updatedAt: DateTime.utc(2026, 4, 21),
        deviceId: 'device-a',
      );
      expect(Account.fromJson(partial.toJson()), partial);
      expect(partial.billingDay, 10);
      expect(partial.repaymentDay, isNull);
    });
  });

  group('TransactionEntry', () {
    final sampleBytes = Uint8List.fromList(const [1, 2, 3, 4, 255, 128, 64]);
    final full = TransactionEntry(
      id: 'tx-1',
      ledgerId: 'ledger-1',
      type: 'expense',
      amount: 42.5,
      currency: 'CNY',
      fxRate: 1.0,
      categoryId: 'cat-1',
      accountId: 'acc-1',
      toAccountId: null,
      occurredAt: DateTime.utc(2026, 4, 21, 20, 18),
      noteEncrypted: sampleBytes,
      attachmentsEncrypted: Uint8List.fromList(const [10, 20, 30]),
      tags: '午餐,工作日',
      contentHash: 'hash-abc',
      updatedAt: DateTime.utc(2026, 4, 21, 20, 19),
      deletedAt: DateTime.utc(2026, 4, 22),
      deviceId: 'device-a',
    );

    test('fromJson(toJson(x)) == x （含非 ASCII bytes 深等 + base64 roundtrip）', () {
      final decoded = TransactionEntry.fromJson(full.toJson());
      expect(decoded, full, reason: '深等相等（bytes 走深比较）');
      expect(decoded.noteEncrypted, isNotNull);
      expect(decoded.noteEncrypted, sampleBytes);
      // bytes 引用不相等但值相等——正是 _bytesEqual 保护的场景
      expect(identical(decoded.noteEncrypted, sampleBytes), isFalse);
    });

    test(
        'fromJson(toJson(x)) == x （note/attachments/category/account/deletedAt 均 null）',
        () {
      final minimal = TransactionEntry(
        id: 'tx-2',
        ledgerId: 'ledger-1',
        type: 'income',
        amount: 10000.0,
        currency: 'CNY',
        occurredAt: DateTime.utc(2026, 4, 1),
        updatedAt: DateTime.utc(2026, 4, 1),
        deviceId: 'device-a',
      );
      expect(TransactionEntry.fromJson(minimal.toJson()), minimal);
      expect(minimal.fxRate, 1.0);
    });

    test('copyWith 改 amount 不动 bytes', () {
      final edited = full.copyWith(amount: 50.0);
      expect(edited.amount, 50.0);
      expect(edited.noteEncrypted, sampleBytes);
      expect(edited, isNot(equals(full))); // amount 变了
    });

    test('不同 bytes 不相等（保证 _bytesEqual 没变成 trivially true）', () {
      final other = full.copyWith(
        noteEncrypted: Uint8List.fromList(const [9, 9, 9]),
      );
      expect(other == full, isFalse);
      expect(other.hashCode == full.hashCode, isFalse);
    });
  });

  group('Budget', () {
    final full = Budget(
      id: 'bgt-1',
      ledgerId: 'ledger-1',
      period: 'monthly',
      categoryId: 'cat-food',
      amount: 1200.0,
      carryOver: true,
      startDate: DateTime.utc(2026, 4, 1),
      updatedAt: DateTime.utc(2026, 4, 21),
      deletedAt: DateTime.utc(2026, 4, 22),
      deviceId: 'device-a',
    );

    test('fromJson(toJson(x)) == x （全字段）', () {
      expect(Budget.fromJson(full.toJson()), full);
    });

    test('fromJson(toJson(x)) == x （categoryId=null 表示总预算 + 默认 carryOver）',
        () {
      final total = Budget(
        id: 'bgt-2',
        ledgerId: 'ledger-1',
        period: 'monthly',
        amount: 3000.0,
        startDate: DateTime.utc(2026, 4, 1),
        updatedAt: DateTime.utc(2026, 4, 21),
        deviceId: 'device-a',
      );
      expect(Budget.fromJson(total.toJson()), total);
      expect(total.categoryId, isNull);
      expect(total.carryOver, isFalse);
    });

    test('copyWith 切换 carryOver', () {
      final off = full.copyWith(carryOver: false);
      expect(off.carryOver, isFalse);
      expect(off.amount, full.amount);
    });
  });

  group('domain 层依赖隔离', () {
    test('lib/domain/ 下所有 .dart 文件均不 import package:drift/*', () {
      final root = Directory('lib/domain');
      expect(root.existsSync(), isTrue,
          reason: 'domain 目录必须存在（Step 0.2 建立的骨架）');

      final offenders = <String>[];
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        // 只扫描 import/export 语句，避免注释/字符串里的字面量误杀
        final importLines = content.split('\n').where(
              (line) =>
                  line.trimLeft().startsWith('import ') ||
                  line.trimLeft().startsWith('export '),
            );
        for (final line in importLines) {
          if (line.contains("'package:drift/") ||
              line.contains('"package:drift/')) {
            offenders.add('${entity.path}: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '领域层禁止直接依赖 drift；仓库层才做 entity ↔ drift 转换。'
              '违规: ${offenders.join('\n')}');
    });
  });
}
