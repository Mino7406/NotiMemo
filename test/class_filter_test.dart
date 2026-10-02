import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/utils/class_filter.dart';

typedef Cls = ({String? category, MemoPriority priority});

Cls c(String? category, [MemoPriority p = MemoPriority.normal]) =>
    (category: category, priority: p);

void main() {
  group('ClassFilter.matches', () {
    test('아무것도 안 고르면 모두 통과', () {
      expect(ClassFilter.none.isActive, isFalse);
      expect(ClassFilter.none.matches('학교', MemoPriority.high), isTrue);
      expect(ClassFilter.none.matches(null, MemoPriority.low), isTrue);
    });

    test('분류만 고르면 그 분류만', () {
      const f = ClassFilter(category: '학교');
      expect(f.isActive, isTrue);
      expect(f.matches('학교', MemoPriority.low), isTrue);
      expect(f.matches('쇼핑', MemoPriority.low), isFalse);
      expect(f.matches(null, MemoPriority.low), isFalse); // 분류 없는 것은 걸리지 않는다
    });

    test('우선순위만 고르면 그 우선순위만(분류 없는 메모도 포함)', () {
      const f = ClassFilter(priority: MemoPriority.high);
      expect(f.matches('쇼핑', MemoPriority.high), isTrue);
      expect(f.matches(null, MemoPriority.high), isTrue);
      expect(f.matches('쇼핑', MemoPriority.normal), isFalse);
    });

    test('둘 다 고르면 둘 다 만족해야 한다', () {
      const f = ClassFilter(category: '학교', priority: MemoPriority.high);
      expect(f.matches('학교', MemoPriority.high), isTrue);
      expect(f.matches('학교', MemoPriority.normal), isFalse);
      expect(f.matches('쇼핑', MemoPriority.high), isFalse);
    });

    test('withCategory/withPriority는 다른 축을 유지하고 null로 해제', () {
      const f = ClassFilter(category: '학교', priority: MemoPriority.high);
      expect(
        f.withCategory(null),
        const ClassFilter(priority: MemoPriority.high),
      );
      expect(f.withPriority(null), const ClassFilter(category: '학교'));
      expect(
        f.withCategory('쇼핑'),
        const ClassFilter(category: '쇼핑', priority: MemoPriority.high),
      );
    });

    test('같은 조건은 같다', () {
      expect(
        const ClassFilter(category: '학교'),
        const ClassFilter(category: '학교'),
      );
      expect(
        const ClassFilter(category: '학교') == const ClassFilter(category: '쇼핑'),
        isFalse,
      );
    });
  });

  group('categoriesIn', () {
    test('실제로 있는 것만 정해진 순서대로, 중복 없이', () {
      expect(categoriesIn(['쇼핑', '학교', '쇼핑', null, '건강']), ['학교', '쇼핑', '건강']);
    });
    test('모르는 이름은 무시하고 비어 있으면 빈 목록', () {
      expect(categoriesIn(['게임']), isEmpty);
      expect(categoriesIn([]), isEmpty);
      expect(categoriesIn([null, null]), isEmpty);
    });
  });

  group('visibleIndexes', () {
    final items = [
      c('학교', MemoPriority.high), // 0
      c('학교'), // 1
      c('쇼핑'), // 2
      c('건강', MemoPriority.low), // 3
      c(null), // 4
    ];
    List<int> idx(ClassFilter f) => visibleIndexes<Cls>(items, f, (e) => e);

    test(
      '필터 없음: 전부, 원래 순서',
      () => expect(idx(ClassFilter.none), [0, 1, 2, 3, 4]),
    );
    test(
      '분류: 원래 위치를 돌려준다',
      () => expect(idx(const ClassFilter(category: '쇼핑')), [2]),
    );
    test('분류 + 우선순위', () {
      expect(
        idx(const ClassFilter(category: '학교', priority: MemoPriority.high)),
        [0],
      );
    });
    test('결과 없음', () {
      expect(
        idx(const ClassFilter(category: '쇼핑', priority: MemoPriority.high)),
        isEmpty,
      );
    });
  });

  group('normalizedFor: 사라진 조건은 푼다', () {
    final items = [c('학교'), c('쇼핑', MemoPriority.high)];

    test('있는 조건은 유지', () {
      const f = ClassFilter(category: '학교', priority: MemoPriority.high);
      expect(f.normalizedFor(items), f);
    });
    test('없어진 분류는 해제', () {
      expect(
        const ClassFilter(category: '건강').normalizedFor(items),
        ClassFilter.none,
      );
    });
    test('없어진 우선순위는 해제하고 분류는 유지', () {
      expect(
        const ClassFilter(
          category: '학교',
          priority: MemoPriority.low,
        ).normalizedFor(items),
        const ClassFilter(category: '학교'),
      );
    });
    test('빈 목록이면 모두 해제', () {
      expect(
        const ClassFilter(category: '학교').normalizedFor(const []),
        ClassFilter.none,
      );
    });
  });
}
