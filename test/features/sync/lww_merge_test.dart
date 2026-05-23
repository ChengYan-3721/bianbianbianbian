import 'package:bianbianbianbian/features/sync/incremental_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 17(云同步 V2):LWW 决策表纯函数测试。
///
/// 不依赖 db/网络/任何 Service 实例,直接验 [lwwDecide] 函数本身。
/// 这是合并语义的"小内核",必须 100% 覆盖三条分支:
/// 1. remote 较新 → useRemote;
/// 2. remote 较旧 → useLocal;
/// 3. 平手按 device_id 字典序。
void main() {
  group('lwwDecide · 时间戳比较', () {
    test('remote.updated_at > local → useRemote', () {
      final outcome = lwwDecide(
        remoteUpdatedAt: 2000,
        remoteDeviceId: 'A',
        localUpdatedAt: 1000,
        localDeviceId: 'A',
      );
      expect(outcome, MergeOutcome.useRemote);
    });

    test('remote.updated_at < local → useLocal', () {
      final outcome = lwwDecide(
        remoteUpdatedAt: 1000,
        remoteDeviceId: 'A',
        localUpdatedAt: 2000,
        localDeviceId: 'A',
      );
      expect(outcome, MergeOutcome.useLocal);
    });

    test('差 1 ms 也算 remote 较新', () {
      final outcome = lwwDecide(
        remoteUpdatedAt: 1700000000001,
        remoteDeviceId: 'A',
        localUpdatedAt: 1700000000000,
        localDeviceId: 'A',
      );
      expect(outcome, MergeOutcome.useRemote);
    });
  });

  group('lwwDecide · device_id 字典序平手', () {
    test('updated_at 相等, remote device_id 字典序较大 → useRemote', () {
      final outcome = lwwDecide(
        remoteUpdatedAt: 1000,
        remoteDeviceId: 'device-B',
        localUpdatedAt: 1000,
        localDeviceId: 'device-A',
      );
      expect(outcome, MergeOutcome.useRemote);
    });

    test('updated_at 相等, remote device_id 字典序较小 → useLocal', () {
      final outcome = lwwDecide(
        remoteUpdatedAt: 1000,
        remoteDeviceId: 'device-A',
        localUpdatedAt: 1000,
        localDeviceId: 'device-B',
      );
      expect(outcome, MergeOutcome.useLocal);
    });

    test('updated_at + device_id 完全相同 → useLocal(保守,避免无意义写)', () {
      final outcome = lwwDecide(
        remoteUpdatedAt: 1000,
        remoteDeviceId: 'same-device',
        localUpdatedAt: 1000,
        localDeviceId: 'same-device',
      );
      expect(outcome, MergeOutcome.useLocal);
    });

    test('空字符串 device_id 视作字典序最小', () {
      final outcome = lwwDecide(
        remoteUpdatedAt: 1000,
        remoteDeviceId: '',
        localUpdatedAt: 1000,
        localDeviceId: 'A',
      );
      expect(outcome, MergeOutcome.useLocal);
    });

    test('UUID 形式 device_id 平手按字典序', () {
      // 现实场景: device_id 是 UUID v4, 平手 = 字面字符串比较
      final outcome = lwwDecide(
        remoteUpdatedAt: 1700000000000,
        remoteDeviceId: 'aaaaaaaa-bbbb-4ccc-9ddd-eeeeeeeeeeee',
        localUpdatedAt: 1700000000000,
        localDeviceId: 'bbbbbbbb-cccc-4ddd-9eee-ffffffffffff',
      );
      // 'a...' < 'b...' → local 较大 → useLocal
      expect(outcome, MergeOutcome.useLocal);
    });
  });

  group('lwwDecide · 真实场景', () {
    test('双设备并发改同一行,后改者(updated_at 大)胜出', () {
      // 设备 A 在 t=1000 改了一笔流水
      // 设备 B 在 t=2000 改了同一笔流水
      // pull 路径:本地是 A 的版本(local), 远端是 B 推上去的(remote)
      final outcome = lwwDecide(
        remoteUpdatedAt: 2000,
        remoteDeviceId: 'device-B',
        localUpdatedAt: 1000,
        localDeviceId: 'device-A',
      );
      expect(outcome, MergeOutcome.useRemote);
    });

    test('本地刚刚 push 上去, pull 时云端 updated_at 与本地相等且 device_id 相同 → useLocal',
        () {
      // 这是 push 后的 self-pull 场景:本地写入 push 到云端,过一会 pull
      // 回来,云端那条就是自己 push 的。LWW 应该判 useLocal 避免无意义重写。
      final outcome = lwwDecide(
        remoteUpdatedAt: 1700000000000,
        remoteDeviceId: 'device-self',
        localUpdatedAt: 1700000000000,
        localDeviceId: 'device-self',
      );
      expect(outcome, MergeOutcome.useLocal);
    });
  });
}
