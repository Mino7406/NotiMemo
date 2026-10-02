import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_analysis.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/services/ai_classifier.dart';
import 'package:notimemo/storage/ai_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 기준: 2026-10-01 목요일 11:12
final now = DateTime(2026, 10, 1, 11, 12);

const okBody = '{"category":"약속","priority":"high","summary":"치과 예약"}';

/// 호출 내용을 기록하는 가짜 통신.
class FakeTransport {
  final List<({Uri url, String body, Map<String, String> headers})> calls = [];
  final Future<AiHttpResponse> Function() respond;
  FakeTransport(this.respond);

  Future<AiHttpResponse> call(
    Uri url,
    String body,
    Map<String, String> headers,
  ) {
    calls.add((url: url, body: body, headers: headers));
    return respond();
  }
}

AiClassifier classifier(FakeTransport t) => AiClassifier(transport: t.call);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'ai_consent': true});
    AiClassifier.dailyLimit =
        AiClassifier.releaseDailyLimit; // 상한 동작은 배포 값으로 시험
  });
  tearDown(() => AiClassifier.dailyLimit = AiClassifier.devDailyLimit);

  group('서버를 부르지 않는 경우', () {
    test('아직 동의를 묻지 않았으면 서버에 아무것도 보내지 않는다', () async {
      SharedPreferences.setMockInitialValues({});
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      final r = await classifier(t).analyze('내일 3시 치과', now: now);
      expect(t.calls, isEmpty);
      expect(r.source, AnalysisSource.rules);
      expect(r.fallbackReason, FallbackReason.disabled);
    });

    test('동의를 거부했으면 서버에 보내지 않는다', () async {
      SharedPreferences.setMockInitialValues({'ai_consent': false});
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      final r = await classifier(t).analyze('내일 3시 치과', now: now);
      expect(t.calls, isEmpty);
      expect(r.fallbackReason, FallbackReason.disabled);
    });

    test('하루 상한을 다 쓰면 서버에 보내지 않는다', () async {
      for (var i = 0; i < AiClassifier.dailyLimit; i++) {
        await AiStorage.addUsage(now);
      }
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      final r = await classifier(t).analyze('방 청소', now: now);
      expect(t.calls, isEmpty);
      expect(r.fallbackReason, FallbackReason.dailyLimit);
      expect(r.category, '할일'); // 폴백도 쓸 만한 결과를 낸다
    });

    test('다음 날이 되면 상한이 초기화된다', () async {
      for (var i = 0; i < AiClassifier.dailyLimit; i++) {
        await AiStorage.addUsage(now);
      }
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      final tomorrow = now.add(const Duration(days: 1));
      final r = await classifier(t).analyze('방 청소', now: tomorrow);
      expect(t.calls, hasLength(1));
      expect(r.source, AnalysisSource.ai);
    });
  });

  group('서버 호출', () {
    test('성공하면 서버 결과를 쓰고, 예약 시각은 앱의 시간 파서가 계산한다', () async {
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      final r = await classifier(t).analyze('내일 오후 3시 치과 예약', now: now);
      expect(r.source, AnalysisSource.ai);
      expect(r.fallbackReason, isNull);
      expect(r.category, '약속');
      expect(r.priority, MemoPriority.high);
      expect(r.due?.at, DateTime(2026, 10, 2, 15));
    });

    test('요청에는 메모와 설치별 id만 담긴다', () async {
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      await classifier(t).analyze('  우유 사기  ', now: now);
      final call = t.calls.single;
      expect(call.url, AiClassifier.defaultEndpoint);
      expect(jsonDecode(call.body), {'memo': '우유 사기'});
      expect(call.headers.keys, ['X-Device-Id']);
      expect(call.headers['X-Device-Id'], matches(RegExp(r'^[a-z0-9]{24}$')));
    });

    test('기기 id는 호출마다 같다', () async {
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      await classifier(t).analyze('a', now: now);
      await classifier(t).analyze('b', now: now);
      expect(
        t.calls[0].headers['X-Device-Id'],
        t.calls[1].headers['X-Device-Id'],
      );
    });

    test('500자를 넘는 메모는 앞 500자만 보낸다', () async {
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      await classifier(t).analyze('가' * 800, now: now);
      expect((jsonDecode(t.calls.single.body) as Map)['memo'], hasLength(500));
    });

    test('호출 횟수는 성공·실패와 상관없이 센다', () async {
      final t = FakeTransport(() async => const AiHttpResponse(500, '{}'));
      await classifier(t).analyze('a', now: now);
      await classifier(t).analyze('b', now: now);
      expect(await AiStorage.usageToday(now), 2);
    });
  });

  group('서버 응답 검증', () {
    test('모르는 카테고리는 기타, 모르는 우선순위는 normal', () async {
      final t = FakeTransport(
        () async => const AiHttpResponse(
          200,
          '{"category":"게임","priority":"긴급","summary":""}',
        ),
      );
      final r = await classifier(t).analyze('뭔가', now: now);
      expect(r.category, '기타');
      expect(r.priority, MemoPriority.normal);
      expect(r.source, AnalysisSource.ai);
    });

    test('우선순위가 문자열이 아니어도 죽지 않는다', () async {
      final t = FakeTransport(
        () async => const AiHttpResponse(
          200,
          '{"category":"학교","priority":5,"summary":null}',
        ),
      );
      final r = await classifier(t).analyze('숙제', now: now);
      expect(r.category, '학교');
      expect(r.priority, MemoPriority.normal);
    });

    test('짧은 메모에는 서버가 요약을 보내도 쓰지 않는다', () async {
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      final r = await classifier(t).analyze('치과 예약', now: now);
      expect(r.summary, '');
    });

    test('긴 메모는 서버 요약을 쓴다', () async {
      final t = FakeTransport(() async => const AiHttpResponse(200, okBody));
      final r = await classifier(
        t,
      ).analyze('내일 학원 가기 전에 도서관에서 영어 단어장 빌리고 사회 과제 자료도 찾기', now: now);
      expect(r.summary, '치과 예약');
    });

    test('JSON이 아니거나 모양이 틀리면 폴백(serverError)', () async {
      for (final body in ['not json', '[]', '"문자열"']) {
        final t = FakeTransport(() async => AiHttpResponse(200, body));
        final r = await classifier(t).analyze('방 청소', now: now);
        expect(r.source, AnalysisSource.rules, reason: body);
        expect(r.fallbackReason, FallbackReason.serverError, reason: body);
      }
    });
  });

  group('실패하면 규칙 기반 폴백과 이유', () {
    Future<MemoAnalysis> run(Future<AiHttpResponse> Function() respond) =>
        classifier(FakeTransport(respond)).analyze('내일 오전 9시 수학 숙제', now: now);

    test('일일 한도 초과(429 quota_exceeded)', () async {
      final r = await run(
        () async => const AiHttpResponse(429, '{"error":"quota_exceeded"}'),
      );
      expect(r.fallbackReason, FallbackReason.quotaExceeded);
    });

    test('횟수 제한(429 rate_limited)', () async {
      final r = await run(
        () async => const AiHttpResponse(429, '{"error":"rate_limited"}'),
      );
      expect(r.fallbackReason, FallbackReason.rateLimited);
    });

    test('429인데 본문을 못 읽으면 횟수 제한으로 본다', () async {
      final r = await run(() async => const AiHttpResponse(429, '???'));
      expect(r.fallbackReason, FallbackReason.rateLimited);
    });

    test('서버 오류(5xx)·잘못된 요청(4xx)', () async {
      expect(
        (await run(
          () async => const AiHttpResponse(502, '{"error":"ai_failed"}'),
        )).fallbackReason,
        FallbackReason.serverError,
      );
      expect(
        (await run(() async => const AiHttpResponse(400, '{}'))).fallbackReason,
        FallbackReason.serverError,
      );
    });

    test('인터넷 없음/차단은 offline', () async {
      expect(
        (await run(
          () async => throw const SocketException('연결 실패'),
        )).fallbackReason,
        FallbackReason.offline,
      );
      expect(
        (await run(
          () async => throw const HandshakeException('TLS'),
        )).fallbackReason,
        FallbackReason.offline,
      );
    });

    test('응답이 늦으면 timeout', () async {
      final r = await run(() async => throw TimeoutException('늦음'));
      expect(r.fallbackReason, FallbackReason.timeout);
    });

    test('예상 못 한 예외도 앱을 죽이지 않는다', () async {
      final r = await run(() async => throw StateError('이상한 일'));
      expect(r.fallbackReason, FallbackReason.serverError);
    });

    test('폴백 결과도 분류·예약 시각·우선순위를 낸다', () async {
      final r = await run(() async => throw const SocketException('x'));
      expect(r.source, AnalysisSource.rules);
      expect(r.category, '학교');
      expect(r.due?.at, DateTime(2026, 10, 2, 9));
      expect(r.priority, MemoPriority.high);
    });
  });

  group('AiStorage.classificationEnabled', () {
    Future<bool> enabled(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      return AiStorage.classificationEnabled();
    }

    test('AI를 안 쓰면(동의 전·거부) 자동 분류 설정과 상관없이 허용', () async {
      expect(await enabled({}), isTrue);
      expect(await enabled({'ai_auto_classify': false}), isTrue);
      expect(
        await enabled({'ai_consent': false, 'ai_auto_classify': false}),
        isTrue,
      );
    });

    test('AI를 켜면 자동 분류 설정을 따른다', () async {
      expect(await enabled({'ai_consent': true}), isTrue);
      expect(
        await enabled({'ai_consent': true, 'ai_auto_classify': true}),
        isTrue,
      );
      expect(
        await enabled({'ai_consent': true, 'ai_auto_classify': false}),
        isFalse,
      );
    });
  });
}
