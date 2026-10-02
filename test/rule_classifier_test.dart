import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_analysis.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/utils/rule_classifier.dart';

// 기준: 2026-10-01 목요일 11:12
final now = DateTime(2026, 10, 1, 11, 12);

MemoAnalysis run(String memo) => classifyByRules(memo, now);

void main() {
  group('서버(AI) 평가와 같은 17건: 허용 카테고리 안에 들어야 한다', () {
    final cases = <(String, List<String>)>[
      ('수학 문제집 30쪽 풀기', ['학교']),
      ('영어 수행평가 준비물 챙기기', ['학교']),
      ('엄마 생신 선물 사기', ['쇼핑']),
      ('휴대폰 요금 이번달 안에 납부', ['돈']),
      ('저녁 식후 약 먹기', ['건강']),
      ('치과 예약 전화하기', ['건강', '약속', '할일']),
      ('토요일 점심 친구랑 약속', ['약속']),
      ('동아리 회의 자료 만들기', ['학교', '할일']),
      ('계란 우유 식빵 사오기', ['쇼핑']),
      ('용돈 5000원 갚기', ['돈']),
      ('운동화 새로 사야함', ['쇼핑']),
      ('병원 가서 감기약 받기', ['건강']),
      ('방 청소하기', ['할일']),
      ('친구 생일 파티 7시', ['약속']),
      ('모의고사 오답노트 정리', ['학교']),
      ('편의점 알바비 입금 확인', ['돈']),
      ('내일 학원 가기 전에 도서관에서 영어 단어장 빌리고 사회 과제 자료도 찾아봐야 함', ['학교']),
    ];
    for (final (memo, allowed) in cases) {
      test(memo, () => expect(allowed, contains(run(memo).category)));
    }
  });

  group('글자가 겹치는 단어 구분', () {
    test('약속·예약의 "약"은 건강이 아니다', () {
      expect(run('친구랑 약속').category, '약속');
      expect(run('식당 예약하기').category, '약속');
    });
    test('약(알약)은 건강', () => expect(run('감기약 먹기').category, '건강'));
    test('운동화는 운동이 아니라 쇼핑', () => expect(run('운동화 사기').category, '쇼핑'));
    test('운동은 건강', () => expect(run('저녁에 운동하기').category, '건강'));
    test('사회 과제의 "사"는 쇼핑이 아니다', () => expect(run('사회 과제 하기').category, '학교'));
    test('금액은 돈', () => expect(run('3000원 송금').category, '돈'));
    test('재활용은 재활(건강)이 아니라 할일', () {
      expect(run('재활용 쓰레기 내놓기').category, '할일');
    });
    test('돈까스는 돈(금전)이 아니다', () => expect(run('돈까스 먹기').category, isNot('돈')));
    test('물 마시기는 건강', () => expect(run('물 2리터 마시기').category, '건강'));
    test('급식비·학원비는 돈', () {
      expect(run('급식비 내기').category, '돈');
      expect(run('학원비 납부').category, '돈');
    });
  });

  test('어디에도 안 맞으면 기타', () {
    expect(run('뭐였더라').category, '기타');
    expect(run('').category, '기타');
  });

  test('동점이면 학교>건강>돈>쇼핑>약속>할일 순서', () {
    // 학교(동아리)와 약속(회의)이 1점씩
    expect(run('동아리 회의').category, '학교');
  });

  group('우선순위', () {
    test('급함 표현은 high', () {
      expect(run('꼭 챙기기').priority, MemoPriority.high);
      expect(run('반드시 제출').priority, MemoPriority.high);
    });
    test('24시간 안의 예약 시각은 high', () {
      expect(run('내일 오전 9시 수학 숙제 제출').priority, MemoPriority.high);
      expect(run('오늘 밤 10시 약 먹기').priority, MemoPriority.high);
    });
    test('먼 일정은 normal', () {
      expect(run('다음주 월요일 오전 9시 영어 수행평가').priority, MemoPriority.normal);
    });
    test('여유 표현은 low', () {
      expect(run('나중에 책상 정리').priority, MemoPriority.low);
      expect(run('시간 날 때 방 청소').priority, MemoPriority.low);
    });
    test(
      '아무 단서가 없으면 normal',
      () => expect(run('수학 문제집 풀기').priority, MemoPriority.normal),
    );
  });

  group('요약', () {
    test('25자 이하의 짧은 메모는 요약이 비어 있다', () {
      expect(run('우유 계란 사기').summary, '');
      expect(run('가' * 25).summary, '');
    });
    test('긴 메모는 첫 문장을 쓴다', () {
      final r = run('내일 학원 가기 전에 도서관에 들러야 한다. 그리고 단어장도 빌려야 한다');
      expect(r.summary, '내일 학원 가기 전에 도서관에 들러야 한다');
    });
    test('첫 문장이 30자를 넘으면 줄임표로 자른다', () {
      final r = run('가' * 60);
      expect(r.summary.length, maxSummaryLength);
      expect(r.summary.endsWith('…'), isTrue);
    });
  });

  group('예약 시각', () {
    test('시간 파서와 같은 결과를 담는다', () {
      final r = run('내일 오후 3시 치과');
      expect(r.due?.at, DateTime(2026, 10, 2, 15));
      expect(r.due?.hasTime, isTrue);
    });
    test('시각이 없으면 null', () => expect(run('방 청소하기').due, isNull));
  });

  test('출처는 rules', () => expect(run('아무거나').source, AnalysisSource.rules));

  test('priorityFromName: 모르는 값은 normal', () {
    expect(priorityFromName('high'), MemoPriority.high);
    expect(priorityFromName('긴급'), MemoPriority.normal);
    expect(priorityFromName(null), MemoPriority.normal);
  });

  test('카테고리 목록은 서버와 같다', () {
    expect(memoCategories, ['학교', '할일', '약속', '쇼핑', '건강', '돈', '기타']);
  });

  group('withRuleClassification / backfillClassification', () {
    MemoEntry entry(String memo, {int time = 1, String? category}) =>
        MemoEntry(id: memo, memo: memo, time: time, category: category);

    test('분류가 없으면 기본 분석으로 카테고리·우선순위를 채운다', () {
      final e = withRuleClassification(entry('수학 숙제 하기'), now);
      expect(e.category, '학교');
      expect(e.priority, MemoPriority.normal);
      expect(e.summary, isNull); // 요약은 건드리지 않는다
    });

    test('이미 분류가 있으면 그대로(✨로 적용한 값을 덮어쓰지 않는다)', () {
      final e = entry('수학 숙제 하기', category: '쇼핑');
      expect(withRuleClassification(e, now).category, '쇼핑');
    });

    test('급함 표현은 high로', () {
      expect(
        withRuleClassification(entry('꼭 챙기기'), now).priority,
        MemoPriority.high,
      );
    });

    test('backfill: 분류 없는 것만 채우고 순서·id는 그대로', () {
      final list = [
        entry('수학 숙제 하기'),
        entry('우유 사기', category: '건강'),
        entry('방 청소하기'),
      ];
      final r = backfillClassification(list, now);
      expect(r.changed, isTrue);
      expect(r.list.map((e) => e.id), ['수학 숙제 하기', '우유 사기', '방 청소하기']);
      expect(r.list.map((e) => e.category), ['학교', '건강', '할일']);
    });

    test('backfill: 모두 분류돼 있으면 changed=false', () {
      final r = backfillClassification([entry('a', category: '학교')], now);
      expect(r.changed, isFalse);
    });

    test('backfill: 빈 목록', () {
      final r = backfillClassification([], now);
      expect(r.list, isEmpty);
      expect(r.changed, isFalse);
    });

    test('backfill: 우선순위는 메모를 쓴 시각 기준', () {
      // 쓴 시각 9/30 10:00 기준 내일 15:00 = 29시간 뒤 → normal
      final wrote = DateTime(2026, 9, 30, 10).millisecondsSinceEpoch;
      final r = backfillClassification([
        entry('내일 오후 3시 치과', time: wrote),
      ], now);
      expect(r.list.single.priority, MemoPriority.normal);
      // 쓴 시각 9/30 20:00 기준 내일 09:00 = 13시간 뒤 → high
      final soon = DateTime(2026, 9, 30, 20).millisecondsSinceEpoch;
      final r2 = backfillClassification([
        entry('내일 오전 9시 치과', time: soon),
      ], now);
      expect(r2.list.single.priority, MemoPriority.high);
    });

    test('backfill: 쓴 시각을 모르면(0) 지금 기준', () {
      final r = backfillClassification([entry('내일 오전 9시 치과', time: 0)], now);
      expect(r.list.single.priority, MemoPriority.high);
    });
  });
}
