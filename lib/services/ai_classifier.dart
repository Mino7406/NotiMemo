import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/memo_analysis.dart';
import '../storage/ai_storage.dart';
import '../utils/due_parser.dart';
import '../utils/rule_classifier.dart';

/// 서버가 돌려준 응답. 통신 계층을 갈아끼워 테스트할 수 있게 값만 담는다.
class AiHttpResponse {
  final int status;
  final String body;
  const AiHttpResponse(this.status, this.body);
}

typedef AiTransport =
    Future<AiHttpResponse> Function(
      Uri url,
      String jsonBody,
      Map<String, String> headers,
    );

/// 메모를 서버(Cloudflare Workers AI)로 분석하고, 못 쓰면 규칙 기반 분석으로 대신한다.
///
/// 어떤 실패든 예외를 던지지 않고 [MemoAnalysis]를 돌려준다. 서버로 보내는 건 동의한
/// 사용자의 메모 본문과 설치별 무작위 id뿐이다.
class AiClassifier {
  static final defaultEndpoint = Uri.parse(
    'https://notimemo-ai.notimemo-ai.workers.dev/classify',
  );

  /// 기기당 하루 호출 상한. 서버의 하루 무료 사용량(약 600건)을 여러 기기가 나눠 쓰므로
  /// 앱에서도 막는다.
  static const dailyLimit = 20;

  /// 서버가 받는 최대 길이(worker MAX_MEMO_LENGTH). 분류에는 앞부분이면 충분하다.
  static const maxMemoLength = 500;

  static const timeout = Duration(seconds: 8);

  final Uri endpoint;
  final AiTransport _transport;

  AiClassifier({Uri? endpoint, AiTransport? transport})
    : endpoint = endpoint ?? defaultEndpoint,
      _transport = transport ?? _httpTransport;

  Future<MemoAnalysis> analyze(String memo, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    MemoAnalysis fallback(FallbackReason reason) =>
        classifyByRules(memo, clock).withFallbackReason(reason);

    if (await AiStorage.getConsent() != true) {
      return fallback(FallbackReason.disabled);
    }
    if (await AiStorage.usageToday(clock) >= dailyLimit) {
      return fallback(FallbackReason.dailyLimit);
    }

    // 서버에 닿는 시도는 성공 여부와 상관없이 센다(서버 한도를 지키기 위해).
    await AiStorage.addUsage(clock);

    try {
      final text = memo.trim();
      final body = jsonEncode({
        'memo': text.length > maxMemoLength
            ? text.substring(0, maxMemoLength)
            : text,
      });
      final response = await _transport(endpoint, body, {
        'X-Device-Id': await AiStorage.getDeviceId(),
      }).timeout(timeout);

      if (response.status == 200) {
        final analysis = _parse(response.body, memo, clock);
        return analysis ?? fallback(FallbackReason.serverError);
      }
      return fallback(_reasonForError(response));
    } on TimeoutException {
      return fallback(FallbackReason.timeout);
    } on SocketException {
      return fallback(FallbackReason.offline);
    } on HandshakeException {
      return fallback(FallbackReason.offline);
    } on HttpException {
      return fallback(FallbackReason.offline);
    } catch (_) {
      return fallback(FallbackReason.serverError);
    }
  }

  FallbackReason _reasonForError(AiHttpResponse response) {
    if (response.status == 429) {
      try {
        final code = (jsonDecode(response.body) as Map)['error'];
        if (code == 'quota_exceeded') return FallbackReason.quotaExceeded;
      } catch (_) {
        // 본문을 못 읽으면 일반적인 횟수 제한으로 본다.
      }
      return FallbackReason.rateLimited;
    }
    return FallbackReason.serverError;
  }

  /// 서버 응답을 검증해 [MemoAnalysis]로 만든다. 모양이 이상하면 null(→ 규칙 기반).
  MemoAnalysis? _parse(String body, String memo, DateTime now) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (json is! Map) return null;

    final category = json['category'];
    final summary = json['summary'];
    final text = memo.trim();
    return MemoAnalysis(
      category: category is String && memoCategories.contains(category)
          ? category
          : '기타',
      priority: priorityFromName(
        json['priority'] is String ? json['priority'] as String : null,
      ),
      // 짧은 메모에는 요약을 두지 않는다(서버와 같은 기준을 한 번 더 지킨다).
      summary: summary is String && text.length > summaryMinMemoLength
          ? summary.trim()
          : '',
      // 예약 시각은 서버가 아니라 이 앱의 시간 파서가 계산한다.
      due: parseDue(memo, now),
      source: AnalysisSource.ai,
    );
  }

  static Future<AiHttpResponse> _httpTransport(
    Uri url,
    String jsonBody,
    Map<String, String> headers,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
      headers.forEach(request.headers.set);
      request.add(utf8.encode(jsonBody));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return AiHttpResponse(response.statusCode, text);
    } finally {
      client.close();
    }
  }
}
