// 우선순위: 낮음 / 보통 / 높음
enum MemoPriority { low, normal, high }

/// 메모 한 건. 저장 포맷은 세 세대를 모두 읽을 수 있어야 한다.
///  1) 문자열만 저장된 초기 포맷
///  2) `{memo, time}` (v2.x)
///  3) 이 클래스의 전체 필드 (v3.x)
/// 새 필드는 기본값이 아닐 때만 기록해서, 옛 버전 앱이 읽어도 깨지지 않게 한다.
class MemoEntry {
  final String id;
  final String memo;

  /// 생성 시각 (ms since epoch), 0 = 알 수 없음 (옛 포맷에서 이전됨)
  final int time;

  /// 카테고리 (자유 문자열, AI 분류 결과 등). null = 미분류
  final String? category;
  final MemoPriority priority;

  /// 한 줄 요약. null = 없음
  final String? summary;

  /// 예약 고정 시각 (ms since epoch). null = 예약 없음
  final int? scheduledAt;

  const MemoEntry({
    required this.id,
    required this.memo,
    required this.time,
    this.category,
    this.priority = MemoPriority.normal,
    this.summary,
    this.scheduledAt,
  });

  /// 새 메모 생성. id는 생성 시각(마이크로초) 기반.
  factory MemoEntry.create(String memo, {int? now}) {
    final ms = now ?? DateTime.now().millisecondsSinceEpoch;
    return MemoEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      memo: memo,
      time: ms,
    );
  }

  MemoEntry copyWith({
    String? memo,
    String? category,
    MemoPriority? priority,
    String? summary,
    int? scheduledAt,
    bool clearScheduledAt = false,
  }) {
    return MemoEntry(
      id: id,
      memo: memo ?? this.memo,
      time: time,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      summary: summary ?? this.summary,
      scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'memo': memo,
    'time': time,
    if (category != null) 'category': category,
    if (priority != MemoPriority.normal) 'priority': priority.name,
    if (summary != null) 'summary': summary,
    if (scheduledAt != null) 'scheduledAt': scheduledAt,
  };

  /// [fallbackId]는 id가 없는 옛 데이터에 부여할 값. 같은 데이터는 항상
  /// 같은 id를 받도록 목록 위치 등 결정적인 값을 넘겨야 한다.
  factory MemoEntry.fromJson(dynamic json, {required String fallbackId}) {
    if (json is String) {
      return MemoEntry(id: fallbackId, memo: json, time: 0);
    }
    final map = json as Map<String, dynamic>;
    return MemoEntry(
      id: (map['id'] as String?) ?? fallbackId,
      memo: map['memo'] as String,
      time: (map['time'] as num?)?.toInt() ?? 0,
      category: map['category'] as String?,
      priority:
          MemoPriority.values.asNameMap()[map['priority']] ??
          MemoPriority.normal,
      summary: map['summary'] as String?,
      scheduledAt: (map['scheduledAt'] as num?)?.toInt(),
    );
  }
}
