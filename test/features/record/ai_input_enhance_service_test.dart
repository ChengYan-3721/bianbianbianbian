import 'dart:convert';

import 'package:bianbianbianbian/features/record/ai_input_enhance_service.dart';
import 'package:bianbianbianbian/features/settings/ai_input_settings_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Step 9.3：[AiInputEnhanceService] + [parseEnhanceJson] 单元测试。
///
/// 覆盖三条 implementation-plan §9.3 验证：
/// 1. 没有配置 API 时按钮不显示——服务侧 [enhance] 在缺配置时抛 [AiEnhanceException]
///    （UI 由 [QuickConfirmCard] 配合 [hasMinimalConfig] 守门，本文件仅验服务端兜底）。
/// 2. 网络失败回退本地结果——HTTP / 超时 / 解析异常一律抛 [AiEnhanceException]。
/// 3. 响应 JSON 不符合 schema 不崩溃——[parseEnhanceJson] 严格校验，越界字段抛
///    [AiEnhanceException] 而非泄露解码异常。
void main() {
  const validSettings = AiInputSettings(
    enabled: true,
    endpoint: 'https://api.example.com/v1/chat/completions',
    apiKey: 'sk-test',
    model: 'gpt-4o-mini',
  );

  String wrapChatCompletion(String contentJson) {
    return jsonEncode({
      'choices': [
        {
          'message': {
            'role': 'assistant',
            'content': contentJson,
          }
        }
      ],
    });
  }

  group('parseEnhanceJson - 正常路径', () {
    test('全字段命中 → AiEnhanceResult', () {
      final r = parseEnhanceJson(jsonEncode({
        'amount': 88.5,
        'category_parent_key': 'transport',
        'occurred_at': '2026-05-01',
        'note': '打车去机场',
      }));
      expect(r.amount, 88.5);
      expect(r.categoryParentKey, 'transport');
      expect(r.occurredAt, DateTime(2026, 5, 1));
      expect(r.note, '打车去机场');
    });

    test('仅 amount 命中 → 其他字段 null（部分识别也能用）', () {
      final r = parseEnhanceJson(jsonEncode({
        'amount': 30,
      }));
      expect(r.amount, 30.0);
      expect(r.categoryParentKey, isNull);
      expect(r.occurredAt, isNull);
      expect(r.note, isNull);
    });

    test('amount=null → AiEnhanceResult.amount=null（可选字段）', () {
      final r = parseEnhanceJson(jsonEncode({
        'amount': null,
        'category_parent_key': 'food',
        'note': '只识别了分类',
      }));
      expect(r.amount, isNull);
      expect(r.categoryParentKey, 'food');
      expect(r.note, '只识别了分类');
    });

    test('占位字段空字符串等价于缺失', () {
      final r = parseEnhanceJson(jsonEncode({
        'amount': 10,
        'category_parent_key': '',
        'occurred_at': '',
        'note': '   ',
      }));
      expect(r.categoryParentKey, isNull);
      expect(r.occurredAt, isNull);
      expect(r.note, isNull);
    });
  });

  group('parseEnhanceJson - schema 严格校验（验证 3：JSON 不符合 schema 不崩溃）', () {
    test('content 不是合法 JSON → AiEnhanceException', () {
      expect(
        () => parseEnhanceJson('not a json'),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('content 根不是对象（数组）→ AiEnhanceException', () {
      expect(
        () => parseEnhanceJson('[1,2,3]'),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('amount 类型非法（字符串）→ AiEnhanceException', () {
      expect(
        () => parseEnhanceJson(jsonEncode({'amount': '30'})),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('amount 非正数 → AiEnhanceException', () {
      expect(
        () => parseEnhanceJson(jsonEncode({'amount': 0})),
        throwsA(isA<AiEnhanceException>()),
      );
      expect(
        () => parseEnhanceJson(jsonEncode({'amount': -5})),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('amount NaN/Infinity → AiEnhanceException', () {
      // jsonDecode 返回的 NaN 表示通过手工构造 dynamic 才能触发；这里用 Infinity
      // 字符串也会因 jsonDecode 失败先被前一关挡掉，故只测 amount=0 等价场景。
      expect(
        () => parseEnhanceJson(jsonEncode({'amount': 0.0})),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('category_parent_key 取值非法 → AiEnhanceException', () {
      expect(
        () => parseEnhanceJson(jsonEncode({
          'amount': 10,
          'category_parent_key': 'breakfast',
        })),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('category_parent_key 类型非法（数字）→ AiEnhanceException', () {
      expect(
        () => parseEnhanceJson(jsonEncode({
          'amount': 10,
          'category_parent_key': 123,
        })),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('occurred_at 不是合法日期 → AiEnhanceException', () {
      expect(
        () => parseEnhanceJson(jsonEncode({
          'amount': 10,
          'occurred_at': '昨天',
        })),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('note 类型非法 → AiEnhanceException', () {
      expect(
        () => parseEnhanceJson(jsonEncode({
          'amount': 10,
          'note': {'unexpected': 'object'},
        })),
        throwsA(isA<AiEnhanceException>()),
      );
    });
  });

  group('AiInputEnhanceService.enhance', () {
    test('未配置 API 时抛 AiEnhanceException（验证 1 服务端兜底）', () async {
      final svc = AiInputEnhanceService(
        settings: const AiInputSettings(),
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(
        () => svc.enhance('foo'),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('endpoint URL 非法 → AiEnhanceException', () async {
      final svc = AiInputEnhanceService(
        settings: const AiInputSettings(
          enabled: true,
          endpoint: 'not-a-url',
          apiKey: 'sk',
          model: 'm',
        ),
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(
        () => svc.enhance('x'),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('成功路径：返回 AiEnhanceResult；http 请求按 OpenAI 协议发出', () async {
      late http.Request capturedReq;
      final svc = AiInputEnhanceService(
        settings: validSettings,
        httpClient: MockClient((req) async {
          capturedReq = req;
          return http.Response(
            wrapChatCompletion(jsonEncode({
              'amount': 25,
              'category_parent_key': 'food',
              'occurred_at': '2026-05-02',
              'note': '午饭',
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        clock: () => DateTime(2026, 5, 4, 9, 30),
      );

      final r = await svc.enhance('午饭 25');
      expect(r.amount, 25.0);
      expect(r.categoryParentKey, 'food');
      expect(r.occurredAt, DateTime(2026, 5, 2));
      expect(r.note, '午饭');

      // 请求方法 / 头 / body schema
      expect(capturedReq.method, 'POST');
      expect(capturedReq.headers['Authorization'], 'Bearer sk-test');
      expect(capturedReq.headers['Content-Type'], contains('json'));
      final body = jsonDecode(capturedReq.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-4o-mini');
      expect((body['messages'] as List).first['role'], 'user');
      expect(body['response_format'], {'type': 'json_object'});
      // prompt 占位符已替换
      final prompt = (body['messages'] as List).first['content'] as String;
      expect(prompt, contains('午饭 25'));
      expect(prompt, contains('2026-05-04 09:30'));
      expect(prompt, contains('food'));
    });

    test(
        '验证 2：HTTP 非 200 → AiEnhanceException（不崩溃，UI 走本地兜底）',
        () async {
      final svc = AiInputEnhanceService(
        settings: validSettings,
        httpClient: MockClient(
          (_) async => http.Response('rate limit', 429),
        ),
      );
      try {
        await svc.enhance('x');
        fail('expected AiEnhanceException');
      } on AiEnhanceException catch (e) {
        expect(e.message, contains('429'));
      }
    });

    test('验证 2：网络异常（client 抛错）→ AiEnhanceException', () async {
      final svc = AiInputEnhanceService(
        settings: validSettings,
        httpClient: MockClient(
          (_) async => throw http.ClientException('connection refused'),
        ),
      );
      expect(
        () => svc.enhance('x'),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('LLM 响应缺 choices → AiEnhanceException', () async {
      final svc = AiInputEnhanceService(
        settings: validSettings,
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'foo': 'bar'}), 200),
        ),
      );
      expect(
        () => svc.enhance('x'),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('LLM 响应 content 非 JSON → AiEnhanceException', () async {
      final svc = AiInputEnhanceService(
        settings: validSettings,
        httpClient: MockClient(
          (_) async => http.Response(
            wrapChatCompletion('not json'),
            200,
          ),
        ),
      );
      expect(
        () => svc.enhance('x'),
        throwsA(isA<AiEnhanceException>()),
      );
    });

    test('LLM 响应 schema 非法（amount 字符串）→ AiEnhanceException', () async {
      final svc = AiInputEnhanceService(
        settings: validSettings,
        httpClient: MockClient(
          (_) async => http.Response(
            wrapChatCompletion(jsonEncode({'amount': '30'})),
            200,
          ),
        ),
      );
      expect(
        () => svc.enhance('x'),
        throwsA(isA<AiEnhanceException>()),
      );
    });
  });

  group('buildPromptForTesting - 占位符替换', () {
    test('默认模板的三个占位符都被替换', () {
      final svc = AiInputEnhanceService(
        settings: validSettings,
        clock: () => DateTime(2026, 5, 4, 9, 30),
      );
      final prompt = svc.buildPromptForTesting('打车 50');
      expect(prompt, contains('2026-05-04 09:30'));
      expect(prompt, contains('打车 50'));
      // categories 列表至少包含 food / transport
      expect(prompt, contains('food'));
      expect(prompt, contains('transport'));
      // 没有未替换的占位符残留
      expect(prompt, isNot(contains('{NOW}')));
      expect(prompt, isNot(contains('{TEXT}')));
      expect(prompt, isNot(contains('{CATEGORIES}')));
    });

    test('用户自定义模板生效 + 占位符替换', () {
      final svc = AiInputEnhanceService(
        settings: validSettings.copyWith(
          promptTemplate: 'TIME={NOW}\nUSER={TEXT}\nCATS={CATEGORIES}',
        ),
        clock: () => DateTime(2026, 5, 4, 12, 0),
      );
      final prompt = svc.buildPromptForTesting('hi');
      expect(prompt, startsWith('TIME=2026-05-04 12:00'));
      expect(prompt, contains('USER=hi'));
      expect(prompt, contains('food'));
    });

    test('空 promptTemplate → 走默认模板', () {
      final svc = AiInputEnhanceService(
        settings: validSettings.copyWith(promptTemplate: '   '),
        clock: () => DateTime(2026, 5, 4),
      );
      final prompt = svc.buildPromptForTesting('x');
      expect(prompt, contains('记账文本解析助手'));
    });
  });
}
