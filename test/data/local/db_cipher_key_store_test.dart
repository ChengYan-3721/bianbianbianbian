import 'dart:math';

import 'package:bianbianbianbian/data/local/db_cipher_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryStore implements SecureKeyValueStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    _map[key] = value;
  }
}

void main() {
  group('DbCipherKeyStore', () {
    test('首次调用生成 64 字符 hex 并写入底层 store', () async {
      final backing = _InMemoryStore();
      // Random(42) 给出确定性序列，便于在 CI 上稳定复现。
      final store = DbCipherKeyStore(storage: backing, random: Random(42));

      final key = await store.loadOrCreate();

      expect(key.length, DbCipherKeyStore.keyByteLength * 2);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue,
          reason: '密钥必须是 64 字符小写 hex');
      expect(await backing.read(DbCipherKeyStore.storageKey), key,
          reason: '生成的密钥必须被持久化到底层 store');
    });

    test('第二次调用直接读回同一密钥，不重新生成', () async {
      final backing = _InMemoryStore();
      final store = DbCipherKeyStore(storage: backing, random: Random(7));

      final first = await store.loadOrCreate();
      final second = await store.loadOrCreate();

      expect(second, first);
    });

    test('底层已存在非法条目时覆写为新密钥', () async {
      final backing = _InMemoryStore();
      // 模拟旧版本遗留的脏数据：长度对但含大写或非 hex 字符。
      await backing.write(DbCipherKeyStore.storageKey, 'X' * 64);
      final store = DbCipherKeyStore(storage: backing, random: Random(1));

      final key = await store.loadOrCreate();

      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
      expect(key, isNot('X' * 64));
      expect(await backing.read(DbCipherKeyStore.storageKey), key);
    });

    test('两个独立 store 实例产出相互独立的密钥（本地熵充足）', () async {
      final storeA =
          DbCipherKeyStore(storage: _InMemoryStore(), random: Random.secure());
      final storeB =
          DbCipherKeyStore(storage: _InMemoryStore(), random: Random.secure());

      final a = await storeA.loadOrCreate();
      final b = await storeB.loadOrCreate();

      expect(a, isNot(b));
    });
  });
}
